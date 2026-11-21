//
//  StatTileView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → Home → 3. Three stat tiles.
//

import SwiftUI

struct StatTileView: View {
    let systemImage: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(height: 24)
                .accessibilityHidden(true)

            Text(value)
                .font(.bricolage(24, relativeTo: .title2))
                .foregroundStyle(.plum)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 4)

            Text(label)
                .font(.inter(14, relativeTo: .footnote))
                .foregroundStyle(.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.brandWhite, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(spacing: 10) {
        StatTileView(systemImage: "flame", iconColor: .rose, value: "6", label: "day streak")
        StatTileView(systemImage: "trash", iconColor: .brandTeal, value: "3.2 GB", label: "let go")
        StatTileView(systemImage: "photo", iconColor: .plum, value: "18%", label: "reviewed")
    }
    .padding()
    .background(.cream)
}
