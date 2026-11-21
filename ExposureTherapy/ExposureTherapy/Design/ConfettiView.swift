//
//  ConfettiView.swift
//  ExposureTherapy
//
//  A short burst of confetti in the brand colors that falls once and is
//  done. Nothing is shown when Reduce Motion is on.
//

import SwiftUI

struct ConfettiView: View {
    var pieceCount = 70

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion {
            GeometryReader { proxy in
                ZStack {
                    ForEach(0..<pieceCount, id: \.self) { index in
                        ConfettiPiece(seed: index, area: proxy.size)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// One piece: starts above the top edge, falls past the bottom while
/// drifting and spinning, then fades out.
private struct ConfettiPiece: View {
    let seed: Int
    let area: CGSize

    @State private var hasFallen = false

    private static let colors: [Color] = [.rose, .brandTeal, .blush, .coral, .plum, .roseDark]

    // Stable pseudo-random values per piece, so redraws don't reshuffle it.
    private func random(_ salt: Int) -> Double {
        var value = UInt64(truncatingIfNeeded: seed &* 2_654_435_761 &+ salt &* 40_503)
        value ^= value >> 13
        value = value &* 0x5bd1e995
        value ^= value >> 15
        return Double(value % 10_000) / 10_000
    }

    var body: some View {
        let startX = random(1) * area.width
        let drift = (random(2) - 0.5) * 160
        let size = 6 + random(3) * 7
        let isStrip = random(4) > 0.5
        let delay = random(5) * 0.35
        let duration = 1.6 + random(6) * 1.0
        let spins = (random(7) - 0.5) * 900

        RoundedRectangle(cornerRadius: isStrip ? 1.5 : size / 2)
            .fill(Self.colors[seed % Self.colors.count])
            .frame(width: size, height: isStrip ? size * 2.2 : size)
            .rotationEffect(.degrees(hasFallen ? spins : 0))
            .position(
                x: startX + (hasFallen ? drift : 0),
                y: hasFallen ? area.height + 40 : -20 - random(8) * 80
            )
            .opacity(hasFallen ? 0 : 1)
            .onAppear {
                withAnimation(.easeIn(duration: duration).delay(delay)) {
                    hasFallen = true
                }
            }
    }
}

#Preview {
    ZStack {
        Color.cream
        ConfettiView()
    }
    .ignoresSafeArea()
}
