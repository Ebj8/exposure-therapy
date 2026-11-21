//
//  CardImageLoader.swift
//  ExposureTherapy
//
//  SPEC.md → Data → Reading the library. Loads swipe-card images with a
//  PHCachingImageManager, downloading from iCloud when needed.
//

import OSLog
import Photos
import UIKit

/// A photo ready to show on a swipe card.
nonisolated struct CardPhoto: Sendable {
    let image: UIImage
    let creationDate: Date?
    /// Size of the original file, when PhotoKit reports it.
    let fileSize: Int64?
}

/// PHCachingImageManager is thread-safe, so this can be used from any thread.
nonisolated final class CardImageLoader: @unchecked Sendable {
    private let lock = NSLock()
    private var currentManager = PHCachingImageManager()
    private let log = Logger(subsystem: "com.elijohnson.ExposureTherapy", category: "Images")

    /// How long to wait for PhotoKit before retrying, then before giving up.
    /// The retry gets longer because an iCloud download can just be slow.
    private static let firstTimeout: TimeInterval = 8
    private static let retryTimeout: TimeInterval = 30

    private var manager: PHCachingImageManager {
        lock.lock()
        defer { lock.unlock() }
        return currentManager
    }

    /// Swaps in a fresh image manager. After hours in the background, or when
    /// the photo library becomes unavailable, PhotoKit can stop answering an
    /// existing manager's requests; a new one recovers without a relaunch.
    func reset(reason: String) {
        lock.lock()
        currentManager = PHCachingImageManager()
        lock.unlock()
        log.notice("Image manager reset: \(reason, privacy: .public)")
    }

    /// Same options for prefetching and loading, so loads hit the cache.
    private static var options: PHImageRequestOptions {
        let options = PHImageRequestOptions()
        // One callback with the final image, rather than a blurry one first.
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        // iCloud-only photos download; the card shows a spinner meanwhile.
        options.isNetworkAccessAllowed = true
        return options
    }

    /// Loads the image (in pixels) plus its date and file size, or nil if the
    /// photo is gone or can't be loaded.
    @concurrent
    func photo(for assetID: String, targetSize: CGSize) async -> CardPhoto? {
        guard let asset = Self.assets(for: [assetID]).first else { return nil }
        // Fit, not fill: the card shows the whole photo at its own shape.
        guard let image = await requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit) else { return nil }
        return CardPhoto(image: image, creationDate: asset.creationDate, fileSize: Self.fileSize(of: asset))
    }

    /// Loads just the image, e.g. a grid thumbnail, filled to a square crop.
    @concurrent
    func image(for assetID: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = Self.assets(for: [assetID]).first else { return nil }
        return await requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill)
    }

    /// Starts loading upcoming cards into the cache. The asset lookup runs
    /// in the background so it never holds up the screen.
    func startCaching(_ assetIDs: [String], targetSize: CGSize, contentMode: PHImageContentMode) {
        guard !assetIDs.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async { [manager] in
            manager.startCachingImages(for: Self.assets(for: assetIDs), targetSize: targetSize, contentMode: contentMode, options: Self.options)
        }
    }

    /// Requests an image, never waiting forever: if PhotoKit doesn't answer
    /// in time, it retries once with a fresh manager and more time, then
    /// gives up (nil), so the screen can offer "Try again" instead of a
    /// skeleton that never ends.
    private func requestImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode) async -> UIImage? {
        switch await requestOnce(for: asset, targetSize: targetSize, contentMode: contentMode, timeout: Self.firstTimeout) {
        case .image(let image):
            return image
        case .failed:
            return nil
        case .timedOut:
            log.error("Image request timed out after \(Self.firstTimeout)s; retrying with a fresh manager")
            reset(reason: "request timed out")
        }
        switch await requestOnce(for: asset, targetSize: targetSize, contentMode: contentMode, timeout: Self.retryTimeout) {
        case .image(let image):
            return image
        case .failed:
            return nil
        case .timedOut:
            log.error("Image request timed out again after \(Self.retryTimeout)s; giving up")
            return nil
        }
    }

    private enum RequestResult {
        case image(UIImage)
        case failed
        case timedOut
    }

    private func requestOnce(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        timeout: TimeInterval
    ) async -> RequestResult {
        let pending = PendingRequest(manager: manager)
        return await withCheckedContinuation { continuation in
            // With .highQualityFormat, PhotoKit calls this once, if it answers.
            let requestID = pending.manager.requestImage(
                for: asset, targetSize: targetSize, contentMode: contentMode, options: Self.options
            ) { image, _ in
                if pending.finish() {
                    continuation.resume(returning: image.map(RequestResult.image) ?? .failed)
                }
            }
            pending.requestID = requestID
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                if pending.finish() {
                    pending.manager.cancelImageRequest(pending.requestID)
                    continuation.resume(returning: .timedOut)
                }
            }
        }
    }

    private static func assets(for assetIDs: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        return result.objects(at: IndexSet(integersIn: 0..<result.count))
    }

    /// The original file's size. `fileSize` is an undocumented key on
    /// PHAssetResource (SPEC.md → Deletion), fine for a personal app.
    static func fileSize(of asset: PHAsset) -> Int64? {
        let resources = PHAssetResource.assetResources(for: asset)
        let resource = resources.first { $0.type == .photo } ?? resources.first
        return (resource?.value(forKey: "fileSize") as? NSNumber)?.int64Value
    }
}

/// One image request, finished exactly once by whichever comes first: the
/// image, or the timeout.
nonisolated private final class PendingRequest: @unchecked Sendable {
    let manager: PHCachingImageManager
    var requestID: PHImageRequestID = PHInvalidImageRequestID
    private let lock = NSLock()
    private var isFinished = false

    init(manager: PHCachingImageManager) {
        self.manager = manager
    }

    /// True the first time it's called, false after.
    func finish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinished else { return false }
        isFinished = true
        return true
    }
}
