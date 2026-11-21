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

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.plum)
            .frame(width: Size.minTapTarget, height: Size.minTapTarget)
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
