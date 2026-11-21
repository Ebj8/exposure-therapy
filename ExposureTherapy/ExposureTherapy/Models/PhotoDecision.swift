//
//  PhotoDecision.swift
//  ExposureTherapy
//
//  SPEC.md → Data → SwiftData models. One row per reviewed photo.
//

import Foundation
import SwiftData

/// What you decided about a photo.
nonisolated enum Decision: String, Codable, CaseIterable, Sendable {
    case keep
    case heart
    case album
    /// Pending until its Breakup succeeds; the photo then gets a `DeletedPhoto` row.
    case unmatch
}

@Model
final class PhotoDecision {
    @Attribute(.unique) var assetID: String
    var decision: Decision
    var decidedAt: Date
    var sessionID: UUID
    /// True if this heart turned Favorite on (it wasn't already), so undo
    /// turns it back off.
    var madeFavorite: Bool = false
    /// The album this decision added the photo to, if it wasn't already in
    /// it, so undo takes it back out.
    var addedToAlbumID: String?

    init(
        assetID: String,
        decision: Decision,
        decidedAt: Date = .now,
        sessionID: UUID,
        madeFavorite: Bool = false,
        addedToAlbumID: String? = nil
    ) {
        self.assetID = assetID
        self.decision = decision
        self.decidedAt = decidedAt
        self.sessionID = sessionID
        self.madeFavorite = madeFavorite
        self.addedToAlbumID = addedToAlbumID
    }

    /// Keep, heart and album count as reviewed. A pending unmatch doesn't
    /// until the photo is actually deleted.
    var countsAsReviewed: Bool {
        decision != .unmatch
    }
}
