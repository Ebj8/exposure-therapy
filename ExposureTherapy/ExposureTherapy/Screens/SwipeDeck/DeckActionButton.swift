//
//  DeckActionButton.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 2. Swipe deck → 5. Button row.
//

import SwiftUI

struct DeckActionButton: View {
    enum Kind {
        /// White circle with a colored icon (Undo, Add to album, Heart).
        case plain(Color)
        /// White circle with a coral border and coral icon.
        case unmatch
    }

    let systemImage: String
    let accessibilityLabel: String
    let kind: Kind
    /// 48 for small buttons, 68 for Discard.
    let diameter: CGFloat
    let action: () -> Void

    /// Grows with the text size, capped so the row still fits the screen.
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let diameter = diameter * min(scale, 1.2)
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.4, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: diameter, height: diameter)
                .background(.brandWhite, in: Circle())
                .overlay {
                    if case .unmatch = kind {
                        Circle().strokeBorder(.coral, lineWidth: 3)
                    }
                }
                .shadow(color: .plum.opacity(0.08), radius: 8, y: 3)
                .contentShape(Circle())
        }
        .buttonStyle(DeckButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconColor: Color {
        switch kind {
        case .plain(let color): color
        case .unmatch: .coral
        }
    }
}

/// Shrinks a little when pressed and dims when disabled.
private struct DeckButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    HStack(spacing: 14) {
        DeckActionButton(systemImage: "arrow.uturn.backward", accessibilityLabel: "Undo", kind: .plain(.muted), diameter: 48) {}
            .disabled(true)
        DeckActionButton(systemImage: "xmark", accessibilityLabel: "Unmatch", kind: .unmatch, diameter: 68) {}
        DeckActionButton(systemImage: "plus.square", accessibilityLabel: "Add to album", kind: .plain(.plum), diameter: 48) {}
        DeckActionButton(systemImage: "heart", accessibilityLabel: "Heart", kind: .plain(.rose), diameter: 48) {}
    }
    .padding()
    .background(.cream)
}
