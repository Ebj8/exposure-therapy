//
//  SessionCompleteView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 4. Session complete. Placeholder until Milestone 6.
//

import SwiftUI

struct SessionCompleteView: View {
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: Spacing.block) {
            Spacer()
            Text("Session complete")
                .font(.bricolage(26))
                .foregroundStyle(.brandWhite)
            Spacer()

            Button {
                router.popToHome()
            } label: {
                Text("Back home")
                    .font(.inter(16, .bold))
                    .foregroundStyle(.plum)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(.brandWhite, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.plum)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        SessionCompleteView()
    }
    .environment(Router())
}
