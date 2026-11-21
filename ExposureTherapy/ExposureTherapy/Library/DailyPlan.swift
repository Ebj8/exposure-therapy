//
//  DailyPlan.swift
//  ExposureTherapy
//
//  SPEC.md → Data → Queues: the daily session. The next `dailyGoal`
//  unreviewed photos, starting in the oldest month that isn't done and
//  continuing into later months.
//

import Foundation

nonisolated struct QueuedPhoto: Sendable {
    let assetID: String
    /// nil for photos with no creation date.
    let month: MonthKey?
}

nonisolated enum DailyPlan {
    /// The next `limit` photos without a decision, oldest month first, then
    /// later months, then undated photos. Months before the oldest unfinished
    /// one have nothing left, so starting from the oldest month is the same
    /// as starting from the oldest unfinished one.
    static func queue(index: LibraryIndex, excluding decided: Set<String>, limit: Int) -> [QueuedPhoto] {
        guard limit > 0 else { return [] }
        var queue: [QueuedPhoto] = []
        for key in index.months.keys.sorted() {
            for assetID in index.months[key] ?? [] where !decided.contains(assetID) {
                queue.append(QueuedPhoto(assetID: assetID, month: key))
                if queue.count == limit { return queue }
            }
        }
        for assetID in index.undated where !decided.contains(assetID) {
            queue.append(QueuedPhoto(assetID: assetID, month: nil))
            if queue.count == limit { return queue }
        }
        return queue
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
