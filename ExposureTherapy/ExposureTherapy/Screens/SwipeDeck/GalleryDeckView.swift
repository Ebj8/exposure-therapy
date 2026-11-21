//
//  GalleryDeckView.swift
//  ExposureTherapy
//
//  Gallery-style deck (trial): swipe sideways to browse photos like the
//  Photos app, and swipe up to break up with one. Moving on from a photo
//  you haven't decided on keeps it. Same session, exes and Breakup flow as
//  the card deck.
//

import SwiftUI
import SwiftData

struct GalleryDeckView: View {
    @Environment(Router.self) private var router
    @Environment(PhotoLibrary.self) private var library
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayScale) private var displayScale

    @State private var model: SwipeDeckModel
    @State private var dragOffset: CGSize = .zero
    /// Locked on the first few points of a drag: browse or break up.
    @State private var dragAxis: Axis?
    /// True while a page change or break-up animates, so input can't overlap.
    @State private var isAnimating = false
    @State private var cardSize: CGSize = .zero
    /// A photo that just flew off the top, hidden while the next one slides in.
    @State private var hiddenID: String?
    @State private var isShowingHeart = false
    @State private var isPickingAlbum = false
    @State private var peek: PeekRequest?
    @State private var decisionFeedback = 0
    @State private var heartFeedback = 0

    @AppStorage(SettingsKey.lastAlbumID) private var lastAlbumID = ""
    @AppStorage(SettingsKey.dailyGoal) private var dailyGoal = SettingsDefault.dailyGoal
    @AppStorage(SettingsKey.hintDecisions) private var hintDecisions = 0

    /// Upward drag that breaks up, and that fully shows the stamp.
    private let commitDistance: CGFloat = 120
    /// Sideways drag that turns the page.
    private let pageDistance: CGFloat = 70
    private let flickVelocity: CGFloat = 700
    private let pageGap: CGFloat = 16

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

            pager
                .padding(.horizontal, Spacing.screen)
                .padding(.top, Spacing.blockLoose)
                .padding(.bottom, Spacing.block)
                .frame(maxHeight: .infinity)

            if let currentID = model.currentID {
                FilmstripView(
                    slots: model.filmstripSlots(around: currentID, radius: 3),
                    status: model.status(of:),
                    onSelect: selectFromFilmstrip
                )
                .padding(.bottom, Spacing.blockTight)
            }

            if hintDecisions < 10 {
                Text("Swipe up to break up · swipe on to keep")
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
            prefetchAround()
        }
        .onChange(of: model.position) {
            prefetchAround()
        }
        .onChange(of: cardSize) {
            prefetchAround()
        }
        .onChange(of: model.isAllDecided) { _, allDecided in
            // Everyone has an answer: move on, like running out of cards.
            if allDecided {
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    if model.isAllDecided {
                        router.push(model.finish(context: modelContext))
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: decisionFeedback)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: heartFeedback)
        .fullScreenCover(item: $peek) { request in
            PeekView(request: request, status: model.status(of:))
        }
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
        let page = model.position + 1
        switch model.mode {
        case .daily: return "\(model.dailyOffset + page) of \(model.dailyOffset + model.queue.count) today"
        case .month: return "\(page) of \(model.queue.count)"
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
                        .frame(width: proxy.size.width * model.galleryProgress)
                }
            }
            .animation(.easeOut(duration: 0.25), value: model.galleryProgress)
            .accessibilityHidden(true)
    }

    // MARK: Pager

    /// The previous, current and next photos, with their offset from the current page.
    private var visiblePages: [(assetID: String, offset: Int)] {
        // Check first: the queue is empty until the deck loads, and an empty
        // range here would crash.
        guard !model.queue.isEmpty else { return [] }
        let lower = max(model.position - 1, 0)
        let upper = min(model.position + 1, model.queue.count - 1)
        guard lower <= upper else { return [] }
        return (lower...upper).map { (model.queue[$0], $0 - model.position) }
    }

    private var pager: some View {
        GeometryReader { proxy in
            ZStack {
                if model.isLoaded && model.queue.isEmpty {
                    emptyState
                }

                ForEach(visiblePages, id: \.assetID) { page in
                    pageView(page.assetID, offset: page.offset, size: proxy.size)
                }

                // Pops over the photo on a heart.
                Image(systemName: "heart.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.rose)
                    .shadow(color: .plum.opacity(0.25), radius: 12)
                    .scaleEffect(isShowingHeart ? 1 : 0.4)
                    .opacity(isShowingHeart ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(pagerGesture)
            .simultaneousGesture(TapGesture(count: 2).onEnded { heart() })
            .onAppear { cardSize = proxy.size }
            .onChange(of: proxy.size) { _, size in cardSize = size }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next photo") { goForward(keepingCurrent: true) }
        .accessibilityAction(named: "Previous photo") { goBack() }
        .accessibilityAction(named: "Break up") { breakUpCurrent() }
        .accessibilityAction(named: "Heart") { heart() }
    }

    private func pageView(_ assetID: String, offset: Int, size: CGSize) -> some View {
        let isCurrent = offset == 0
        let decision = model.decision(for: assetID)
        let horizontal = dragAxis == .horizontal ? dragOffset.width : 0
        // Upward drags follow the finger; downward ones barely move.
        let vertical = isCurrent && dragAxis == .vertical
            ? (dragOffset.height < 0 ? dragOffset.height : dragOffset.height * 0.2)
            : 0

        return SwipeCardView(
            assetID: assetID,
            targetSize: pixelSize,
            unmatchOpacity: isCurrent ? Double(min(max(-vertical / commitDistance, 0), 1)) : 0
        )
        .overlay {
            if decision == .unmatch {
                RoundedRectangle(cornerRadius: Radius.swipeCard, style: .continuous)
                    .fill(.plum.opacity(0.45))
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            if let decision {
                statusPill(for: decision)
                    .padding(.top, 16)
            }
        }
        .frame(width: size.width, height: size.height)
        .offset(x: CGFloat(offset) * (size.width + pageGap) + horizontal, y: vertical)
        .opacity(assetID == hiddenID ? 0 : 1)
        .accessibilityHidden(!isCurrent)
        .accessibilityValue(decision.map(accessibilityStatus) ?? "Not decided")
    }

    private func statusPill(for decision: Decision) -> some View {
        let isEx = decision == .unmatch
        return Label(isEx ? "Ex · tap ✓ to take back" : "Kept", systemImage: isEx ? "xmark" : "checkmark")
            .font(.inter(13, .bold))
            .foregroundStyle(.brandWhite)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isEx ? Color.coral : Color.brandTeal, in: Capsule())
    }

    private func accessibilityStatus(_ decision: Decision) -> String {
        decision == .unmatch ? "Marked for delete" : "Kept"
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

    // MARK: Gestures

    private var isOnLastPage: Bool {
        model.position >= model.queue.count - 1
    }

    private var pagerGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isAnimating, model.currentID != nil else { return }
                if dragAxis == nil {
                    dragAxis = abs(value.translation.width) > abs(value.translation.height) ? .horizontal : .vertical
                }
                var translation = value.translation
                if dragAxis == .horizontal {
                    // Rubber-band at the first and last photo.
                    let atStart = model.position == 0 && translation.width > 0
                    let atEnd = isOnLastPage && translation.width < 0
                    if atStart || atEnd { translation.width *= 0.3 }
                } else if model.decision(for: model.currentID ?? "") == .unmatch {
                    // Already an ex: resist instead of breaking up again.
                    translation.height *= 0.2
                }
                dragOffset = translation
            }
            .onEnded { value in
                guard !isAnimating else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                switch dragAxis {
                case .horizontal:
                    if (dx < -pageDistance || value.velocity.width < -flickVelocity) && !isOnLastPage {
                        goForward(keepingCurrent: true)
                    } else if (dx > pageDistance || value.velocity.width > flickVelocity) && model.position > 0 {
                        goBack()
                    } else {
                        springBack()
                    }
                case .vertical:
                    let canBreakUp = model.decision(for: model.currentID ?? "") != .unmatch
                    if canBreakUp && (dy < -commitDistance || value.velocity.height < -flickVelocity) {
                        breakUpCurrent()
                    } else {
                        springBack()
                    }
                case .none:
                    springBack()
                }
            }
    }

    private func springBack() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            dragOffset = .zero
            dragAxis = nil
        }
    }

    /// Locks input for `duration`, on a timer rather than an animation
    /// completion (which SwiftUI can skip).
    private func lockInput(for duration: Duration) {
        isAnimating = true
        Task {
            try? await Task.sleep(for: duration)
            isAnimating = false
        }
    }

    // MARK: Actions

    /// Next page. Moving on from an undecided photo keeps it.
    private func goForward(keepingCurrent: Bool) {
        guard let currentID = model.currentID, !isOnLastPage else {
            springBack()
            return
        }
        if keepingCurrent && model.decision(for: currentID) == nil {
            model.record(.keep, for: currentID, context: modelContext)
            noteDecision()
        }
        lockInput(for: .milliseconds(300))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            model.moveTo(page: model.position + 1)
            dragOffset = .zero
            dragAxis = nil
        }
    }

    /// Previous page. Look-only: nothing is decided.
    private func goBack() {
        lockInput(for: .milliseconds(300))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            model.moveTo(page: model.position - 1)
            dragOffset = .zero
            dragAxis = nil
        }
    }

    /// Swipe up or ✕: the photo flies off the top, becomes an ex, and the
    /// next photo slides in.
    private func breakUpCurrent() {
        guard !isAnimating, let assetID = model.currentID, model.decision(for: assetID) != .unmatch else { return }
        isAnimating = true
        withAnimation(.easeIn(duration: 0.22)) {
            dragAxis = .vertical
            dragOffset = CGSize(width: 0, height: -(cardSize.height * 1.5 + 100))
        }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            model.record(.unmatch, for: assetID, context: modelContext)
            noteDecision()

            // Put the card back in its slot unseen, then slide to the next one.
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                hiddenID = assetID
                dragOffset = .zero
                dragAxis = nil
            }
            if !isOnLastPage {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    model.moveTo(page: model.position + 1)
                }
            }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeOut(duration: 0.2)) {
                hiddenID = nil
            }
            isAnimating = false
        }
    }

    /// ✓: keeps the photo (or takes an ex back) and moves on.
    private func keepCurrent() {
        guard !isAnimating, let assetID = model.currentID else { return }
        model.record(.keep, for: assetID, context: modelContext)
        noteDecision()
        goForward(keepingCurrent: false)
    }

    private func heart() {
        guard !isAnimating, let assetID = model.currentID else { return }
        isAnimating = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            isShowingHeart = true
        }
        Task {
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
            model.record(.heart, for: assetID, madeFavorite: didChange, context: modelContext)
            noteDecision()
            isAnimating = false
            goForward(keepingCurrent: false)
        }
    }

    private func addToAlbum(_ albumID: String) {
        guard !isAnimating, let assetID = model.currentID else { return }
        isPickingAlbum = false
        isAnimating = true
        Task {
            let added = await library.addToAlbum(assetID: assetID, albumID: albumID)
            lastAlbumID = albumID
            model.record(.album, for: assetID, addedToAlbumID: added ? albumID : nil, context: modelContext)
            noteDecision()
            isAnimating = false
            goForward(keepingCurrent: false)
        }
    }

    private func createAlbumAndAdd(_ title: String) {
        guard !isAnimating else { return }
        isPickingAlbum = false
        Task {
            if let albumID = await library.createAlbum(named: title) {
                addToAlbum(albumID)
            }
        }
    }

    /// Steps back through decisions and changes of mind, reversing any
    /// Photos change, and shows the photo it affected.
    private func undo() {
        guard !isAnimating, let undone = model.undoGallery(context: modelContext) else { return }
        lockInput(for: .milliseconds(350))
        Task {
            if undone.madeFavorite {
                _ = await library.setFavorite(false, assetID: undone.assetID)
            }
            if let albumID = undone.addedToAlbumID {
                await library.removeFromAlbum(assetID: undone.assetID, albumID: albumID)
            }
        }
        if let page = model.queue.firstIndex(of: undone.assetID) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                model.moveTo(page: page)
                dragOffset = .zero
                dragAxis = nil
            }
        }
    }

    /// Filmstrip tap: jump to the photo if it's in this session, otherwise peek.
    private func selectFromFilmstrip(_ assetID: String) {
        guard !isAnimating else { return }
        if let page = model.queue.firstIndex(of: assetID) {
            lockInput(for: .milliseconds(300))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                model.moveTo(page: page)
            }
        } else if let currentID = model.currentID {
            peek = PeekRequest(assetIDs: model.neighbors(of: currentID, radius: 10), startID: assetID)
        }
    }

    private func noteDecision() {
        decisionFeedback += 1
        if hintDecisions < 10 {
            withAnimation { hintDecisions += 1 }
        }
    }

    private func prefetchAround() {
        guard cardSize.width > 0, !model.queue.isEmpty else { return }
        let start = max(model.position - 1, 0)
        let end = min(model.position + 3, model.queue.count - 1)
        guard start <= end else { return }
        library.prefetchCards(Array(model.queue[start...end]), targetSize: pixelSize)
    }

    // MARK: Buttons

    private var buttonRow: some View {
        let currentDecision = model.currentID.flatMap(model.decision(for:))
        return HStack(spacing: 14) {
            DeckActionButton(systemImage: "arrow.uturn.backward", accessibilityLabel: "Undo", kind: .plain(.muted), diameter: 48) {
                undo()
            }
            .disabled(!model.canUndoGallery)

            DeckActionButton(systemImage: "xmark", accessibilityLabel: "Break up", kind: .unmatch, diameter: 68) {
                breakUpCurrent()
            }
            .disabled(model.currentID == nil || currentDecision == .unmatch)

            DeckActionButton(systemImage: "plus.square", accessibilityLabel: "Add to album", kind: .plain(.plum), diameter: 48) {
                isPickingAlbum = true
            }
            .disabled(model.currentID == nil)

            DeckActionButton(systemImage: "heart", accessibilityLabel: "Heart", kind: .plain(.rose), diameter: 48) {
                heart()
            }
            .disabled(model.currentID == nil)

            DeckActionButton(
                systemImage: "checkmark",
                accessibilityLabel: currentDecision == .unmatch ? "Take back" : "Keep",
                kind: .match,
                diameter: 68
            ) {
                keepCurrent()
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
        .disabled(model.exesCount == 0)
    }
}

#Preview {
    NavigationStack {
        GalleryDeckView(mode: .month(MonthKey(year: 2019, month: 6)))
    }
    .environment(Router())
    .environment(PreviewData.library())
    .modelContainer(PreviewData.container)
}
