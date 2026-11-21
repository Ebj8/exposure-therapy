//
//  SkeletonView.swift
//  ExposureTherapy
//
//  A placeholder with a soft shimmer, shown while photos load (including
//  iCloud downloads). Holds still when Reduce Motion is on.
//

import SwiftUI

struct SkeletonView: View {
    var cornerRadius: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 to 1: where the highlight is as it sweeps left to right.
    @State private var phase: CGFloat = 0

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(.line)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(
                            colors: [.clear, .brandWhite.opacity(0.55), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 0.6)
                        // Sweeps from just off the left edge to just off the right.
                        .offset(x: -width * 0.6 + phase * width * 1.6)
                    }
                }
            }
            .clipShape(shape)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Loading")
    }
}

#Preview {
    VStack(spacing: 16) {
        SkeletonView(cornerRadius: Radius.swipeCard)
            .frame(height: 320)
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { _ in
                SkeletonView(cornerRadius: 8)
                    .frame(width: 40, height: 40)
            }
        }
    }
    .padding()
    .background(.cream)
}
