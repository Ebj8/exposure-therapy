//
//  YourExesView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 3. Your exes. Placeholder until Milestone 5.
//

import SwiftUI

struct YourExesView: View {
    @Environment(Router.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
            RoundIconButton(systemImage: "chevron.left", accessibilityLabel: "Back") {
                router.pop()
            }

            Text("Your exes")
                .font(.bricolage(34, relativeTo: .largeTitle))
                .foregroundStyle(.plum)

            Spacer()

            Button {
                router.push(.sessionComplete)
            } label: {
                Label("Breakup", systemImage: "heart.slash")
                    .font(.inter(16, .bold))
                    .foregroundStyle(.brandWhite)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(.rose, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.cream)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        YourExesView()
    }
    .environment(Router())
}
