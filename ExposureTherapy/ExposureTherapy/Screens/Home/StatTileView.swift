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

    /// Keeps the values lined up across tiles whatever the icon's shape.
    @ScaledMetric(relativeTo: .title3) private var iconHeight: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(iconColor)
                .frame(height: iconHeight)
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
                .fixedSize(horizontal: false, vertical: true)
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
