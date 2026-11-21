//
//  LibraryProgress.swift
//  ExposureTherapy
//
//  SPEC.md → Stats. Combines the library index with SwiftData records to
//  work out what's been reviewed. Pure value math, so Previews can feed it
//  sample data.
//

import Foundation

nonisolated struct MonthProgress: Identifiable, Sendable {
    enum Status: Equatable, Sendable {
        /// No photos that month, in the library or deleted.
        case noPhotos
        case notStarted
        /// `percent` is rounded down, so it never shows 100 before it's done.
        case inProgress(percent: Int)
        case done
    }

    let key: MonthKey
    /// Photos in the library now plus photos deleted from this month.
    let total: Int
    /// Reviewed photos in the library now plus photos deleted from this month.
    let reviewed: Int

    var id: MonthKey { key }

    var status: Status {
        if total == 0 { return .noPhotos }
        if reviewed >= total { return .done }
        if reviewed == 0 { return .notStarted }
        return .inProgress(percent: reviewed * 100 / total)
    }
}

nonisolated struct LibraryProgress: Sendable {
    /// Photos in the library now plus deleted photos.
    let totalPhotos: Int
    /// Reviewed photos (keep, heart or album) plus deleted photos.
    let reviewedPhotos: Int
    /// Every year from the oldest photo to the newest, or nil with no dated photos.
    let yearRange: ClosedRange<Int>?
    /// The oldest month that isn't done, where the next session picks up.
    let resumeMonth: MonthKey?

    private let months: [MonthKey: MonthProgress]
    /// Every month with photos, oldest first.
    private let sortedKeys: [MonthKey]

    /// - Parameters:
    ///   - index: The current library.
    ///   - reviewedIDs: Asset IDs with a keep, heart or album decision.
    ///   - deletedMonthKeys: `DeletedPhoto.monthKey` for every deleted photo.
    ///   - deletedIDs: Asset IDs of deleted photos. Right after a Breakup the
    ///     index can still list them until PhotoKit reports the change; they're
    ///     skipped so they aren't counted twice.
    init(index: LibraryIndex, reviewedIDs: Set<String>, deletedMonthKeys: [String], deletedIDs: Set<String> = []) {
        var deletedPerMonth: [String: Int] = [:]
        for key in deletedMonthKeys {
            deletedPerMonth[key, default: 0] += 1
        }

        var months: [MonthKey: MonthProgress] = [:]
        var total = 0
        var reviewed = 0

        for (key, ids) in index.months {
            let deleted = deletedPerMonth.removeValue(forKey: key.rawValue) ?? 0
            var present = 0
            var reviewedPresent = 0
            for id in ids where !deletedIDs.contains(id) {
                present += 1
                if reviewedIDs.contains(id) { reviewedPresent += 1 }
            }
            months[key] = MonthProgress(key: key, total: present + deleted, reviewed: reviewedPresent + deleted)
            total += present + deleted
            reviewed += reviewedPresent + deleted
        }

        // Months where every photo has been deleted still count, and are done.
        for (rawKey, deleted) in deletedPerMonth {
            total += deleted
            reviewed += deleted
            if let key = MonthKey(rawValue: rawKey) {
                months[key] = MonthProgress(key: key, total: deleted, reviewed: deleted)
            }
        }

        // The undated bucket counts toward the library totals but has no tile.
        for id in index.undated where !deletedIDs.contains(id) {
            total += 1
            if reviewedIDs.contains(id) { reviewed += 1 }
        }

        let sortedKeys = months.keys.sorted()
        if let first = sortedKeys.first, let last = sortedKeys.last {
            yearRange = first.year...last.year
        } else {
            yearRange = nil
        }
        resumeMonth = sortedKeys.first { months[$0]?.status != .done }

        self.sortedKeys = sortedKeys
        self.months = months
        self.totalPhotos = total
        self.reviewedPhotos = reviewed
    }

    /// Reviewed ÷ (library now + deleted), rounded down.
    var percentReviewed: Int {
        totalPhotos == 0 ? 0 : reviewedPhotos * 100 / totalPhotos
    }

    /// The oldest unfinished month after `key`, or the oldest unfinished
    /// month overall when there's none after it.
    func nextUnfinishedMonth(after key: MonthKey?) -> MonthKey? {
        if let key, let next = sortedKeys.first(where: { $0 > key && months[$0]?.status != .done }) {
            return next
        }
        return resumeMonth
    }

    /// The year Home opens on: the year of the month in progress, or the
    /// newest year once everything is done.
    var defaultYear: Int? {
        resumeMonth?.year ?? yearRange?.upperBound
    }

    func month(_ key: MonthKey) -> MonthProgress {
        months[key] ?? MonthProgress(key: key, total: 0, reviewed: 0)
    }

    /// January through December of `year`.
    func months(in year: Int) -> [MonthProgress] {
        (1...12).map { month(MonthKey(year: year, month: $0)) }
    }

    func doneCount(in year: Int) -> Int {
        months(in: year).filter { $0.status == .done }.count
    }
}
