//
//  HomeView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 1. Home.
//

import Photos
import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(PhotoLibrary.self) private var library
    @Query private var decisions: [PhotoDecision]
    @Query private var deletedPhotos: [DeletedPhoto]
    @Query private var sessions: [Session]
    @AppStorage(SettingsKey.dailyGoal) private var dailyGoal = SettingsDefault.dailyGoal
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The year picked with the chevrons; nil means the default year.
    @State private var selectedYear: Int?

    var body: some View {
        let snapshot = LibrarySnapshot(index: library.index, decisions: decisions, deletedPhotos: deletedPhotos, sessions: sessions)
        let progress = snapshot.progress

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.blockLoose) {
                header
                title

                if library.authorization == .limited {
                    LimitedAccessBanner()
                }

                if !library.hasLoaded {
                    ProgressView()
                        .tint(.rose)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if progress.totalPhotos == 0 {
                    EmptyLibraryView(isLimited: library.authorization == .limited)
                } else {
                    statTiles(snapshot)
                    todayCard
                    LibraryProgressView(reviewed: progress.reviewedPhotos, total: progress.totalPhotos)
                        .padding(.top, 8)
                    yearGrid(progress)
                        // Month tiles are fixed squares; past this size labels can't fit.
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.screen)
        }
        .background(.cream)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("AppIconImage")
                .resizable()
                .frame(width: Size.headerIcon, height: Size.headerIcon)
                .clipShape(RoundedRectangle(cornerRadius: Radius.headerIcon, style: .continuous))
                .accessibilityHidden(true)

            Text("Exposure Therapy")
                .font(.bricolage(19, relativeTo: .headline))
                .foregroundStyle(.plum)

            Spacer()

            RoundIconButton(systemImage: "gearshape", accessibilityLabel: "Settings") {
                router.push(.settings)
            }
        }
        .padding(.top, 8)
        // The header is a fixed row; past this size the title crowds the icon.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ready to let go?")
                .font(.bricolage(34, relativeTo: .largeTitle))
                .foregroundStyle(.plum)
            Text("Your camera roll misses you. Some of it, anyway.")
                .font(.inter(16))
                .foregroundStyle(.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var todayCard: some View {
        let doneToday = DailyPlan.doneToday(decisions: decisions, sessions: sessions)
        let queue = DailyPlan.queue(
            index: library.index,
            excluding: Set(decisions.map(\.assetID)),
            limit: DailyPlan.batchSize(goal: dailyGoal, doneToday: doneToday)
        )
        return TodayCardView(
            count: queue.count,
            startMonth: queue.first?.month,
            isDoneForToday: doneToday >= dailyGoal
        ) {
            router.push(.swipeDeck(.daily))
        }
    }

    private func statTiles(_ snapshot: LibrarySnapshot) -> some View {
        // Side by side normally; stacked at accessibility text sizes.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            StatTileView(systemImage: "flame", iconColor: .rose, value: snapshot.streak.formatted(), label: "day streak")
            StatTileView(systemImage: "trash", iconColor: .brandTeal, value: Stats.storageText(bytes: snapshot.bytesFreed), label: "let go")
            StatTileView(systemImage: "photo", iconColor: .plum, value: "\(snapshot.progress.percentReviewed)%", label: "reviewed")
        }
    }

    @ViewBuilder
    private func yearGrid(_ progress: LibraryProgress) -> some View {
        if let range = progress.yearRange, let defaultYear = progress.defaultYear {
            // Clamp in case the library changed and the picked year is gone.
            let year = Binding {
                min(max(selectedYear ?? defaultYear, range.lowerBound), range.upperBound)
            } set: {
                selectedYear = $0
            }
            YearGridView(progress: progress, year: year) { month in
                router.push(.swipeDeck(.month(month)))
            }
        }
    }
}

#Preview("Full access") {
    NavigationStack {
        HomeView()
    }
    .environment(Router())
    .environment(PreviewData.library())
    .modelContainer(PreviewData.container)
}

#Preview("Limited access") {
    NavigationStack {
        HomeView()
    }
    .environment(Router())
    .environment(PreviewData.library(authorization: .limited))
    .modelContainer(PreviewData.container)
}

#Preview("Empty library") {
    NavigationStack {
        HomeView()
    }
    .environment(Router())
    .environment(PhotoLibrary(previewIndex: .empty))
    .modelContainer(PreviewData.emptyContainer)
}
