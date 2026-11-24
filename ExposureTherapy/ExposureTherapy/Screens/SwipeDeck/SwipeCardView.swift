//
//  SwipeCardView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 2. Swipe deck → Card stack, and Gestures → Swipe
//  feel (stamps). One photo card; the deck handles dragging.
//

import SwiftUI

struct SwipeCardView: View {
    let assetID: String
    /// Image size to request, in pixels.
    let targetSize: CGSize
    /// Pinch zoom on the photo (1 is the whole photo), and how far it's
    /// panned, in points from the center. The deck owns the gestures.
    var zoom: CGFloat = 1
    var pan: CGSize = .zero
    /// Reports the card's size on screen, so the deck can keep panning
    /// inside the photo.
    var onDisplaySize: ((CGSize) -> Void)? = nil

    @Environment(PhotoLibrary.self) private var library
    @State private var photo: CardPhoto?
    /// A sharper copy, loaded the first time the photo is zoomed.
    @State private var detailImage: UIImage?
    @State private var didFail = false
    /// Bumped by "Try again" to load the photo once more.
    @State private var attempt = 0

    /// What a load depends on: the size, and which try this is.
    private struct LoadKey: Equatable {
        let size: CGSize
        let attempt: Int
    }

    private let shape = RoundedRectangle(cornerRadius: Radius.swipeCard, style: .continuous)

    /// The photo's width ÷ height once loaded, so the card takes its shape.
    private var aspectRatio: CGFloat? {
        guard let size = photo?.image.size, size.height > 0 else { return nil }
        return size.width / size.height
    }

    var body: some View {
        // Sized to the photo's own shape (as large as fits) so nothing is
        // cropped; the skeleton fills the whole space until it loads.
        Group {
            if let aspectRatio {
                card.aspectRatio(aspectRatio, contentMode: .fit)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                        onDisplaySize?(size)
                    }
            } else {
                card
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The whole slot stays draggable, even beside a wide photo.
        .contentShape(Rectangle())
        .task(id: LoadKey(size: targetSize, attempt: attempt)) {
            guard targetSize.width > 0, photo == nil else { return }
            let loaded = await library.cardPhoto(for: assetID, targetSize: targetSize)
            withAnimation(.easeOut(duration: 0.2)) {
                photo = loaded
                didFail = loaded == nil
            }
        }
        .task(id: zoom > 1) {
            guard zoom > 1, detailImage == nil, photo != nil else { return }
            detailImage = await library.cardPhoto(for: assetID, targetSize: detailSize)?.image
        }
        .accessibilityElement(children: didFail ? .contain : .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(didFail ? [] : .isImage)
    }

    private var card: some View {
        Color.line
            .overlay {
                if let photo {
                    // The card matches the photo's shape, so filling it
                    // crops nothing.
                    Image(uiImage: detailImage ?? photo.image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(zoom)
                        .offset(pan)
                } else if didFail {
                    VStack(spacing: 12) {
                        Label("Couldn't load this photo", systemImage: "exclamationmark.triangle")
                            .font(.inter(15, .semibold))
                            .foregroundStyle(.muted)
                        Button("Try again") {
                            didFail = false
                            attempt += 1
                        }
                        .font(.inter(15, .bold))
                        .foregroundStyle(.roseDark)
                        .padding(.horizontal, 18)
                        .frame(minHeight: Size.minTapTarget)
                        .background(.blush, in: Capsule())
                        .buttonStyle(.plain)
                    }
                } else {
                    SkeletonView()
                }
            }
            .clipShape(shape)
            .overlay(alignment: .bottom) {
                // Out of the way while you look at details.
                if let photo, zoom <= 1 {
                    chips(for: photo)
                        .transition(.opacity)
                }
            }
            .shadow(color: .plum.opacity(0.18), radius: 18, y: 10)
    }

    /// Three times the card's pixels, so details stay sharp when zoomed,
    /// capped so a huge photo doesn't use too much memory.
    private var detailSize: CGSize {
        let scale = min(3, 4096 / max(targetSize.width, targetSize.height, 1))
        return CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
    }

    private func chips(for photo: CardPhoto) -> some View {
        HStack {
            if let date = photo.creationDate {
                ChipView(text: Self.dateText(date))
            }
            Spacer(minLength: 8)
            if let size = photo.fileSize {
                ChipView(text: size.formatted(.byteCount(style: .file)))
            }
        }
        .padding(16)
    }

    /// e.g. "Jun 14, 2019 · 8:42 PM".
    static func dateText(_ date: Date) -> String {
        let day = date.formatted(.dateTime.month(.abbreviated).day().year())
        let time = date.formatted(date: .omitted, time: .shortened)
        return "\(day) · \(time)"
    }

    private var accessibilityDescription: String {
        guard let photo else { return didFail ? "Photo couldn't load" : "Loading photo" }
        var parts = ["Photo"]
        if let date = photo.creationDate { parts.append(Self.dateText(date)) }
        if let size = photo.fileSize { parts.append(size.formatted(.byteCount(style: .file))) }
        return parts.joined(separator: ", ")
    }
}

/// A dark translucent label over the photo.
private struct ChipView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.inter(13, .semibold, relativeTo: .caption))
            .foregroundStyle(.brandWhite)
            .lineLimit(1)
            // Narrow portrait cards: shrink a little before truncating.
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.plum.opacity(0.8), in: Capsule())
    }
}

#Preview {
    VStack(spacing: 20) {
        SwipeCardView(assetID: "preview-2019-06-12", targetSize: CGSize(width: 600, height: 800))
        SwipeCardView(assetID: "preview-2019-06-13", targetSize: CGSize(width: 600, height: 800))
    }
    .padding(20)
    .background(.cream)
    .environment(PreviewData.library())
}
