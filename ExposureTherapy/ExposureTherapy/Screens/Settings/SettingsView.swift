//
//  SettingsView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → Settings: a plain list. Rows arrive in Milestone 8.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section {
                Text("Settings arrive in a later milestone.")
                    .font(.inter(15))
                    .foregroundStyle(.muted)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
