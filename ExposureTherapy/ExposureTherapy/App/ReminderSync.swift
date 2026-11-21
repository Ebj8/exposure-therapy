//
//  ReminderSync.swift
//  ExposureTherapy
//
//  Keeps scheduled reminders in step with the settings and your progress.
//  Asks for notification permission the first time the reminder is turned
//  on (from Settings or Session complete), never at launch.
//

import SwiftUI
import SwiftData

struct ReminderSync: View {
    @Environment(PhotoLibrary.self) private var library
    @Environment(\.scenePhase) private var scenePhase
    @Query private var decisions: [PhotoDecision]
    @Query private var deletedPhotos: [DeletedPhoto]
    @Query private var sessions: [Session]

    @AppStorage(SettingsKey.reminderEnabled) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderTime) private var reminderTime = SettingsDefault.reminderTime
    @AppStorage(SettingsKey.dailyGoal) private var dailyGoal = SettingsDefault.dailyGoal

    @State private var isShowingDenied = false

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                await reschedule()
            }
            .onChange(of: reminderEnabled) { _, isOn in
                Task {
                    if isOn, await !ReminderScheduler.requestPermission() {
                        reminderEnabled = false
                        isShowingDenied = true
                    }
                    await reschedule()
                }
            }
            .onChange(of: library.hasLoaded) {
                Task { await reschedule() }
            }
            .onChange(of: reminderTime) {
                Task { await reschedule() }
            }
            .onChange(of: dailyGoal) {
                Task { await reschedule() }
            }
            .onChange(of: scenePhase) { _, phase in
                // Opening the app, or leaving it after a session, refreshes
                // the text and whether today is skipped.
                if phase != .inactive {
                    Task { await reschedule() }
                }
            }
            .alert("Notifications are off", isPresented: $isShowingDenied) {
                OpenSettingsButton()
                Button("Not now", role: .cancel) {}
            } message: {
                Text("To get a daily reminder, allow notifications for Exposure Therapy in Settings.")
            }
    }

    private func reschedule() async {
        guard library.hasLoaded else { return }
        let snapshot = LibrarySnapshot(index: library.index, decisions: decisions, deletedPhotos: deletedPhotos, sessions: sessions)
        let doneToday = DailyPlan.doneToday(decisions: decisions, sessions: sessions)
        let waiting = DailyPlan.queue(
            index: library.index,
            excluding: Set(decisions.map(\.assetID)),
            limit: max(dailyGoal - doneToday, 0)
        ).count
        let context = ReminderScheduler.Context(
            photosToday: waiting,
            dailyGoal: dailyGoal,
            resumeMonth: snapshot.progress.resumeMonth,
            streak: snapshot.streak,
            isTodayDone: doneToday >= dailyGoal
        )
        await ReminderScheduler.reschedule(enabled: reminderEnabled, minutesAfterMidnight: reminderTime, context: context)
    }
}
