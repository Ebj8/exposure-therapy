//
//  LimitedAccessBanner.swift
//  ExposureTherapy
//
//  SPEC.md → Data → Photo access. Shown on Home when access is limited.
//

import SwiftUI

struct LimitedAccessBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.rose)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text("You've shared only some photos. Allow full access to review your whole library.")
                    .font(.inter(14))
                    .foregroundStyle(.plum)
                    .fixedSize(horizontal: false, vertical: true)

                OpenSettingsButton {
                    Text("Open Settings")
                        .font(.inter(14, .bold))
                        .foregroundStyle(.roseDark)
                        .frame(minHeight: Size.minTapTarget)
                        .padding(.horizontal, 16)
                        .background(.blush, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.brandWhite, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .strokeBorder(.line, lineWidth: 1)
        }
    }
}

#Preview {
    LimitedAccessBanner()
        .padding()
        .background(.cream)
}
