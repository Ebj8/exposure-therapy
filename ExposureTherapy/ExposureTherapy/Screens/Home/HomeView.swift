//
//  HomeView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 1. Home. Milestone 1 covers the header and title;
//  stats, today's session, library progress and the year grid come later.
//

import SwiftUI

struct HomeView: View {
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.blockLoose) {
                header
                title
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

    #if DEBUG
    /// Temporary buttons to reach the empty screens until their real
    /// entry points are built in later milestones.
    private var debugScreenLinks: some View {
        VStack(alignment: .leading, spacing: Spacing.blockTight) {
            Text("DEBUG · SCREENS")
                .font(.inter(12, .bold))
                .foregroundStyle(.muted)
            Button("Swipe deck") { router.push(.swipeDeck) }
            Button("Your exes") { router.push(.yourExes) }
            Button("Session complete") { router.push(.sessionComplete) }
        }
        .font(.inter(16, .semibold))
        .tint(.rose)
        .padding(.top, Spacing.blockLoose)
    }
    #endif
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(Router())
}
