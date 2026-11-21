//
//  SwipeDeckView.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 2. Swipe deck, and Gestures and interactions.
//

import SwiftUI
import SwiftData

struct SwipeDeckView: View {
    @Environment(Router.self) private var router
    @Environment(PhotoLibrary.self) private var library
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayScale) private var displayScale

    @State private var model: SwipeDeckModel
    /// How far the top card has been dragged (or thrown).
    @State private var dragOffset: CGSize = .zero
    /// True while a card flies off, so input can't double-commit.
    @State private var isFlying = false
    @State private var cardSize: CGSize = .zero
    /// Where a card slides in from when it's inserted: 0 normally, or the
    /// side an undone card left from.
    @State private var insertionOffset: CGFloat = 0
    @State private var isShowingHeart = false
    @State private var isPickingAlbum = false
    @AppStorage(SettingsKey.lastAlbumID) private var lastAlbumID = ""
    @AppStorage(SettingsKey.dailyGoal) private var dailyGoal = SettingsDefault.dailyGoal
    /// The hint line hides after the first 10 decisions.
    @AppStorage(SettingsKey.hintDecisions) private var hintDecisions = 0
    /// Bumped on each decision, for a light haptic.
    @State private var decisionFeedback = 0
    /// Bumped twice on a heart, for a soft double tap.
    @State private var heartFeedback = 0

    /// Drag distance that commits a decision, and that fully shows a stamp.
    private let commitDistance: CGFloat = 120
    /// Horizontal speed (pt/s) that counts as a flick.
    private let flickVelocity: CGFloat = 800

    init(mode: DeckMode) {
        _model = State(initialValue: SwipeDeckModel(mode: mode))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, Spacing.screen)

            progressBar
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.block)

            cardStack
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.blockLoose)
                .frame(maxHeight: .infinity)

            if hintDecisions < 10 {
                Text("Right to keep · left to unmatch · double-tap to heart")
                    .font(.inter(14, relativeTo: .footnote))
                    .foregroundStyle(.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.screen)
                    .transition(.opacity)
            }

            buttonRow
                .padding(.top, Spacing.block)

            exesChip
                .padding(.top, Spacing.block)
        }
        .padding(.bottom, 8)
        .background(.cream)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            model.load(index: library.index, dailyGoal: dailyGoal, context: modelContext)
            prefetchUpcoming()
        }
        .onChange(of: model.position) { oldPosition, _ in
            if model.queue.indices.contains(oldPosition) {
                library.stopPrefetchingCards([model.queue[oldPosition]], targetSize: pixelSize)
            }
            prefetchUpcoming()
            // When the queue runs out, move on automatically.
            if model.isOutOfCards {
                router.push(model.finish(context: modelContext))
            }
        }
        .onChange(of: cardSize) {
            prefetchUpcoming()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: decisionFeedback)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: heartFeedback)
        .sheet(isPresented: $isPickingAlbum) {
            AlbumPickerSheet(onPick: addToAlbum, onCreate: createAlbumAndAdd)
        }
    }

    // MARK: Top bar and progress

    private var topBar: some View {
        HStack {
            RoundIconButton(systemImage: "chevron.left", accessibilityLabel: "Back") {
                router.pop()
            }

            Spacer()

            VStack(spacing: 2) {
                Text(model.title)
                    .font(.bricolage(20, relativeTo: .headline))
                    .foregroundStyle(.plum)
                if !model.queue.isEmpty {
                    Text(positionText)
                        .font(.inter(14, relativeTo: .subheadline))
                        .foregroundStyle(.muted)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityElement(children: .combine)

            Spacer()

            Button("Done") {
                router.push(model.finish(context: modelContext))
            }
            .font(.inter(16, .bold))
            .foregroundStyle(.brandWhite)
            .padding(.horizontal, 20)
            .frame(minHeight: Size.minTapTarget)
            .background(.plum, in: Capsule())
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private var positionText: String {
        switch model.mode {
        case .daily: "\(model.dailyOffset + model.displayPosition) of \(model.dailyOffset + model.queue.count) today"
        case .month: "\(model.displayPosition) of \(model.queue.count)"
        }
    }

    private var progressBar: some View {
        Capsule()
            .fill(.line)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(.rose)
                        .frame(width: proxy.size.width * model.progress)
                }
            }
            .animation(.easeOut(duration: 0.25), value: model.progress)
            .accessibilityHidden(true)
    }

    // MARK: Card stack

    private var cardStack: some View {
        GeometryReader { proxy in
            ZStack {
                if model.isLoaded && model.currentID == nil {
                    emptyState
                }

                // The next card first, so the top card draws over it.
                ForEach([model.nextID, model.currentID].compactMap { $0 }, id: \.self) { assetID in
                    card(assetID, size: proxy.size)
                        .transition(.asymmetric(insertion: .offset(x: insertionOffset), removal: .identity))
                }

                // Pops over the photo on a heart, before the card flies.
                Image(systemName: "heart.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.rose)
                    .shadow(color: .plum.opacity(0.25), radius: 12)
                    .scaleEffect(isShowingHeart ? 1 : 0.4)
                    .opacity(isShowingHeart ? 1 : 0)
                    .zIndex(2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear { cardSize = proxy.size }
            .onChange(of: proxy.size) { _, size in cardSize = size }
        }
    }

    private func card(_ assetID: String, size: CGSize) -> some View {
        let isTop = assetID == model.currentID
        let dx = dragOffset.width

        return SwipeCardView(
            assetID: assetID,
            targetSize: pixelSize,
            matchOpacity: isTop ? Double(min(max(dx / commitDistance, 0), 1)) : 0,
            unmatchOpacity: isTop ? Double(min(max(-dx / commitDistance, 0), 1)) : 0
        )
        .frame(width: size.width, height: size.height)
        // The next card peeks out, tilted 3°, and scales up as the top card leaves.
        .scaleEffect(isTop ? 1 : 0.97 + 0.03 * dragProgress)
        .rotationEffect(.degrees(isTop ? dragRotation : 3))
        .offset(isTop ? dragOffset : .zero)
        .zIndex(isTop ? 1 : 0)
        .allowsHitTesting(isTop)
        .gesture(dragGesture, including: isTop ? .all : .none)
        .simultaneousGesture(TapGesture(count: 2).onEnded { heart() }, including: isTop ? .all : .none)
        .accessibilityHidden(!isTop)
        .accessibilityAction(named: "Keep") { commit(.keep) }
        .accessibilityAction(named: "Unmatch") { commit(.unmatch) }
        .accessibilityAction(named: "Heart") { heart() }
        .accessibilityAction(named: "Add to album") { isPickingAlbum = true }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("That's everyone.")
                .font(.bricolage(26))
                .foregroundStyle(.plum)
            Text("Nothing left to review in \(model.title).")
                .font(.inter(16))
                .foregroundStyle(.muted)
                .multilineTextAlignment(.center)
        }
    }

    /// Card size in pixels, for image requests.
    private var pixelSize: CGSize {
        CGSize(width: cardSize.width * displayScale, height: cardSize.height * displayScale)
    }

    // MARK: Dragging

    /// 0 to 1, how close the drag is to committing.
    private var dragProgress: CGFloat {
        min(abs(dragOffset.width) / commitDistance, 1)
    }

    /// Up to 12° in the direction of the drag.
    private var dragRotation: Double {
        Double(min(max(dragOffset.width / 15, -12), 12))
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isFlying else { return }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isFlying else { return }
                let dx = value.translation.width
                let vx = value.velocity.width
                if dx > commitDistance || (vx > flickVelocity && dx > 0) {
                    commit(.keep)
                } else if dx < -commitDistance || (vx < -flickVelocity && dx < 0) {
                    commit(.unmatch)
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    /// Distance that takes a card fully off-screen.
    private var offScreenDistance: CGFloat {
        cardSize.width * 1.5 + 100
    }

    /// Keep or unmatch, from a swipe or a button.
    private func commit(_ decision: Decision) {
        guard !isFlying, model.currentID != nil else { return }
        flyOff(toRight: decision != .unmatch) {
            model.decide(decision, context: modelContext)
        }
    }

    /// Flies the top card off-screen, then runs `record` (which advances the
    /// deck) while the next card springs into place.
    private func flyOff(toRight: Bool, then record: @escaping () -> Void) {
        isFlying = true
        let flyOut = CGSize(width: (toRight ? 1 : -1) * offScreenDistance, height: dragOffset.height)

        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = flyOut
        } completion: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                record()
                dragOffset = .zero
                if hintDecisions < 10 {
                    hintDecisions += 1
                }
            }
            decisionFeedback += 1
            isFlying = false
        }
    }

    /// Heart: marks the photo a Favorite in Photos and keeps it. The heart
    /// pops over the photo, then the card flies right.
    private func heart() {
        guard !isFlying, let assetID = model.currentID else { return }
        isFlying = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            isShowingHeart = true
        }
        Task {
            // A soft double tap as the heart pops.
            heartFeedback += 1
            try? await Task.sleep(for: .milliseconds(110))
            heartFeedback += 1
        }
        Task {
            async let madeFavorite = library.setFavorite(true, assetID: assetID)
            try? await Task.sleep(for: .milliseconds(450))
            let didChange = await madeFavorite
            withAnimation(.easeOut(duration: 0.2)) {
                isShowingHeart = false
            }
            flyOff(toRight: true) {
                model.decide(.heart, madeFavorite: didChange, context: modelContext)
            }
        }
    }

    /// Keep and file: adds the photo to an album, closes the sheet and moves on.
    private func addToAlbum(_ albumID: String) {
        guard !isFlying, let assetID = model.currentID else { return }
        isPickingAlbum = false
        isFlying = true
        Task {
            let added = await library.addToAlbum(assetID: assetID, albumID: albumID)
            lastAlbumID = albumID
            flyOff(toRight: true) {
                model.decide(.album, addedToAlbumID: added ? albumID : nil, context: modelContext)
            }
        }
    }

    private func createAlbumAndAdd(_ title: String) {
        guard !isFlying else { return }
        isPickingAlbum = false
        Task {
            if let albumID = await library.createAlbum(named: title) {
                addToAlbum(albumID)
            }
        }
    }

    /// Reverses the last decision, including any Photos change it made, and
    /// slides the card back in from the side it left.
    private func undo() {
        guard !isFlying, let record = model.lastDecision else { return }
        isFlying = true
        let assetID = record.assetID
        let leftToRight = record.decision != .unmatch
        let madeFavorite = record.madeFavorite
        let albumID = record.addedToAlbumID

        Task {
            if madeFavorite {
                _ = await library.setFavorite(false, assetID: assetID)
            }
            if let albumID {
                await library.removeFromAlbum(assetID: assetID, albumID: albumID)
            }

            insertionOffset = (leftToRight ? 1 : -1) * offScreenDistance
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                model.undo(context: modelContext)
            } completion: {
                insertionOffset = 0
                isFlying = false
            }
        }
    }

    private func prefetchUpcoming() {
        guard cardSize.width > 0 else { return }
        library.prefetchCards(model.upcomingIDs, targetSize: pixelSize)
    }

    // MARK: Buttons

    private var buttonRow: some View {
        HStack(spacing: 14) {
            DeckActionButton(systemImage: "arrow.uturn.backward", accessibilityLabel: "Undo", kind: .plain(.muted), diameter: 48) {
                undo()
            }
            .disabled(!model.canUndo)

            DeckActionButton(systemImage: "xmark", accessibilityLabel: "Unmatch", kind: .unmatch, diameter: 68) {
                commit(.unmatch)
            }
            .disabled(model.currentID == nil)

            DeckActionButton(systemImage: "plus.square", accessibilityLabel: "Add to album", kind: .plain(.plum), diameter: 48) {
                isPickingAlbum = true
            }
            .disabled(model.currentID == nil)

            DeckActionButton(systemImage: "heart", accessibilityLabel: "Heart", kind: .plain(.rose), diameter: 48) {
                heart()
            }
            .disabled(model.currentID == nil)

            DeckActionButton(systemImage: "checkmark", accessibilityLabel: "Match", kind: .match, diameter: 68) {
                commit(.keep)
            }
            .disabled(model.currentID == nil)
        }
    }

    private var exesChip: some View {
        Button {
            if let sessionID = model.sessionID {
                router.push(.yourExes(sessionID: sessionID))
            }
        } label: {
            Label(model.exesCount == 1 ? "1 ex this session" : "\(model.exesCount) exes this session", systemImage: "xmark")
                .font(.inter(15, .bold))
                .foregroundStyle(.roseDark)
                .padding(.horizontal, 22)
                .frame(minHeight: Size.minTapTarget)
                .background(.blush, in: Capsule())
        }
        .buttonStyle(.plain)
        // With zero exes there's nothing to review (SPEC.md → Your exes, 6).
        .disabled(model.exesCount == 0)
    }
}

#Preview {
    NavigationStack {
        SwipeDeckView(mode: .month(MonthKey(year: 2019, month: 6)))
    }
    .environment(Router())
    .environment(PreviewData.library())
    .modelContainer(PreviewData.container)
}

#Preview("Daily") {
    NavigationStack {
        SwipeDeckView(mode: .daily)
    }
    .environment(Router())
    .environment(PreviewData.library())
    .modelContainer(PreviewData.container)
}
