//
//  YearGridView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → Home → 6. Year grid.
//

import SwiftUI

struct YearGridView: View {
    let progress: LibraryProgress
    @Binding var year: Int
    let onSelectMonth: (MonthKey) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Six months to a row; three at accessibility text sizes, so the
    /// labels have room to grow.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: dynamicTypeSize.isAccessibilitySize ? 3 : 6)
    }

    var body: some View {
        VStack(spacing: Spacing.block) {
            header

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(progress.months(in: year)) { month in
                    Button {
                        onSelectMonth(month.key)
                    } label: {
                        MonthTileView(month: month)
                    }
                    .buttonStyle(.plain)
                    .disabled(month.status == .noPhotos)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            chevron("chevron.left", label: "Previous year", target: year - 1)

            Spacer()

            VStack(spacing: 2) {
                // String(year) avoids a thousands separator ("2,019").
                Text(String(year))
                    .font(.bricolage(22, relativeTo: .title2))
                    .foregroundStyle(.plum)
                Text("\(progress.doneCount(in: year)) of 12 months done")
                    .font(.inter(15, relativeTo: .subheadline))
                    .foregroundStyle(.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer()

            chevron("chevron.right", label: "Next year", target: year + 1)
        }
    }

    private func chevron(_ systemImage: String, label: String, target: Int) -> some View {
        let isAvailable = progress.yearRange?.contains(target) ?? false
        return RoundIconButton(systemImage: systemImage, accessibilityLabel: label) {
            year = target
        }
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.4)
    }
}

#Preview {
    @Previewable @State var year = 2019
    YearGridView(progress: PreviewData.progress, year: $year) { _ in }
        .padding()
        .background(.cream)
}
