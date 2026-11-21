//
//  LibraryProgressView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → Home → 5. Library progress.
//

import SwiftUI

struct LibraryProgressView: View {
    let reviewed: Int
    let total: Int

    private var fraction: Double {
        total == 0 ? 0 : min(1, Double(reviewed) / Double(total))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    titleText
                    Spacer(minLength: 8)
                    countText
                }
                VStack(alignment: .leading, spacing: 2) {
                    titleText
                    countText
                }
            }

            Capsule()
                .fill(.line)
                .frame(height: 10)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(.rose)
                            .frame(width: proxy.size.width * fraction)
                    }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your whole library")
        .accessibilityValue("\(reviewed.formatted()) of \(total.formatted()) photos reviewed")
    }

    private var titleText: some View {
        Text("Your whole library")
            .font(.inter(16, .semibold))
            .foregroundStyle(.plum)
    }

    private var countText: some View {
        Text("\(reviewed.formatted()) of \(total.formatted()) photos")
            .font(.inter(15))
            .foregroundStyle(.muted)
    }
}

#Preview {
    LibraryProgressView(reviewed: 2_140, total: 11_872)
        .padding()
        .background(.cream)
}
