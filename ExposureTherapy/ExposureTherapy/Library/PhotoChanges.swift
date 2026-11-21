//
//  PhotoChanges.swift
//  ExposureTherapy
//
//  SPEC.md → Gestures and interactions, and Deletion (Breakup). The edits
//  the app makes in Apple Photos. `deletePhotos` must only be called from
//  the Breakup flow.
//

import Photos

/// A user album that photos can be added to.
nonisolated struct PhotoAlbum: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let count: Int
}

/// What to record about a photo before it's deleted, so stats survive it.
nonisolated struct DeletionCandidate: Sendable {
    let assetID: String
    let bytes: Int64
    /// `MonthKey.rawValue`, or `MonthKey.undatedRawValue`.
    let monthKey: String
}

nonisolated enum DeletionResult: Sendable {
    case deleted
    /// You tapped Don't Allow / Cancel on iOS's confirmation.
    case cancelled
    case failed
}

/// Every function here runs off the main actor; PhotoKit change blocks run
/// on a background queue, so they must not touch main-actor state.
nonisolated enum PhotoChanges {
    /// Sets the photo's Favorite flag. Returns true only if this call changed
    /// it, so undo knows whether to change it back.
    @concurrent
    static func setFavorite(_ isFavorite: Bool, assetID: String) async -> Bool {
        guard let asset = asset(assetID), asset.isFavorite != isFavorite else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let asset = Self.asset(assetID) else { return }
                PHAssetChangeRequest(for: asset).isFavorite = isFavorite
            }
            return true
        } catch {
            return false
        }
    }

    /// Adds the photo to an album. Returns true only if this call added it
    /// (it wasn't already there), so undo knows whether to remove it.
    @concurrent
    static func addToAlbum(assetID: String, albumID: String) async -> Bool {
        guard let album = album(albumID), !contains(album, assetID: assetID) else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let album = Self.album(albumID), let asset = Self.asset(assetID) else { return }
                PHAssetCollectionChangeRequest(for: album)?.addAssets([asset] as NSArray)
            }
            return true
        } catch {
            return false
        }
    }

    /// Takes the photo back out of an album. The photo itself stays in the library.
    @concurrent
    static func removeFromAlbum(assetID: String, albumID: String) async {
        try? await PHPhotoLibrary.shared().performChanges {
            guard let album = Self.album(albumID), let asset = Self.asset(assetID) else { return }
            PHAssetCollectionChangeRequest(for: album)?.removeAssets([asset] as NSArray)
        }
    }

    /// Creates an empty album and returns its ID.
    @concurrent
    static func createAlbum(named title: String) async -> String? {
        let createdID = CreatedID()
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: title)
                createdID.value = request.placeholderForCreatedAssetCollection.localIdentifier
            }
            return createdID.value
        } catch {
            return nil
        }
    }

    /// Albums you made that accept new photos, newest first. PhotoKit returns
    /// user albums oldest first by default, so the list is reversed.
    @concurrent
    static func albums() async -> [PhotoAlbum] {
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var albums: [PhotoAlbum] = []
        collections.enumerateObjects { collection, _, _ in
            guard collection.canPerform(.addContent) else { return }
            albums.append(PhotoAlbum(
                id: collection.localIdentifier,
                title: collection.localizedTitle ?? "Untitled album",
                count: PHAsset.fetchAssets(in: collection, options: nil).count
            ))
        }
        return albums.reversed()
    }

    // MARK: Breakup

    /// Reads size and month for each photo still in the library. Photos that
    /// are already gone are left out.
    @concurrent
    static func deletionCandidates(for assetIDs: [String]) async -> [DeletionCandidate] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        var candidates: [DeletionCandidate] = []
        result.enumerateObjects { asset, _, _ in
            let monthKey = asset.creationDate.map { MonthKey(date: $0).rawValue } ?? MonthKey.undatedRawValue
            candidates.append(DeletionCandidate(
                assetID: asset.localIdentifier,
                bytes: CardImageLoader.fileSize(of: asset) ?? 0,
                monthKey: monthKey
            ))
        }
        return candidates
    }

    /// Moves the photos to Recently Deleted. iOS asks you to confirm first.
    /// Only the Breakup flow (SPEC.md → Deletion) may call this.
    @concurrent
    static func deletePhotos(_ assetIDs: [String]) async -> DeletionResult {
        guard !assetIDs.isEmpty else { return .deleted }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
                PHAssetChangeRequest.deleteAssets(assets)
            }
            return .deleted
        } catch let error as PHPhotosError where error.code == .userCancelled {
            return .cancelled
        } catch {
            return .failed
        }
    }

    // MARK: Helpers

    private static func asset(_ id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    private static func album(_ id: String) -> PHAssetCollection? {
        PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject
    }

    private static func contains(_ album: PHAssetCollection, assetID: String) -> Bool {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "localIdentifier == %@", assetID)
        return PHAsset.fetchAssets(in: album, options: options).count > 0
    }

    /// Carries the new album's ID out of the change block.
    private final class CreatedID: @unchecked Sendable {
        var value: String?
    }
}
