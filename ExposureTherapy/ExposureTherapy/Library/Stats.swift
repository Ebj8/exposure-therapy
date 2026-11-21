//
//  Stats.swift
//  ExposureTherapy
//
//  SPEC.md → Stats, streaks and reminders. Every stat is computed from the
//  SwiftData records, so nothing is double-counted.
//

import Foundation

nonisolated enum Stats {
    /// Consecutive calendar days, ending today or yesterday, with at least
    /// one finished session that had 1+ decision.
    ///
    /// - Parameter finishedSessionDates: `endedAt` of every finished session
    ///   that had at least one decision.
    static func streak(finishedSessionDates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(finishedSessionDates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        var day: Date
        if days.contains(today) {
            day = today
        } else if days.contains(yesterday) {
            day = yesterday
        } else {
            return 0
        }

        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// True if a session counts toward the streak.
    static func countsTowardStreak(endedAt: Date?, keptCount: Int, deletedCount: Int) -> Bool {
        endedAt != nil && keptCount + deletedCount > 0
    }

    /// MB below 1 GB, GB with one decimal above, e.g. "212 MB" or "3.2 GB".
    static func storageText(bytes: Int64) -> String {
        let gigabyte: Double = 1_000_000_000
        let value = Double(max(bytes, 0))
        if value < gigabyte {
            return "\(Int((value / 1_000_000).rounded())) MB"
        }
        return (value / gigabyte).formatted(.number.precision(.fractionLength(1))) + " GB"
    }

    /// Queue size × 6 seconds, rounded up to whole minutes.
    static func minutesEstimate(photoCount: Int) -> Int {
        (photoCount * 6 + 59) / 60
    }
}
