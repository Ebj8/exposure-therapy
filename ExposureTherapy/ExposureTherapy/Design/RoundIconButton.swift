//
//  RoundIconButton.swift
//  ExposureTherapy
//
//  The white 44 pt circular button used for Settings, back and chevrons.
//

import SwiftUI

struct RoundIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundIconLabel(systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// The visual part of `RoundIconButton`, for use inside a `NavigationLink`.
struct RoundIconLabel: View {
    let systemImage: String

    /// Grows with the text size, capped so header rows still fit.
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let scale = min(scale, 1.3)
        Image(systemName: systemImage)
            .font(.system(size: 18 * scale, weight: .medium))
            .foregroundStyle(.plum)
            .frame(width: Size.minTapTarget * scale, height: Size.minTapTarget * scale)
            .background(.brandWhite, in: Circle())
            .contentShape(Circle())
    }
}

#Preview {
    HStack {
        RoundIconButton(systemImage: "chevron.left", accessibilityLabel: "Back") {}
        RoundIconButton(systemImage: "gearshape", accessibilityLabel: "Settings") {}
    }
    .padding()
    .background(.cream)
}
