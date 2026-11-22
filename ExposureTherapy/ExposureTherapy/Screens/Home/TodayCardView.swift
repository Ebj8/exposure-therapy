//
//  TodayCardView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → Home → 4. Today's session card.
//

import SwiftUI

struct TodayCardView: View {
    /// Photos waiting in today's session.
    let count: Int
    /// The month the session starts in, for "Picking up where you left off".
    let startMonth: MonthKey?
    /// True once today's goal is met.
    let isDoneForToday: Bool
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
            HStack {
                Text("TODAY'S SESSION")
                    .font(.inter(14, .bold, relativeTo: .footnote))
                    .tracking(1.5)
                    .foregroundStyle(.blush)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !isDoneForToday && count > 0 {
                    Text("about \(Stats.minutesEstimate(photoCount: count)) min")
                        .font(.inter(14, relativeTo: .footnote))
                        .foregroundStyle(.brandWhite.opacity(0.85))
                }
            }
            // A one-line eyebrow; it wraps awkwardly at the largest sizes.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)

            Text(headline)
                .font(.bricolage(26, relativeTo: .title))
                .foregroundStyle(.brandWhite)
                .fixedSize(horizontal: false, vertical: true)

            if count == 0 {
                Text("Your whole library has been reviewed. New photos will show up here.")
                    .font(.inter(16))
                    .foregroundStyle(.brandWhite.opacity(0.9))
            } else if let startMonth {
                Text("Picking up where you left off in \(startMonth.title).")
                    .font(.inter(16))
                    .foregroundStyle(.brandWhite.opacity(0.9))
            }

            if count > 0 {
                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Text(isDoneForToday ? "Keep going" : "Start swiping")
                        Image(systemName: "arrow.right")
                            .font(.body.bold())
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.pill)
                .padding(.top, 4)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.plum, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var headline: String {
        if count == 0 {
            return "Every photo has heard back."
        }
        if isDoneForToday {
            return "You've hit your goal for today."
        }
        return count == 1 ? "1 photo is waiting to hear back." : "\(count) photos are waiting to hear back."
    }
}

#Preview("Waiting") {
    TodayCardView(count: 50, startMonth: MonthKey(year: 2019, month: 6), isDoneForToday: false) {}
        .padding()
        .background(.cream)
}

#Preview("Library done") {
    TodayCardView(count: 0, startMonth: nil, isDoneForToday: false) {}
        .padding()
        .background(.cream)
}

#Preview("Caught up") {
    TodayCardView(count: 50, startMonth: MonthKey(year: 2019, month: 7), isDoneForToday: true) {}
        .padding()
        .background(.cream)
}
