//
//  PillButtonStyle.swift
//  ExposureTherapy
//
//  Full-width, fully rounded buttons (SPEC.md → Shape and spacing).
//

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    var fill: Color = .rose
    var pressedFill: Color = .roseDark
    var foreground: Color = .brandWhite

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(16, .bold))
            .foregroundStyle(foreground)
            // Centered when large text wraps the label.
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, Spacing.screen)
            .background(configuration.isPressed ? pressedFill : fill, in: Capsule())
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    /// The rose primary pill.
    static var pill: PillButtonStyle { PillButtonStyle() }
}

#Preview {
    Button("Allow photo access") {}
        .buttonStyle(.pill)
        .padding()
        .background(.cream)
}
