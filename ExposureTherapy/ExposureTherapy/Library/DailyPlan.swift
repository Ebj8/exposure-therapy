//
//  DailyPlan.swift
//  ExposureTherapy
//
//  SPEC.md → Data → Queues: the daily session. The next `dailyGoal`
//  unreviewed photos from the oldest month that isn't done. A session stays
//  within one month, so it ends where the month ends; the next session picks
//  up in the following month.
//

import Foundation

nonisolated struct QueuedPhoto: Sendable {
    let assetID: String
    /// nil for photos with no creation date.
    let month: MonthKey?
}

nonisolated enum DailyPlan {
    /// Up to `limit` photos without a decision, all from the oldest month
    /// that has any left (or the undated photos once every month is done).
    /// The queue never crosses into the next month, so a session ends with
    /// its month and goes to review.
    static func queue(index: LibraryIndex, excluding decided: Set<String>, limit: Int) -> [QueuedPhoto] {
        guard limit > 0 else { return [] }
        for key in index.months.keys.sorted() {
            let remaining = (index.months[key] ?? []).filter { !decided.contains($0) }
            if !remaining.isEmpty {
                return remaining.prefix(limit).map { QueuedPhoto(assetID: $0, month: key) }
            }
        }
        return index.undated
            .filter { !decided.contains($0) }
            .prefix(limit)
            .map { QueuedPhoto(assetID: $0, month: nil) }
    }

    /// Photos to serve: what's left of today's goal, or a fresh goal's worth
    /// once it's met ("Keep going anyway").
    static func batchSize(goal: Int, doneToday: Int) -> Int {
        let left = goal - doneToday
        return left > 0 ? left : goal
    }
}

extension DailyPlan {
    /// Decisions made in daily sessions that started today. Undone decisions
    /// are gone from the records, so they don't count.
    static func doneToday(decisions: [PhotoDecision], sessions: [Session], now: Date = .now, calendar: Calendar = .current) -> Int {
        let todaysSessions = Set(sessions.filter {
            $0.mode == .daily && calendar.isDate($0.startedAt, inSameDayAs: now)
        }.map(\.id))
        guard !todaysSessions.isEmpty else { return 0 }
        return decisions.filter { todaysSessions.contains($0.sessionID) }.count
    }
}
