//
//  ReminderScheduler.swift
//  ExposureTherapy
//
//  SPEC.md → Stats, streaks and reminders → Daily reminder.
//
//  A single repeating trigger can't skip today or rotate its text, so this
//  schedules one calendar notification per day for the next two weeks and
//  is refreshed whenever the app opens or goes to the background.
//

import Foundation
import UserNotifications

enum ReminderScheduler {
    private static let identifierPrefix = "daily-reminder-"
    private static let daysAhead = 14

    /// What the reminder text can mention.
    struct Context {
        /// Photos waiting today, or a full day's goal for later days.
        let photosToday: Int
        let dailyGoal: Int
        /// The month the next session picks up in.
        let resumeMonth: MonthKey?
        let streak: Int
        /// Today's session is finished, so today's reminder is skipped.
        let isTodayDone: Bool
    }

    /// Asks for notification permission the first time; afterwards returns
    /// the current answer without asking again.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    /// Replaces any scheduled reminders. With `enabled` off, just clears them.
    static func reschedule(enabled: Bool, minutesAfterMidnight: Int, context: Context, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        guard enabled else { return }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        for dayOffset in 0..<daysAhead {
            // If today's session is finished, skip today and keep the following days.
            if dayOffset == 0 && context.isTodayDone { continue }
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = minutesAfterMidnight / 60
            components.minute = minutesAfterMidnight % 60
            guard let fireDate = calendar.date(from: components), fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.body = message(for: day, dayOffset: dayOffset, context: context, calendar: calendar)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: identifierPrefix + MonthKey(date: day).rawValue + "-\(components.day ?? 0)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// Rotates through the reminder lines, one per day.
    static func message(for day: Date, dayOffset: Int, context: Context, calendar: Calendar = .current) -> String {
        let count = dayOffset == 0 ? context.photosToday : context.dailyGoal
        // A fixed four-line cycle, one step per day. Lines that don't apply
        // (no month to mention, streak under 2) pass to the next line.
        let cycle: [String?] = [
            count == 1 ? "Review 1 photo to reach your daily goal." : "Review \(count) photos to reach your daily goal.",
            "Your camera roll misses you.",
            context.resumeMonth.map { "Don't leave \($0.title) on read." },
            // Only while the streak is real: today, or tomorrow if today counted.
            context.streak >= 2 && dayOffset <= 1 ? "Your \(context.streak)-day streak is on the line." : nil,
        ]
        let dayNumber = calendar.ordinality(of: .day, in: .era, for: day) ?? dayOffset
        for step in 0..<cycle.count {
            if let line = cycle[(dayNumber + step) % cycle.count] {
                return line
            }
        }
        return "Your camera roll misses you."
    }
}
