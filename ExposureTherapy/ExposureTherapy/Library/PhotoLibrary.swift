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
        imageLoader.startCaching(assetIDs, targetSize: targetSize)
    }

    /// Releases prefetched cards that are no longer needed.
    func stopPrefetchingCards(_ assetIDs: [String], targetSize: CGSize) {
        guard !isPreview else { return }
        imageLoader.stopCaching(assetIDs, targetSize: targetSize)
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
        let observer = LibraryChangeObserver { [weak self] in
            Task { @MainActor in
                await self?.reload()
            }
        }
        PHPhotoLibrary.shared().register(observer)
        changeObserver = observer
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

/// Forwards PhotoKit change notifications, which arrive on a background queue.
nonisolated private final class LibraryChangeObserver: NSObject, PHPhotoLibraryChangeObserver, Sendable {
    private let onChange: @Sendable () -> Void

    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        onChange()
    }
}
