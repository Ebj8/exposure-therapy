//
//  SwipeDeckView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 2. Swipe deck. Placeholder until Milestone 3.
//

import SwiftUI

struct SwipeDeckView: View {
    let mode: DeckMode

    @Environment(Router.self) private var router

    private var title: String {
        switch mode {
        case .daily: "Today's session"
        case .month(let key): key.title
        }
    }

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
            Text(title)
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
        SwipeDeckView(mode: .month(MonthKey(year: 2019, month: 6)))
    }
    .environment(Router())
}
