//
//  MonthKey.swift
//  ExposureTherapy
//
//  A calendar month that photos are grouped into.
//

import Foundation

nonisolated struct MonthKey: Hashable, Comparable, Sendable {
    let year: Int
    /// 1 (January) through 12 (December).
    let month: Int

    /// Stored in place of a month key for photos with no creation date.
    static let undatedRawValue = "undated"

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    /// The month containing `date` in the phone's calendar.
    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        self.init(year: components.year ?? 0, month: components.month ?? 1)
    }

    /// Parses a stored key like "2019-06". Returns nil for "undated" or bad input.
    init?(rawValue: String) {
        let parts = rawValue.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              (1...12).contains(month)
        else { return nil }
        self.init(year: year, month: month)
    }

    /// Stored form, e.g. "2019-06".
    var rawValue: String {
        String(format: "%04d-%02d", year, month)
    }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    /// The first day of the month, for formatting.
    private var firstDay: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? .distantPast
    }

    /// e.g. "June 2019".
    var title: String {
        firstDay.formatted(.dateTime.month(.wide).year())
    }

    /// e.g. "Jun".
    var shortName: String {
        firstDay.formatted(.dateTime.month(.abbreviated))
    }

    /// e.g. "June".
    var monthName: String {
        firstDay.formatted(.dateTime.month(.wide))
    }
}
