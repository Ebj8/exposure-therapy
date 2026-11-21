//
//  LibrarySnapshot.swift
//  ExposureTherapy
//
//  The stats Home and Session complete both show, built the same way from
//  the same records so the two screens always agree.
//

import Foundation

struct LibrarySnapshot {
    let progress: LibraryProgress
    let streak: Int
    /// Sum of `DeletedPhoto.bytes`.
    let bytesFreed: Int64

    init(index: LibraryIndex, decisions: [PhotoDecision], deletedPhotos: [DeletedPhoto], sessions: [Session], now: Date = .now) {
        progress = LibraryProgress(
            index: index,
            reviewedIDs: Set(decisions.lazy.filter(\.countsAsReviewed).map(\.assetID)),
            deletedMonthKeys: deletedPhotos.map(\.monthKey)
        )
        let finished = sessions.filter {
            Stats.countsTowardStreak(endedAt: $0.endedAt, keptCount: $0.keptCount, deletedCount: $0.deletedCount)
        }
        streak = Stats.streak(finishedSessionDates: finished.compactMap(\.endedAt), now: now)
        bytesFreed = deletedPhotos.reduce(0) { $0 + $1.bytes }
    }
}
