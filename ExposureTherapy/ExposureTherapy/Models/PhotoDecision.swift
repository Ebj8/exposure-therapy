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

    init(assetID: String, decision: Decision, decidedAt: Date = .now, sessionID: UUID) {
        self.assetID = assetID
        self.decision = decision
        self.decidedAt = decidedAt
        self.sessionID = sessionID
    }

    /// Keep, heart and album count as reviewed. A pending unmatch doesn't
    /// until the photo is actually deleted.
    var countsAsReviewed: Bool {
        decision != .unmatch
    }
}
