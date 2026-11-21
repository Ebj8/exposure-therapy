//
//  SettingsView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → Settings: a plain list.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(SettingsKey.dailyGoal) private var dailyGoal = SettingsDefault.dailyGoal
    @AppStorage(SettingsKey.reminderEnabled) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderTime) private var reminderTime = SettingsDefault.reminderTime
    @AppStorage(SettingsKey.bestStreak) private var bestStreak = 0

    @State private var isConfirmingReset = false
    @State private var didReset = false

    /// The reminder time as a Date for the picker, stored as minutes after midnight.
    private var reminderDate: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: reminderTime / 60, minute: reminderTime % 60)) ?? .now
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderTime = (components.hour ?? 20) * 60 + (components.minute ?? 0)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Photos per session", selection: $dailyGoal) {
                    Text("25").tag(25)
                    Text("50").tag(50)
                    Text("100").tag(100)
                }
            } header: {
                Text("Daily session")
            }

            Section {
                Toggle("Daily reminder", isOn: $reminderEnabled)
                if reminderEnabled {
                    DatePicker("Time", selection: reminderDate, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Reminder")
            } footer: {
                Text("Skipped on days you've already finished your session.")
            }

            Section {
                Button("Reset progress", role: .destructive) {
                    isConfirmingReset = true
                }
            } footer: {
                Text("Clears your decisions and stats. Your photos are never touched.")
            }
        }
        .font(.inter(16))
        .tint(.rose)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset progress?", isPresented: $isConfirmingReset) {
            Button("Reset", role: .destructive, action: resetProgress)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears every decision, session and stat. Nothing is deleted from Photos.")
        }
        .alert("Progress reset", isPresented: $didReset) {
            Button("OK", role: .cancel) {}
        }
    }

    /// Clears decisions and stats only, never photos.
    private func resetProgress() {
        try? modelContext.delete(model: PhotoDecision.self)
        try? modelContext.delete(model: DeletedPhoto.self)
        try? modelContext.delete(model: Session.self)
        try? modelContext.save()
        bestStreak = 0
        didReset = true
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(PreviewData.container)
}
