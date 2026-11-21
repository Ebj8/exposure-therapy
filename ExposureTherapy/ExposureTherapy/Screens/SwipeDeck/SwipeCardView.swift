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
    /// 0 to 1; follows drag distance.
    var matchOpacity: Double = 0
    var unmatchOpacity: Double = 0

    @Environment(PhotoLibrary.self) private var library
    @State private var photo: CardPhoto?
    @State private var didFail = false

    private let shape = RoundedRectangle(cornerRadius: Radius.swipeCard, style: .continuous)

    var body: some View {
        Color.line
            .overlay {
                if let photo {
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFill()
                } else if didFail {
                    Label("Couldn't load this photo", systemImage: "exclamationmark.triangle")
                        .font(.inter(15, .semibold))
                        .foregroundStyle(.muted)
                } else {
                    SkeletonView()
                }
            }
            .clipShape(shape)
            .overlay(alignment: .bottom) {
                if let photo {
                    chips(for: photo)
                }
            }
            .overlay(alignment: .topLeading) {
                StampView(text: "MATCH", color: .brandTeal, angle: -14)
                    .opacity(matchOpacity)
                    .padding(28)
            }
            .overlay(alignment: .topTrailing) {
                StampView(text: "UNMATCH", color: .coral, angle: 14)
                    .opacity(unmatchOpacity)
                    .padding(28)
            }
            .contentShape(shape)
            .shadow(color: .plum.opacity(0.18), radius: 18, y: 10)
            .task(id: targetSize) {
                guard targetSize.width > 0, photo == nil else { return }
                photo = await library.cardPhoto(for: assetID, targetSize: targetSize)
                didFail = photo == nil
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.plum.opacity(0.8), in: Capsule())
    }
}

/// The tilted MATCH / UNMATCH stamp.
private struct StampView: View {
    let text: String
    let color: Color
    let angle: Double

    var body: some View {
        Text(text)
            .font(.bricolage(32))
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(color, lineWidth: 4)
            }
            .rotationEffect(.degrees(angle))
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        SwipeCardView(assetID: "preview-2019-06-12", targetSize: CGSize(width: 600, height: 800), matchOpacity: 1)
        SwipeCardView(assetID: "preview-2019-06-13", targetSize: CGSize(width: 600, height: 800), unmatchOpacity: 0.6)
    }
    .padding(20)
    .background(.cream)
    .environment(PreviewData.library())
}
