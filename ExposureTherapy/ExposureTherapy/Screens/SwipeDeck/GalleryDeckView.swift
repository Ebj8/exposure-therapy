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
    @State private var isShowingHeart = false
    @State private var isPickingAlbum = false
    @State private var peek: PeekRequest?
    @State private var decisionFeedback = 0
    @State private var heartFeedback = 0
    /// Set once this visit has moved on to review, so the end-of-month
    /// swipe, Done and "everyone decided" can't push it twice.
    @State private var didFinish = false

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

            if !model.isLoaded {
                FilmstripPlaceholder()
                    .padding(.bottom, Spacing.blockTight)
            } else if let currentID = model.currentID {
                FilmstripView(
                    slots: model.filmstripSlots(around: currentID, radius: 3),
                    status: model.status(of:),
                    onSelect: selectFromFilmstrip
                )
                .padding(.bottom, Spacing.blockTight)
            }

            if hintDecisions < 10 {
                Text("Swipe up to break up · swipe to keep")
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
            await model.load(index: library.index, dailyGoal: dailyGoal, browseWholeMonth: true, context: modelContext)
            prefetchAround()
        }
        .onChange(of: model.position) {
            prefetchAround()
        }
        .onChange(of: cardSize) {
            prefetchAround()
        }
        .onAppear {
            // Back from Your exes ("Not yet, keep swiping"): don't land on a
            // photo you just broke up with, and allow finishing again.
            if didFinish {
                model.moveTo(page: model.position)
            }
            didFinish = false
        }
        .onChange(of: model.isAllDecided) { _, allDecided in
            // Everyone has an answer: move on, like running out of cards.
            if allDecided {
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    if model.isAllDecided {
                        finishSession()
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
                if !model.visiblePages.isEmpty {
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
                finishSession()
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
        case .daily:
            // Today's count is decisions toward the goal, not the page.
            return "\(model.dailyOffset + model.decidedInQueue) of \(model.dailyOffset + model.queue.count) today"
        case .month:
            return "\(model.position + 1) of \(model.visiblePages.count)"
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
    private var pagerSlots: [(assetID: String, offset: Int)] {
        // Check first: the queue is empty until the deck loads, and an empty
        // range here would crash.
        let pages = model.visiblePages
        guard !pages.isEmpty else { return [] }
        let lower = max(model.position - 1, 0)
        let upper = min(model.position + 1, pages.count - 1)
        guard lower <= upper else { return [] }
        return (lower...upper).map { (pages[$0], $0 - model.position) }
    }

    private var pager: some View {
        GeometryReader { proxy in
            ZStack {
                if !model.isLoaded {
                    SkeletonView(cornerRadius: Radius.swipeCard)
                } else if model.visiblePages.isEmpty {
                    emptyState
                }

                ForEach(pagerSlots, id: \.assetID) { page in
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
        let decision = model.effectiveDecision(for: assetID)
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
        .overlay(alignment: .top) {
            if decision != nil {
                reviewedPill
                    .padding(.top, 16)
            }
        }
        .frame(width: size.width, height: size.height)
        .offset(x: CGFloat(offset) * (size.width + pageGap) + horizontal, y: vertical)
        .accessibilityHidden(!isCurrent)
        .accessibilityValue(decision.map(accessibilityStatus) ?? "Not decided")
    }

    private var reviewedPill: some View {
        Label("Reviewed", systemImage: "checkmark")
            .font(.inter(13, .bold))
            .foregroundStyle(.brandWhite)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.brandTeal, in: Capsule())
    }

    private func accessibilityStatus(_ decision: Decision) -> String {
        decision == .unmatch ? "Marked for delete" : "Reviewed, kept"
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

    /// There's a photo on screen to decide or change.
    private var isCurrentEditable: Bool {
        model.currentID != nil
    }

    private var canBreakUpCurrent: Bool {
        guard let currentID = model.currentID else { return false }
        return model.effectiveDecision(for: currentID) != .unmatch
    }

    private var isOnLastPage: Bool {
        model.position >= model.visiblePages.count - 1
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
                } else if !canBreakUpCurrent {
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
                    let forward = dx < -pageDistance || value.velocity.width < -flickVelocity
                    if forward && isOnLastPage {
                        finishFromLastPhoto()
                    } else if forward {
                        goForward(keepingCurrent: true)
                    } else if (dx > pageDistance || value.velocity.width > flickVelocity) && model.position > 0 {
                        goBack()
                    } else {
                        springBack()
                    }
                case .vertical:
                    if canBreakUpCurrent && (dy < -commitDistance || value.velocity.height < -flickVelocity) {
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
    /// Next page. On the month's last photo there's no next page, so it
    /// goes to review instead (after ✓, ♡ or an album, the photo is decided).
    private func goForward(keepingCurrent: Bool) {
        guard let currentID = model.currentID else {
            springBack()
            return
        }
        if isOnLastPage {
            if keepingCurrent {
                finishFromLastPhoto()
            } else {
                finishSession()
            }
            return
        }
        if keepingCurrent && model.effectiveDecision(for: currentID) == nil {
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

    /// Swiping on past the month's last photo: keep it if it's undecided,
    /// then go to review (Your exes, or Session complete with no exes).
    private func finishFromLastPhoto() {
        springBack()
        if let currentID = model.currentID, model.effectiveDecision(for: currentID) == nil {
            model.record(.keep, for: currentID, context: modelContext)
            noteDecision()
        }
        finishSession()
    }

    /// Goes to review once per visit, whichever way the session ends. If you
    /// only browsed (re-reviewing a month without changing anything), there's
    /// nothing to review, so it goes back instead.
    private func finishSession() {
        guard !didFinish else { return }
        didFinish = true
        // No decisions this visit (or all undone): just browsing.
        if model.history.isEmpty {
            router.pop()
        } else {
            router.push(model.finish(context: modelContext))
        }
    }

    /// Previous page. Swiping off an undecided photo in either direction
    /// keeps it; photos already decided are left as they are.
    private func goBack() {
        if let currentID = model.currentID, model.effectiveDecision(for: currentID) == nil {
            model.record(.keep, for: currentID, context: modelContext)
            noteDecision()
        }
        lockInput(for: .milliseconds(300))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            model.moveTo(page: model.position - 1)
            dragOffset = .zero
            dragAxis = nil
        }
    }

    /// Swipe up or ✕: the photo flies off the top and leaves the gallery
    /// as an ex; the next photo slides into its place.
    private func breakUpCurrent() {
        guard !isAnimating, canBreakUpCurrent, let assetID = model.currentID else { return }
        isAnimating = true
        let wasLastPhoto = isOnLastPage
        withAnimation(.easeIn(duration: 0.22)) {
            dragAxis = .vertical
            dragOffset = CGSize(width: 0, height: -(cardSize.height * 1.5 + 100))
        }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                model.record(.unmatch, for: assetID, context: modelContext)
                dragOffset = .zero
                dragAxis = nil
            }
            noteDecision()
            if wasLastPhoto {
                // That was the month's last photo: on to review. The last
                // kept photo is where you'll pick up if you come back.
                model.moveTo(page: model.position)
                finishSession()
            }
            try? await Task.sleep(for: .milliseconds(300))
            isAnimating = false
        }
    }

    private func heart() {
        guard !isAnimating, isCurrentEditable, let assetID = model.currentID else { return }
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
        guard !isAnimating, isCurrentEditable, let assetID = model.currentID else { return }
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
        if let page = model.visiblePages.firstIndex(of: undone.assetID) {
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
        if let page = model.visiblePages.firstIndex(of: assetID) {
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
        let pages = model.visiblePages
        guard cardSize.width > 0, !pages.isEmpty else { return }
        let start = max(model.position - 1, 0)
        let end = min(model.position + 3, pages.count - 1)
        guard start <= end else { return }
        library.prefetchCards(Array(pages[start...end]), targetSize: pixelSize)
    }

    // MARK: Buttons

    /// Undo on the left; Album, Discard and Favorite grouped and centered
    /// on the screen, with Discard large in the middle.
    private var buttonRow: some View {
        ZStack {
            HStack(spacing: 14) {
                DeckActionButton(systemImage: "plus.square", accessibilityLabel: "Add to album", kind: .plain(.plum), diameter: 48) {
                    isPickingAlbum = true
                }
                .disabled(!isCurrentEditable)

                DeckActionButton(systemImage: "xmark", accessibilityLabel: "Break up", kind: .unmatch, diameter: 68) {
                    breakUpCurrent()
                }
                .disabled(!canBreakUpCurrent)

                DeckActionButton(systemImage: "heart", accessibilityLabel: "Heart", kind: .plain(.rose), diameter: 48) {
                    heart()
                }
                .disabled(!isCurrentEditable)
            }

            HStack {
                DeckActionButton(systemImage: "arrow.uturn.backward", accessibilityLabel: "Undo", kind: .plain(.muted), diameter: 48) {
                    undo()
                }
                .disabled(!model.canUndoGallery)
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.screen)
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
