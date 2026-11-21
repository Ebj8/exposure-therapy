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

    /// - Parameters:
    ///   - index: The current library.
    ///   - reviewedIDs: Asset IDs with a keep, heart or album decision.
    ///   - deletedMonthKeys: `DeletedPhoto.monthKey` for every deleted photo.
    init(index: LibraryIndex, reviewedIDs: Set<String>, deletedMonthKeys: [String]) {
        var deletedPerMonth: [String: Int] = [:]
        for key in deletedMonthKeys {
            deletedPerMonth[key, default: 0] += 1
        }

        var months: [MonthKey: MonthProgress] = [:]
        var total = 0
        var reviewed = 0

        for (key, ids) in index.months {
            let deleted = deletedPerMonth.removeValue(forKey: key.rawValue) ?? 0
            let reviewedHere = ids.reduce(0) { $0 + (reviewedIDs.contains($1) ? 1 : 0) } + deleted
            months[key] = MonthProgress(key: key, total: ids.count + deleted, reviewed: reviewedHere)
            total += ids.count + deleted
            reviewed += reviewedHere
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
        total += index.undated.count
        reviewed += index.undated.reduce(0) { $0 + (reviewedIDs.contains($1) ? 1 : 0) }

        let sortedKeys = months.keys.sorted()
        if let first = sortedKeys.first, let last = sortedKeys.last {
            yearRange = first.year...last.year
        } else {
            yearRange = nil
        }
        resumeMonth = sortedKeys.first { months[$0]?.status != .done }

        self.months = months
        self.totalPhotos = total
        self.reviewedPhotos = reviewed
    }

    /// Share of the library reviewed, 0 to 1.
    var fractionReviewed: Double {
        totalPhotos == 0 ? 0 : Double(reviewedPhotos) / Double(totalPhotos)
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
