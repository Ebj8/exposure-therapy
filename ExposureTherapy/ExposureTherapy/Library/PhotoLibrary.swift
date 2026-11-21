//
//  PhotoLibrary.swift
//  ExposureTherapy
//
//  SPEC.md → Data → Photo access and Reading the library. Owns the
//  authorization state and the current `LibraryIndex`, and refreshes it
//  when the library changes.
//

import Foundation
import Photos
import UIKit

@Observable
final class PhotoLibrary {
    private(set) var authorization: PHAuthorizationStatus
    private(set) var index: LibraryIndex = .empty
    /// False until the first fetch finishes, so Home can show a spinner.
    private(set) var hasLoaded = false

    @ObservationIgnored private let imageLoader = CardImageLoader()
    @ObservationIgnored private var changeObserver: LibraryChangeObserver?
    @ObservationIgnored private var isReloading = false
    @ObservationIgnored private var needsAnotherReload = false
    /// When the app went to the background, to spot long absences.
    @ObservationIgnored private var backgroundedAt: Date?
    /// After this long in the background, refresh PhotoKit connections.
    private static let longAbsence: TimeInterval = 10 * 60
    /// Previews use sample data and never touch PhotoKit.
    @ObservationIgnored private let isPreview: Bool

    init() {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        isPreview = false
    }

    /// A library backed by sample data, for Previews.
    init(previewIndex: LibraryIndex, authorization: PHAuthorizationStatus = .authorized) {
        self.authorization = authorization
        self.index = previewIndex
        self.hasLoaded = true
        self.isPreview = true
    }

    var hasAccess: Bool {
        authorization == .authorized || authorization == .limited
    }

    // MARK: Card images

    /// Loads a swipe-card photo at `targetSize` pixels.
    func cardPhoto(for assetID: String, targetSize: CGSize) async -> CardPhoto? {
        if isPreview {
            return PreviewData.cardPhoto(for: assetID)
        }
        return await imageLoader.photo(for: assetID, targetSize: targetSize)
    }

    /// Prefetches upcoming cards at `targetSize` pixels.
    func prefetchCards(_ assetIDs: [String], targetSize: CGSize) {
        guard !isPreview else { return }
        imageLoader.startCaching(assetIDs, targetSize: targetSize, contentMode: .aspectFit)
    }

    /// Prefetches square grid thumbnails at `targetSize` pixels.
    func prefetchThumbnails(_ assetIDs: [String], targetSize: CGSize) {
        guard !isPreview else { return }
        imageLoader.startCaching(assetIDs, targetSize: targetSize, contentMode: .aspectFill)
    }

    /// Loads a grid thumbnail at `targetSize` pixels.
    func thumbnail(for assetID: String, targetSize: CGSize) async -> UIImage? {
        if isPreview {
            return PreviewData.cardPhoto(for: assetID).image
        }
        return await imageLoader.image(for: assetID, targetSize: targetSize)
    }

    // MARK: Changes in Apple Photos

    /// Returns true if this call changed the Favorite flag.
    func setFavorite(_ isFavorite: Bool, assetID: String) async -> Bool {
        if isPreview { return true }
        return await PhotoChanges.setFavorite(isFavorite, assetID: assetID)
    }

    /// Returns true if this call added the photo to the album.
    func addToAlbum(assetID: String, albumID: String) async -> Bool {
        if isPreview { return true }
        return await PhotoChanges.addToAlbum(assetID: assetID, albumID: albumID)
    }

    func removeFromAlbum(assetID: String, albumID: String) async {
        guard !isPreview else { return }
        await PhotoChanges.removeFromAlbum(assetID: assetID, albumID: albumID)
    }

    /// Creates an album and returns its ID.
    func createAlbum(named title: String) async -> String? {
        if isPreview { return "preview-album-new" }
        return await PhotoChanges.createAlbum(named: title)
    }

    func albums() async -> [PhotoAlbum] {
        if isPreview { return PreviewData.albums }
        return await PhotoChanges.albums()
    }

    // MARK: Breakup

    func deletionCandidates(for assetIDs: [String]) async -> [DeletionCandidate] {
        if isPreview {
            return assetIDs.map { DeletionCandidate(assetID: $0, bytes: 2_400_000, monthKey: "2019-06") }
        }
        return await PhotoChanges.deletionCandidates(for: assetIDs)
    }

    /// Only the Breakup flow (SPEC.md → Deletion) may call this.
    func deletePhotos(_ assetIDs: [String]) async -> DeletionResult {
        if isPreview { return .deleted }
        return await PhotoChanges.deletePhotos(assetIDs)
    }

    // MARK: Access and loading

    /// Shows the system permission prompt, then loads the library if allowed.
    func requestAccess() async {
        guard !isPreview else { return }
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await start()
    }

    /// Re-reads the permission, which may have changed in the Settings app.
    func refreshAuthorization() async {
        guard !isPreview else { return }
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current != authorization else { return }
        authorization = current
        if changeObserver == nil {
            await start()
        } else {
            await reload()
        }
    }

    /// Loads the library and starts watching it for changes, once access is granted.
    func start() async {
        guard !isPreview, hasAccess, changeObserver == nil else { return }
        // The loader is thread-safe, so the availability callback (on a
        // background queue) can reset it directly.
        let loader = imageLoader
        let observer = LibraryChangeObserver(
            onChange: { [weak self] in
                Task { @MainActor in
                    await self?.reload()
                }
            },
            onUnavailable: {
                loader.reset(reason: "photo library became unavailable")
            }
        )
        PHPhotoLibrary.shared().register(observer as PHPhotoLibraryChangeObserver)
        PHPhotoLibrary.shared().register(observer as PHPhotoLibraryAvailabilityObserver)
        changeObserver = observer
        await reload()
    }

    // MARK: App lifecycle

    func appDidEnterBackground() {
        backgroundedAt = .now
    }

    /// After a long time in the background, PhotoKit may have dropped the
    /// app's connection, leaving image requests unanswered (an endless
    /// skeleton). Start fresh: a new image manager and a re-read library.
    func appDidBecomeActive() async {
        guard let backgroundedAt else { return }
        self.backgroundedAt = nil
        guard !isPreview, hasAccess, Date.now.timeIntervalSince(backgroundedAt) > Self.longAbsence else { return }
        imageLoader.reset(reason: "back after a long time in the background")
        await reload()
    }

    /// Rebuilds the index off the main actor. Changes that arrive mid-fetch
    /// are folded into one more pass instead of overlapping fetches.
    func reload() async {
        guard !isPreview, hasAccess else { return }
        if isReloading {
            needsAnotherReload = true
            return
        }
        isReloading = true
        repeat {
            needsAnotherReload = false
            index = await Task.detached(priority: .userInitiated) {
                LibraryIndex.fetch()
            }.value
        } while needsAnotherReload
        isReloading = false
        hasLoaded = true
    }
}

/// Forwards PhotoKit change and availability notifications, which arrive
/// on a background queue.
nonisolated private final class LibraryChangeObserver: NSObject, PHPhotoLibraryChangeObserver,
    PHPhotoLibraryAvailabilityObserver, Sendable {
    private let onChange: @Sendable () -> Void
    private let onUnavailable: @Sendable () -> Void

    init(onChange: @escaping @Sendable () -> Void, onUnavailable: @escaping @Sendable () -> Void) {
        self.onChange = onChange
        self.onUnavailable = onUnavailable
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        onChange()
    }

    func photoLibraryDidBecomeUnavailable(_ photoLibrary: PHPhotoLibrary) {
        onUnavailable()
    }
}
