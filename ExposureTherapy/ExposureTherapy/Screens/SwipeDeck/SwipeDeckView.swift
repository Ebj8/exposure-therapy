//
//  SwipeDeckView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 2. Swipe deck. Placeholder until Milestone 3.
//

import SwiftUI

struct SwipeDeckView: View {
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: Spacing.block) {
            HStack {
                RoundIconButton(systemImage: "chevron.left", accessibilityLabel: "Back") {
                    router.pop()
                }
                Spacer()
                Button("Done") { router.push(.yourExes) }
                    .font(.inter(15, .semibold))
                    .foregroundStyle(.brandWhite)
                    .padding(.horizontal, 18)
                    .frame(minHeight: Size.minTapTarget)
                    .background(.plum, in: Capsule())
            }

            Spacer()
            Text("Swipe deck")
                .font(.bricolage(26))
                .foregroundStyle(.plum)
            Spacer()
        }
        .padding(.horizontal, Spacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.cream)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        SwipeDeckView()
    }
    .environment(Router())
}
