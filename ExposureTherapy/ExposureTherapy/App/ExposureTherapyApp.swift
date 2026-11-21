//
//  ExposureTherapyApp.swift
//  ExposureTherapy
//
//  Created by Eli Johnson on 11/20/26.
//

import SwiftUI

@main
struct ExposureTherapyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// The navigation stack that hosts every screen, with Home at the root.
struct RootView: View {
    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .swipeDeck: SwipeDeckView()
                    case .yourExes: YourExesView()
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
}
