//
//  YourExesView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 3. Your exes, and Deletion (Breakup).
//

import SwiftUI
import SwiftData

struct YourExesView: View {
    @Environment(Router.self) private var router
    @Environment(PhotoLibrary.self) private var library
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayScale) private var displayScale

    @State private var model: YourExesModel
    @State private var didFail = false

    /// Grid thumbnails are requested at 200 pt (SPEC.md → Reading the library).
    private var thumbnailSize: CGSize {
        CGSize(width: 200 * displayScale, height: 200 * displayScale)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    init(sessionID: UUID) {
        _model = State(initialValue: YourExesModel(sessionID: sessionID))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.blockLoose) {
                    header
                    grid
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.bottom, Spacing.screen)
            }

            footer
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.blockTight)
                .padding(.bottom, 8)
        }
        .background(.cream)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            model.load(context: modelContext)
            library.prefetchCards(model.exes.map(\.id), targetSize: thumbnailSize)
        }
        .alert("Couldn't delete photos", isPresented: $didFail) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nothing was deleted. Your exes are still marked, so you can try again.")
        }
    }

    // MARK: Header and grid

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.block) {
            ZStack {
                Text(model.sessionLabel)
                    .font(.inter(15))
                    .foregroundStyle(.muted)
                HStack {
                    RoundIconButton(systemImage: "chevron.left", accessibilityLabel: "Back to swiping") {
                        router.pop()
                    }
                    Spacer()
                }
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Your exes")
                    .font(.bricolage(34, relativeTo: .largeTitle))
                    .foregroundStyle(.plum)
                    .accessibilityAddTraits(.isHeader)
                Text("Having second thoughts? Tap a photo to take it back.")
                    .font(.inter(16))
                    .foregroundStyle(.muted)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(model.exes) { ex in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        model.toggleRescue(ex, context: modelContext)
                    }
                } label: {
                    ExTileView(assetID: ex.id, isRescued: ex.isRescued, targetSize: thumbnailSize)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Photo")
                .accessibilityValue(ex.isRescued ? "Back together" : "Marked for delete")
                .accessibilityHint(ex.isRescued ? "Double-tap to mark it for delete again." : "Double-tap to take it back.")
            }
        }
        .disabled(model.isBreakingUp)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: Spacing.block) {
            warningCard

            Button {
                Task { await breakup() }
            } label: {
                HStack(spacing: 10) {
                    if model.isBreakingUp {
                        ProgressView().tint(.brandWhite)
                    } else {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 20, weight: .bold))
                    }
                    Text("Breakup")
                        .font(.bricolage(22, relativeTo: .title3))
                }
            }
            .buttonStyle(.pill)
            .disabled(model.isBreakingUp)

            Button("Not yet, keep swiping") {
                router.pop()
            }
            .font(.inter(16, .bold))
            .foregroundStyle(.rose)
            .frame(minHeight: Size.minTapTarget)
            .disabled(model.isBreakingUp)
        }
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.coral)
                .frame(width: 36, height: 36)
                .background(.blush, in: Circle())
                .accessibilityHidden(true)

            Text("\(Text("This is goodbye.").font(.inter(16, .bold))) \(warningText)")
                .font(.inter(16))
                .foregroundStyle(.plum)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
                .animation(.default, value: model.deleteCount)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.brandWhite, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(.line, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
    }

    private var warningText: String {
        let count = model.deleteCount
        return count == 1
            ? "1 photo will move to Recently Deleted and disappear for good after 30 days."
            : "\(count) photos will move to Recently Deleted and disappear for good after 30 days."
    }

    // MARK: Breakup

    private func breakup() async {
        switch await model.breakup(library: library, context: modelContext) {
        case .deleted:
            router.push(.sessionComplete)
        case .cancelled:
            // Stay here with the exes still marked.
            break
        case .failed:
            didFail = true
        }
    }
}

#Preview {
    NavigationStack {
        YourExesView(sessionID: PreviewData.exesSessionID)
    }
    .environment(Router())
    .environment(PreviewData.library())
    .modelContainer(PreviewData.container)
}
