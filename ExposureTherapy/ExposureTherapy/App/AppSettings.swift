//
//  AppSettings.swift
//  ExposureTherapy
//
//  SPEC.md → Data → `@AppStorage` settings: keys and defaults in one place.
//

import Foundation

enum SettingsKey {
    /// Photos per daily session: 25, 50 or 100.
    static let dailyGoal = "dailyGoal"
    static let reminderEnabled = "reminderEnabled"
    /// Minutes after midnight, e.g. 1200 for 8:00 PM.
    static let reminderTime = "reminderTime"
    static let lastAlbumID = "lastAlbumID"
    /// Longest streak so far, for "new best".
    static let bestStreak = "bestStreak"
}

enum SettingsDefault {
    static let dailyGoal = 50
    static let reminderTime = 20 * 60
}

extension Int {
    /// Formats minutes after midnight as a time, e.g. 1200 → "8:00 PM".
    var minutesAfterMidnightText: String {
        let components = DateComponents(hour: self / 60, minute: self % 60)
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
