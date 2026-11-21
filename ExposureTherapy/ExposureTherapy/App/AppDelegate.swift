//
//  AppDelegate.swift
//  ExposureTherapy
//
//  Tapping a reminder opens the app on Home (SPEC.md → Daily reminder).
//

import UIKit
import UserNotifications

extension Notification.Name {
    /// Posted when a reminder is tapped; the root view returns to Home.
    static let openHome = Notification.Name("ExposureTherapy.openHome")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set before launch finishes so a tap that launches the app is delivered.
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            NotificationCenter.default.post(name: .openHome, object: nil)
        }
    }

    /// Shows the reminder even if the app happens to be open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
