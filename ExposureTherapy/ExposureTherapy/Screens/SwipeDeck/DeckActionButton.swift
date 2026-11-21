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
        /// Teal circle with a white icon.
        case match
    }

    let systemImage: String
    let accessibilityLabel: String
    let kind: Kind
    /// 48 for small buttons, 68 for Unmatch and Match.
    let diameter: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.4, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: diameter, height: diameter)
                .background(fill, in: Circle())
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
        case .match: .brandWhite
        }
    }

    private var fill: Color {
        switch kind {
        case .match: .brandTeal
        case .plain, .unmatch: .brandWhite
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
        DeckActionButton(systemImage: "checkmark", accessibilityLabel: "Match", kind: .match, diameter: 68) {}
    }
    .padding()
    .background(.cream)
}
