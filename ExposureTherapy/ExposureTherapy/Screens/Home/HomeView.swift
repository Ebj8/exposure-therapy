//
//  HomeView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 1. Home. Milestone 2 adds library progress and the
//  year grid; stat tiles and today's session come in later milestones.
//

import Photos
import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(PhotoLibrary.self) private var library
    @Query private var decisions: [PhotoDecision]
    @Query private var deletedPhotos: [DeletedPhoto]
    /// The year picked with the chevrons; nil means the default year.
    @State private var selectedYear: Int?

    var body: some View {
        let progress = LibraryProgress(
            index: library.index,
            reviewedIDs: Set(decisions.lazy.filter(\.countsAsReviewed).map(\.assetID)),
            deletedMonthKeys: deletedPhotos.map(\.monthKey)
        )

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.blockLoose) {
                header
                title

                if library.authorization == .limited {
                    LimitedAccessBanner()
                }

                if library.hasLoaded {
                    LibraryProgressView(reviewed: progress.reviewedPhotos, total: progress.totalPhotos)
                        .padding(.top, 8)
                    yearGrid(progress)
                } else {
                    ProgressView()
                        .tint(.rose)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }

                #if DEBUG
                debugScreenLinks
                #endif
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

    #if DEBUG
    /// Temporary buttons to reach the empty screens until their real
    /// entry points are built in later milestones.
    private var debugScreenLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.blockTight) {
            Text("DEBUG · SCREENS")
                .font(.inter(12, .bold))
                .foregroundStyle(.muted)
            Button("Your exes") { router.push(.yourExes) }
            Button("Session complete") { router.push(.sessionComplete) }
        }
        .font(.inter(16, .semibold))
        .tint(.rose)
        .padding(.top, Spacing.blockLoose)
    }
    #endif
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
