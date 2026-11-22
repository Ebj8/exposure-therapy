//
//  EmptyLibraryView.swift
//  ExposureTherapy
//
//  Shown on Home when there are no photos to review, either because the
//  camera roll is empty or because no photos have been shared yet.
//

import SwiftUI

struct EmptyLibraryView: View {
    /// With limited access, the fix is sharing photos rather than taking them.
    let isLimited: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.rose)
                .accessibilityHidden(true)

            Text("Nobody to swipe on yet.")
                .font(.bricolage(26, relativeTo: .title))
                .foregroundStyle(.plum)
                .accessibilityAddTraits(.isHeader)

            Text(isLimited
                 ? "You haven't shared any photos with Exposure Therapy. Allow access to some or all of your library to get started."
                 : "Your camera roll is empty. Take a few photos and they'll show up here.")
                .font(.inter(16))
                .foregroundStyle(.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.brandWhite, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

#Preview("Empty") {
    EmptyLibraryView(isLimited: false)
        .padding()
        .background(.cream)
}

#Preview("Limited, nothing shared") {
    EmptyLibraryView(isLimited: true)
        .padding()
        .background(.cream)
}
