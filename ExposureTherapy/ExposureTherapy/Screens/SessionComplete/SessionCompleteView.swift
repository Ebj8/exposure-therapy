//
//  SessionCompleteView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 4. Session complete.
//

import SwiftUI
import SwiftData

struct SessionCompleteView: View {
    /// The session that just ended, or nil if Done was tapped before any decision.
    let sessionID: UUID?

    @Environment(Router.self) private var router
    @Environment(PhotoLibrary.self) private var library
    @Query private var sessions: [Session]
    @Query private var decisions: [PhotoDecision]
    @Query private var deletedPhotos: [DeletedPhoto]

    @AppStorage(SettingsKey.bestStreak) private var bestStreak = 0
    @AppStorage(SettingsKey.reminderEnabled) private var reminderEnabled = false
    @AppStorage(SettingsKey.reminderTime) private var reminderTime = SettingsDefault.reminderTime

    /// Worked out once when the screen appears, so it doesn't flicker off
    /// after the new best is saved.
    @State private var isNewBest = false

    private var session: Session? {
        guard let sessionID else { return nil }
        return sessions.first { $0.id == sessionID }
    }

    var body: some View {
        let snapshot = LibrarySnapshot(index: library.index, decisions: decisions, deletedPhotos: deletedPhotos, sessions: sessions)
        let deleted = session?.deletedCount ?? 0

        ScrollView {
            VStack(spacing: Spacing.blockLoose) {
                badge
                    .padding(.top, 8)

                headline(hasDeletes: deleted > 0)

                statGrid(snapshot: snapshot)

                if let month = finishedMonth(in: snapshot.progress) {
                    monthDoneBanner(month: month, percent: snapshot.progress.percentReviewed)
                }

                reminderRow

                buttons(next: nextMonth(in: snapshot.progress))
                    .padding(.top, Spacing.blockTight)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.screen)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.plum)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Record a new best streak once, when the session ends.
            if snapshot.streak > bestStreak {
                isNewBest = true
                bestStreak = snapshot.streak
            }
        }
    }

    // MARK: Header

    private var badge: some View {
        Image(systemName: "heart.slash")
            .font(.system(size: 46, weight: .bold))
            .foregroundStyle(.brandWhite)
            .frame(width: 112, height: 112)
            .background(.rose, in: Circle())
            .rotationEffect(.degrees(-8))
            .accessibilityHidden(true)
    }

    private func headline(hasDeletes: Bool) -> some View {
        VStack(spacing: 6) {
            Text(hasDeletes ? "It's not you,\nit's me." : "Love is in\nthe air.")
                .font(.bricolage(36, relativeTo: .largeTitle))
                .foregroundStyle(.brandWhite)
                .multilineTextAlignment(.center)
            Text(hasDeletes ? "(It's you. You were blurry.)" : "(You kept everything. No notes.)")
                .font(.inter(16))
                .foregroundStyle(.blush)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Stats

    private func statGrid(snapshot: LibrarySnapshot) -> some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        let streak = snapshot.streak
        return LazyVGrid(columns: columns, spacing: 12) {
            statTile(value: (session?.deletedCount ?? 0).formatted(), label: "exes let go")
            statTile(value: (session?.keptCount ?? 0).formatted(), label: "matches kept")
            statTile(value: Stats.storageText(bytes: session?.bytesFreed ?? 0), label: "freed up")
            statTile(
                value: streak == 1 ? "1 day" : "\(streak) days",
                label: isNewBest ? "streak, new best" : "streak",
                valueColor: .blush
            )
        }
    }

    private func statTile(value: String, label: String, valueColor: Color = .brandWhite) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.bricolage(28, relativeTo: .title))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.inter(15, relativeTo: .subheadline))
                .foregroundStyle(.brandWhite.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.plumRaised, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Month banner

    /// The month this session finished, if any: a month it decided photos in
    /// that's now done. When several are, the newest one.
    private func finishedMonth(in progress: LibraryProgress) -> MonthKey? {
        guard let session else { return nil }
        let months: [MonthKey]
        if session.mode == .month {
            months = session.monthKey.flatMap(MonthKey.init(rawValue:)).map { [$0] } ?? []
        } else {
            months = monthsTouched(by: session)
        }
        return months.filter { progress.month($0).status == .done }.max()
    }

    /// Months of the photos a daily session decided, from the library for
    /// kept photos and from the deletion records for deleted ones.
    private func monthsTouched(by session: Session) -> [MonthKey] {
        let sessionAssetIDs = Set(decisions.filter { $0.sessionID == session.id }.map(\.assetID))
        var months = Set<MonthKey>()
        for (key, ids) in library.index.months where ids.contains(where: sessionAssetIDs.contains) {
            months.insert(key)
        }
        for deleted in deletedPhotos where sessionAssetIDs.contains(deleted.assetID) {
            if let key = MonthKey(rawValue: deleted.monthKey) {
                months.insert(key)
            }
        }
        return Array(months)
    }

    private func monthDoneBanner(month: MonthKey, percent: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.brandWhite)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(month.title) is done")
                    .font(.inter(17, .bold))
                Text("Library now \(percent)% reviewed")
                    .font(.inter(15))
            }
            .foregroundStyle(.brandWhite)
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(.brandTeal, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Reminder

    private var reminderRow: some View {
        Toggle(isOn: $reminderEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Remind me tomorrow")
                    .font(.inter(17, .bold))
                    .foregroundStyle(.brandWhite)
                Text("\(reminderTime.minutesAfterMidnightText) · keep the streak alive")
                    .font(.inter(15))
                    .foregroundStyle(.brandWhite.opacity(0.85))
            }
        }
        .tint(.rose)
        .padding(18)
        .background(.plumRaised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    // MARK: Buttons

    /// The next unfinished month after this session's month.
    private func nextMonth(in progress: LibraryProgress) -> MonthKey? {
        let current = session?.monthKey.flatMap(MonthKey.init(rawValue:))
        return progress.nextUnfinishedMonth(after: current)
    }

    private func buttons(next: MonthKey?) -> some View {
        VStack(spacing: 12) {
            Button("Back home") {
                router.popToHome()
            }
            .buttonStyle(PillButtonStyle(fill: .brandWhite, pressedFill: .blush, foreground: .plum))

            if let next {
                Button("Keep going: \(next.title)") {
                    // Replace the finished loop with the next month's deck.
                    router.path = [.swipeDeck(.month(next))]
                }
                .buttonStyle(PillButtonStyle(fill: .clear, pressedFill: .plumRaised, foreground: .brandWhite))
                .overlay {
                    Capsule().strokeBorder(.brandWhite.opacity(0.35), lineWidth: 2)
                }
            }
        }
    }
}

#Preview("With deletes") {
    NavigationStack {
        SessionCompleteView(sessionID: PreviewData.completedSessionID)
    }
    .environment(Router())
    .environment(PreviewData.library())
    .modelContainer(PreviewData.container)
}

#Preview("Zero deletes") {
    NavigationStack {
        SessionCompleteView(sessionID: nil)
    }
    .environment(Router())
    .environment(PreviewData.library())
    .modelContainer(PreviewData.container)
}
