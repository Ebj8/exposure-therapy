//
//  AppRoute.swift
//  ExposureTherapy
//
//  Navigation for the Home → Swipe deck → Your exes → Session complete loop.
//

import SwiftUI

/// Which photos the Swipe deck serves.
enum DeckMode: Hashable {
    /// The next `dailyGoal` unreviewed photos, across months.
    case daily
    /// Every unreviewed photo in one month.
    case month(MonthKey)
}

/// Screens pushed on top of Home.
enum AppRoute: Hashable {
    case swipeDeck(DeckMode)
    case yourExes
    case sessionComplete
    case settings
}

/// Owns the navigation path so any screen can move forward or return Home.
@Observable
final class Router {
    var path: [AppRoute] = []

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToHome() {
        path.removeAll()
    }
}
