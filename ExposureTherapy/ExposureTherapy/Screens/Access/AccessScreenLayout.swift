//
//  AccessScreenLayout.swift
//  ExposureTherapy
//
//  The layout the access screens share: content centered on the screen,
//  scrolling when large text makes it too tall, with the button pinned at
//  the bottom.
//

import SwiftUI

struct AccessScreenLayout<Content: View, Action: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let action: Action

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.blockLoose) {
                        content
                    }
                    .padding(.horizontal, Spacing.screen)
                    .padding(.vertical, Spacing.blockLoose)
                    // At least a screen tall, so short content stays centered.
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            action
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.block)
                .padding(.bottom, Spacing.screen)
        }
        .background(.cream)
    }
}

#Preview {
    AccessScreenLayout {
        Text("A heading")
            .font(.bricolage(34, relativeTo: .largeTitle))
            .foregroundStyle(.plum)
        Text("Some body text.")
            .font(.inter(16))
            .foregroundStyle(.muted)
    } action: {
        Button("Continue") {}
            .buttonStyle(.pill)
    }
}
