//
//  MonthTileView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → Home → 6. Year grid: one month tile.
//

import SwiftUI

struct MonthTileView: View {
    let month: MonthProgress

    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        // A square that fills the grid column, with the label laid on top.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background { background }
            .overlay { label }
            .clipShape(shape)
        .overlay {
            if case .inProgress = month.status {
                shape.strokeBorder(.rose, lineWidth: 2)
            }
        }
        .opacity(month.status == .noPhotos ? 0.4 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(month.key.monthName)
        .accessibilityValue(accessibilityStatus)
    }

    private var label: some View {
        VStack(spacing: 2) {
            Text(month.key.shortName)
                .font(.inter(15, .bold, relativeTo: .subheadline))
                .foregroundStyle(labelColor)

            switch month.status {
            case .done:
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(.brandWhite)
            case .inProgress(let percent):
                Text("\(percent)%")
                    .font(.inter(13, .bold, relativeTo: .caption))
                    .foregroundStyle(.roseDark)
            case .notStarted, .noPhotos:
                EmptyView()
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(4)
    }

    private var labelColor: Color {
        switch month.status {
        case .done: .brandWhite
        case .inProgress: .plum
        case .notStarted, .noPhotos: .muted
        }
    }

    @ViewBuilder
    private var background: some View {
        switch month.status {
        case .done:
            Color.brandTeal
        case .inProgress(let percent):
            // Blush fill rises from the bottom to match the percent reviewed.
            Color.brandWhite.overlay(alignment: .bottom) {
                GeometryReader { proxy in
                    Color.blush
                        .frame(height: proxy.size.height * Double(percent) / 100)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        case .notStarted, .noPhotos:
            Color.brandWhite
        }
    }

    private var accessibilityStatus: String {
        switch month.status {
        case .done: "Done"
        case .inProgress(let percent): "\(percent)% reviewed"
        case .notStarted: "Not started"
        case .noPhotos: "No photos"
        }
    }
}

#Preview {
    let june = MonthKey(year: 2019, month: 6)
    HStack(spacing: 6) {
        MonthTileView(month: MonthProgress(key: MonthKey(year: 2019, month: 1), total: 40, reviewed: 40))
        MonthTileView(month: MonthProgress(key: june, total: 100, reviewed: 62))
        MonthTileView(month: MonthProgress(key: MonthKey(year: 2019, month: 7), total: 30, reviewed: 0))
        MonthTileView(month: MonthProgress(key: MonthKey(year: 2019, month: 8), total: 0, reviewed: 0))
    }
    .padding()
    .background(.cream)
}
