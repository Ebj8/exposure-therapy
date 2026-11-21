//
//  FilmstripView.swift
//  ExposureTherapy
//
//  A row of the photos taken just before and after the one on the card,
//  so you can tell the best shot of a burst. Tap one to peek at it larger.
//

import SwiftUI

struct FilmstripView: View {
    /// Neighbors in library order, with the current photo in the middle
    /// slot. nil slots (past the start or end of the month) stay empty.
    let slots: [String?]
    let status: (String) -> SwipeDeckModel.NeighborStatus
    let onSelect: (String) -> Void

    @Environment(\.displayScale) private var displayScale

    private let thumbSide: CGFloat = 40
    private let currentSide: CGFloat = 50

    /// A slot with a stable identity: the photo's ID, or its side and
    /// distance for an empty slot.
    private struct Slot: Identifiable {
        let id: String
        let assetID: String?
    }

    private var identifiedSlots: [Slot] {
        let middle = slots.count / 2
        return slots.enumerated().map { offset, assetID in
            Slot(id: assetID ?? "empty-\(offset - middle)", assetID: assetID)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(identifiedSlots) { slot in
                if let assetID = slot.assetID {
                    let state = status(assetID)
                    Button {
                        onSelect(assetID)
                    } label: {
                        FilmstripThumb(
                            assetID: assetID,
                            status: state,
                            side: state == .current ? currentSide : thumbSide,
                            targetSize: CGSize(width: currentSide * displayScale, height: currentSide * displayScale)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: state))
                    .accessibilityHint("Opens a larger view to compare nearby photos.")
                } else {
                    // Past the start or end of the month.
                    Color.clear
                        .frame(width: thumbSide, height: thumbSide)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(height: currentSide)
        .animation(.easeOut(duration: 0.2), value: slots)
    }

    private func accessibilityLabel(for state: SwipeDeckModel.NeighborStatus) -> String {
        switch state {
        case .current: "This photo"
        case .kept: "Nearby photo, kept"
        case .ex: "Nearby photo, marked for delete"
        case .undecided: "Nearby photo, not reviewed"
        }
    }
}

private struct FilmstripThumb: View {
    let assetID: String
    let status: SwipeDeckModel.NeighborStatus
    let side: CGFloat
    let targetSize: CGSize

    @Environment(PhotoLibrary.self) private var library
    @State private var image: UIImage?

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    var body: some View {
        Color.line
            .frame(width: side, height: side)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .overlay {
                if status == .ex {
                    Color.plum.opacity(0.5)
                }
            }
            .clipShape(shape)
            .overlay {
                if status == .current {
                    shape.strokeBorder(.rose, lineWidth: 2.5)
                }
            }
            .overlay(alignment: .topTrailing) {
                badge
                    .offset(x: 4, y: -4)
            }
            .task(id: assetID) {
                image = await library.thumbnail(for: assetID, targetSize: targetSize)
            }
    }

    @ViewBuilder
    private var badge: some View {
        switch status {
        case .kept:
            badgeIcon("checkmark", fill: .brandTeal)
        case .ex:
            badgeIcon("xmark", fill: .coral)
        case .current, .undecided:
            EmptyView()
        }
    }

    private func badgeIcon(_ systemImage: String, fill: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 8, weight: .heavy))
            .foregroundStyle(.brandWhite)
            .frame(width: 16, height: 16)
            .background(fill, in: Circle())
            .overlay(Circle().strokeBorder(.cream, lineWidth: 1.5))
    }
}

#Preview {
    // The second photo of a month: two empty slots, one earlier photo, the
    // current photo (31) in the middle, then three after.
    let ids: [String?] = [nil, nil] + (30..<35).map { "preview-2019-06-\($0)" }
    FilmstripView(
        slots: ids,
        status: { id in
            switch id {
            case "preview-2019-06-31": .current
            case "preview-2019-06-28", "preview-2019-06-29": .kept
            case "preview-2019-06-30": .ex
            default: .undecided
            }
        },
        onSelect: { _ in }
    )
    .padding()
    .background(.cream)
    .environment(PreviewData.library())
}
