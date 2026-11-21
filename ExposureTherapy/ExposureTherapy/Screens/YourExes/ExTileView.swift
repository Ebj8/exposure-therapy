//
//  ExTileView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 3. Your exes → 2. One tile in the grid.
//

import SwiftUI

struct ExTileView: View {
    let assetID: String
    let isRescued: Bool
    /// Thumbnail size to request, in pixels.
    let targetSize: CGSize

    @Environment(PhotoLibrary.self) private var library
    @State private var image: UIImage?
    @State private var didFail = false

    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        Color.line
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if didFail {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundStyle(.muted)
                } else {
                    SkeletonView()
                }
            }
            .overlay {
                // Marked for delete: dimmed.
                if !isRescued {
                    Color.plum.opacity(0.45)
                }
            }
            .clipShape(shape)
            .overlay(alignment: .topTrailing) {
                if !isRescued {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.brandWhite)
                        .frame(width: 24, height: 24)
                        .background(.coral, in: Circle())
                        .padding(6)
                }
            }
            .overlay(alignment: .bottom) {
                if isRescued {
                    Text("Back together")
                        .font(.inter(11, .bold, relativeTo: .caption2))
                        .foregroundStyle(.brandWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.brandTeal, in: Capsule())
                        .padding(6)
                }
            }
            .overlay {
                if isRescued {
                    shape.strokeBorder(.brandTeal, lineWidth: 3)
                }
            }
            .contentShape(shape)
            .task(id: targetSize) {
                guard targetSize.width > 0, image == nil else { return }
                image = await library.thumbnail(for: assetID, targetSize: targetSize)
                didFail = image == nil
            }
    }
}

#Preview {
    HStack(spacing: 10) {
        ExTileView(assetID: "preview-2019-06-40", isRescued: false, targetSize: CGSize(width: 400, height: 400))
        ExTileView(assetID: "preview-2019-06-41", isRescued: true, targetSize: CGSize(width: 400, height: 400))
    }
    .frame(width: 200)
    .padding()
    .background(.cream)
    .environment(PreviewData.library())
}
