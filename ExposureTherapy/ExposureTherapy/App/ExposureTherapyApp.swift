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
        .task {
            await library.start()
        }
        .onChange(of: scenePhase) { _, phase in
            // Photo access may have changed in the Settings app.
            if phase == .active {
                Task { await library.refreshAuthorization() }
            }
        }
    }

    private var navigationStack: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .swipeDeck(let mode): SwipeDeckView(mode: mode)
                    case .yourExes(let sessionID): YourExesView(sessionID: sessionID)
                    case .sessionComplete: SessionCompleteView()
                    case .settings: SettingsView()
                    }
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
