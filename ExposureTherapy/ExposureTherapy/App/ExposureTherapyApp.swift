//
//  ExposureTherapyApp.swift
//  ExposureTherapy
//
//  Created by Eli Johnson on 11/20/26.
//

import Photos
import SwiftUI
import SwiftData

@main
struct ExposureTherapyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var library = PhotoLibrary()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
        }
        .modelContainer(for: [PhotoDecision.self, DeletedPhoto.self, Session.self])
    }
}

/// Picks the welcome, denied or main screen from the photo permission, and
/// hosts the navigation stack with Home at the root.
struct RootView: View {
    @Environment(PhotoLibrary.self) private var library
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = Router()
    @AppStorage(SettingsKey.deckStyle) private var deckStyle = SettingsDefault.deckStyle

    var body: some View {
        Group {
            switch library.authorization {
            case .authorized, .limited:
                navigationStack
            case .notDetermined:
                WelcomeView()
            default:
                AccessDeniedView()
            }
        }
        .background {
            if library.hasAccess {
                ReminderSync()
            }
        }
        .task {
            await library.start()
        }
        .task {
            // A tapped reminder opens the app on Home.
            for await _ in NotificationCenter.default.notifications(named: .openHome) {
                router.popToHome()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                library.appDidEnterBackground()
            case .active:
                Task {
                    // After a long absence, refresh PhotoKit before it's needed.
                    await library.appDidBecomeActive()
                    // Photo access may have changed in the Settings app.
                    await library.refreshAuthorization()
                }
            default:
                break
            }
        }
    }

    private var navigationStack: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    Group {
                        switch route {
                        case .swipeDeck(let mode):
                            if deckStyle == DeckStyle.cards.rawValue {
                                SwipeDeckView(mode: mode)
                            } else {
                                GalleryDeckView(mode: mode)
                            }
                        case .yourExes(let sessionID): YourExesView(sessionID: sessionID)
                        case .sessionComplete(let sessionID): SessionCompleteView(sessionID: sessionID)
                        case .settings: SettingsView()
                        }
                    }
                    // Tie each screen's state to its route. Without this, replacing
                    // the path (e.g. "Keep going: {next month}") can reuse the old
                    // screen in the same slot, keeping its @State: the previous deck.
                    .id(route)
                }
        }
        .environment(router)
    }
}

#Preview {
    RootView()
        .environment(PreviewData.library())
        .modelContainer(PreviewData.container)
}
