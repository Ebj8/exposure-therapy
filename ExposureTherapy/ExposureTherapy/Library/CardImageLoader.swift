//
//  CardImageLoader.swift
//  ExposureTherapy
//
//  SPEC.md → Data → Reading the library. Loads swipe-card images with a
//  PHCachingImageManager, downloading from iCloud when needed.
//

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
    private let manager = PHCachingImageManager()

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
        guard let image = await requestImage(for: asset, targetSize: targetSize) else { return nil }
        return CardPhoto(image: image, creationDate: asset.creationDate, fileSize: Self.fileSize(of: asset))
    }

    /// Loads just the image, e.g. a grid thumbnail.
    @concurrent
    func image(for assetID: String, targetSize: CGSize) async -> UIImage? {
        guard let asset = Self.assets(for: [assetID]).first else { return nil }
        return await requestImage(for: asset, targetSize: targetSize)
    }

    /// Starts loading upcoming cards into the cache.
    func startCaching(_ assetIDs: [String], targetSize: CGSize) {
        guard !assetIDs.isEmpty else { return }
        manager.startCachingImages(for: Self.assets(for: assetIDs), targetSize: targetSize, contentMode: .aspectFill, options: Self.options)
    }

    /// Frees cached images for cards that have been decided.
    func stopCaching(_ assetIDs: [String], targetSize: CGSize) {
        guard !assetIDs.isEmpty else { return }
        manager.stopCachingImages(for: Self.assets(for: assetIDs), targetSize: targetSize, contentMode: .aspectFill, options: Self.options)
    }

    private func requestImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            // With .highQualityFormat, PhotoKit calls this exactly once.
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: Self.options) { image, _ in
                continuation.resume(returning: image)
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
