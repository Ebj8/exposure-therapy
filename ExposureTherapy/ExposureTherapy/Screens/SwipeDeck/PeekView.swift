//
//  PeekView.swift
//  ExposureTherapy
//
//  A full-screen look at the photos around the one on the card. Swipe
//  sideways to compare; swipe down or tap ✕ to go back to deciding.
//

import SwiftUI

/// What to show in the peek: nearby photos and where to start.
struct PeekRequest: Identifiable {
    let assetIDs: [String]
    let startID: String
    var id: String { startID }
}

struct PeekView: View {
    let request: PeekRequest
    let status: (String) -> SwipeDeckModel.NeighborStatus

    @Environment(\.dismiss) private var dismiss
    @State private var selection: String
    /// Follows a downward drag, for swipe-to-close.
    @State private var dismissOffset: CGFloat = 0

    init(request: PeekRequest, status: @escaping (String) -> SwipeDeckModel.NeighborStatus) {
        self.request = request
        self.status = status
        _selection = State(initialValue: request.startID)
    }

    private var positionText: String {
        let position = (request.assetIDs.firstIndex(of: selection) ?? 0) + 1
        return "\(position) of \(request.assetIDs.count)"
    }

    var body: some View {
        ZStack {
            Color.plum.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(request.assetIDs, id: \.self) { assetID in
                    PeekPage(assetID: assetID, status: status(assetID))
                        .tag(assetID)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(y: dismissOffset)
            .simultaneousGesture(dismissGesture)
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Text(positionText)
                    .font(.inter(15, .semibold))
                    .foregroundStyle(.brandWhite.opacity(0.85))
                    .contentTransition(.numericText())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.brandWhite)
                        .frame(width: Size.minTapTarget, height: Size.minTapTarget)
                        .background(.plumRaised, in: Circle())
                }
                .accessibilityLabel("Back to deciding")
            }
            .padding(.horizontal, Spacing.screen)
        }
        .safeAreaInset(edge: .bottom) {
            Text("Swipe to compare · swipe down to close")
                .font(.inter(14, relativeTo: .footnote))
                .foregroundStyle(.brandWhite.opacity(0.7))
                .padding(.bottom, 8)
        }
    }

    /// A mostly vertical downward drag closes the peek; sideways drags page.
    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let dy = value.translation.height
                if dy > 0 && dy > abs(value.translation.width) {
                    dismissOffset = dy
                }
            }
            .onEnded { value in
                if dismissOffset > 120 || value.velocity.height > 800 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        dismissOffset = 0
                    }
                }
            }
    }
}

/// One photo in the peek, fit to the screen, with its date and status.
private struct PeekPage: View {
    let assetID: String
    let status: SwipeDeckModel.NeighborStatus

    @Environment(PhotoLibrary.self) private var library
    @Environment(\.displayScale) private var displayScale
    @State private var photo: CardPhoto?

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: Spacing.block) {
                Spacer(minLength: 0)
                ZStack {
                    if let photo {
                        Image(uiImage: photo.image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    } else {
                        ProgressView().tint(.brandWhite)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: proxy.size.height * 0.8)

                HStack(spacing: 8) {
                    statusPill
                    if let date = photo?.creationDate {
                        Text(SwipeCardView.dateText(date))
                            .font(.inter(14, .semibold))
                            .foregroundStyle(.brandWhite.opacity(0.85))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.screen)
            .task(id: proxy.size) {
                guard proxy.size.width > 0, photo == nil else { return }
                let target = CGSize(width: proxy.size.width * displayScale, height: proxy.size.height * displayScale)
                photo = await library.cardPhoto(for: assetID, targetSize: target)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusPill: some View {
        switch status {
        case .current:
            pill("Deciding now", fill: .rose)
        case .kept:
            pill("Kept", fill: .brandTeal)
        case .ex:
            pill("Ex", fill: .coral)
        case .undecided:
            EmptyView()
        }
    }

    private func pill(_ text: String, fill: Color) -> some View {
        Text(text)
            .font(.inter(13, .bold))
            .foregroundStyle(.brandWhite)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(fill, in: Capsule())
    }
}

#Preview {
    let ids = (25..<38).map { "preview-2019-06-\($0)" }
    PeekView(
        request: PeekRequest(assetIDs: ids, startID: "preview-2019-06-31"),
        status: { id in
            switch id {
            case "preview-2019-06-31": .current
            case "preview-2019-06-30": .ex
            case "preview-2019-06-29": .kept
            default: .undecided
            }
        }
    )
    .environment(PreviewData.library())
}
