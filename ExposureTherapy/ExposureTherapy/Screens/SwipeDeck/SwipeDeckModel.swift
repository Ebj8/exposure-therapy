//
//  SwipeDeckModel.swift
//  ExposureTherapy
//
//  SPEC.md → Data → Queues and SwiftData models. Builds the deck's queue,
//  records each decision as it's made, and tracks this session's exes.
//

import Foundation
import SwiftData

@Observable
final class SwipeDeckModel {
    let mode: DeckMode

    /// Asset IDs to review, in date order. Fixed once loaded.
    private(set) var queue: [String] = []
    /// Index in `queue` of the card on top.
    private(set) var position = 0
    private(set) var isLoaded = false

    /// Daily mode: today's goal, and today's decisions when the deck opened
    /// (from earlier daily sessions, or this one before a relaunch).
    private(set) var dailyGoal = 0
    private(set) var doneTodayAtLoad = 0
    /// `history.count` at load, so only new decisions add to today's count.
    @ObservationIgnored private var historyCountAtLoad = 0

    /// This session's decisions, oldest first, for multi-step undo.
    private(set) var history: [PhotoDecision] = []

    /// Every photo of the month, decided or not.
    private(set) var pages: [String] = []

    /// Every decision or change of mind, newest last, so
    /// undo can step back through them (including keep → ex changes).
    private(set) var actions: [Action] = []

    /// The open session, created on the first decision if there isn't one.
    @ObservationIgnored private var session: Session?
    /// Months of queued photos, for the daily deck's title.
    @ObservationIgnored private var queueMonths: [String: MonthKey] = [:]
    @ObservationIgnored private var index: LibraryIndex = .empty
    /// Decisions from earlier sessions, for marking neighbors in the filmstrip.
    /// This session's are read live from `history`, so rescues show up too.
    @ObservationIgnored private var earlierDecisions: [String: Decision] = [:]
    @ObservationIgnored private var isLoading = false

    init(mode: DeckMode) {
        self.mode = mode
    }

    /// Unmatched photos in this session, waiting for a Breakup. Computed from
    /// the records, so rescues on Your exes show up here too.
    var exesCount: Int {
        history.filter { $0.decision == .unmatch }.count
    }

    var sessionID: UUID? {
        session?.id
    }

    /// Month mode: the month. Daily mode: the month of the photo on screen
    /// (a daily session stays within one month).
    var title: String {
        switch mode {
        case .month(let key):
            return key.title
        case .daily:
            guard let currentID else { return "Today's session" }
            if let month = queueMonths[currentID] ?? month(of: currentID) {
                return month.title
            }
            return "Undated"
        }
    }

    /// Looks up a photo's month in the library, for photos put back by undo
    /// that weren't in this visit's queue.
    private func month(of assetID: String) -> MonthKey? {
        index.months.first { $0.value.contains(assetID) }?.key
    }

    var currentID: String? {
        let pages = visiblePages
        return pages.indices.contains(position) ? pages[position] : nil
    }

    /// The month's photos minus exes. Breaking up removes a
    /// photo from the gallery; undo or a rescue on Your exes brings it back
    /// in its place. `position` indexes this list when browsing.
    var visiblePages: [String] {
        let sessionIDs = Set(history.map(\.assetID))
        var exIDs = Set(history.filter { $0.decision == .unmatch }.map(\.assetID))
        for (assetID, decision) in earlierDecisions where decision == .unmatch && !sessionIDs.contains(assetID) {
            exIDs.insert(assetID)
        }
        return pages.filter { !exIDs.contains($0) }
    }

    // MARK: Loading

    /// Pages are every photo of the month (so you can swipe back to ones
    /// already decided), opening on the first one still to decide. `queue`
    /// is the photos to decide.
    func load(index: LibraryIndex, dailyGoal: Int, context: ModelContext) async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Let the screen finish sliding in first (the skeleton shows
        // meanwhile), so the work below can't stall the transition.
        try? await Task.sleep(for: .milliseconds(350))
        self.index = index

        // Skip anything already decided, including exes still waiting for a Breakup.
        let allDecisions = (try? context.fetch(FetchDescriptor<PhotoDecision>())) ?? []
        let decided = Set(allDecisions.map(\.assetID))
        var doneToday = 0
        if case .daily = mode {
            let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
            doneToday = DailyPlan.doneToday(decisions: allDecisions, sessions: sessions)
            self.dailyGoal = dailyGoal
            doneTodayAtLoad = doneToday
        }

        // Walking the library to build the queue runs off the main thread.
        let mode = self.mode
        let plan = await Task.detached(priority: .userInitiated) {
            DeckPlan(mode: mode, index: index, decided: decided, dailyGoal: dailyGoal, doneToday: doneToday)
        }.value
        queue = plan.queue
        queueMonths = plan.queueMonths
        pages = plan.pages

        session = openSession(context: context)
        if let session {
            let sessionID = session.id
            let descriptor = FetchDescriptor<PhotoDecision>(
                predicate: #Predicate { $0.sessionID == sessionID },
                sortBy: [SortDescriptor(\.decidedAt)]
            )
            history = (try? context.fetch(descriptor)) ?? []
        }
        actions = history.map {
            Action(record: $0, previous: nil, previousMadeFavorite: false, previousAlbumID: nil,
                          madeFavorite: $0.madeFavorite, addedToAlbumID: $0.addedToAlbumID)
        }
        let sessionIDs = Set(history.map(\.assetID))
        for record in allDecisions where !sessionIDs.contains(record.assetID) {
            earlierDecisions[record.assetID] = record.decision
        }

        position = queue.first.flatMap { visiblePages.firstIndex(of: $0) } ?? 0
        historyCountAtLoad = history.count
        isLoaded = true
    }

    /// An unfinished session for this deck, so exes from before a quit
    /// carry over.
    private func openSession(context: ModelContext) -> Session? {
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.endedAt == nil })
        let open = (try? context.fetch(descriptor)) ?? []
        return open.first { session in
            switch mode {
            case .daily: session.mode == .daily
            case .month(let key): session.mode == .month && session.monthKey == key.rawValue
            }
        }
    }

    // MARK: Filmstrip

    /// Where a photo stands, for marking it in the filmstrip.
    enum NeighborStatus {
        case current
        case kept
        case ex
        case undecided
    }

    /// Gallery filmstrip: `radius` slots on each side of the current photo,
    /// taken from the gallery itself, so exes are left out just as they are
    /// when browsing. nil where the month runs out.
    func filmstripSlots(radius: Int) -> [String?] {
        let pages = visiblePages
        return (position - radius...position + radius).map { pages.indices.contains($0) ? pages[$0] : nil }
    }

    func status(of assetID: String) -> NeighborStatus {
        if assetID == currentID { return .current }
        let decision = history.last(where: { $0.assetID == assetID })?.decision ?? earlierDecisions[assetID]
        switch decision {
        case .none: return .undecided
        case .unmatch: return .ex
        case .keep, .heart, .album: return .kept
        }
    }

    // MARK: Decisions

    /// One decision or change of mind, with what it replaced so undo can
    /// restore it.
    struct Action {
        let record: PhotoDecision
        /// nil when this action created the record.
        let previous: Decision?
        let previousMadeFavorite: Bool
        let previousAlbumID: String?
        /// Photos changes this action made, for undo to reverse.
        let madeFavorite: Bool
        let addedToAlbumID: String?
        /// Set when this action moved an earlier session's decision into this
        /// session; undo hands it back.
        var previousSessionID: UUID? = nil
    }

    /// This session's decision for a photo, if any.
    func decision(for assetID: String) -> Decision? {
        history.last { $0.assetID == assetID }?.decision
    }

    /// Queue photos with a decision so far.
    var decidedInQueue: Int {
        let decided = Set(history.map(\.assetID))
        return queue.filter(decided.contains).count
    }

    /// Every photo in the queue has a decision.
    /// Daily mode: decisions made today, counting every photo decided in
    /// this deck (past the goal too) plus today's earlier daily sessions.
    var decidedToday: Int {
        doneTodayAtLoad + max(history.count - historyCountAtLoad, 0)
    }

    var isAllDecided: Bool {
        isLoaded && !queue.isEmpty && decidedInQueue == queue.count
    }

    /// Share of the session decided, 0 to 1.
    var progress: Double {
        switch mode {
        case .daily:
            // Fills up to the goal; reviewing past it keeps it full.
            return dailyGoal == 0 ? 0 : min(Double(decidedToday) / Double(dailyGoal), 1)
        case .month:
            return queue.isEmpty ? 0 : Double(decidedInQueue) / Double(queue.count)
        }
    }

    var canUndo: Bool {
        !actions.isEmpty
    }

    /// Shows a page without deciding anything.
    func moveTo(page: Int) {
        position = min(max(page, 0), max(visiblePages.count - 1, 0))
    }

    /// This session's decision, or else an earlier session's: what the
    /// photo's status is right now.
    func effectiveDecision(for assetID: String) -> Decision? {
        decision(for: assetID) ?? earlierDecisions[assetID]
    }

    /// Records (or changes) the decision for a photo without moving pages.
    func record(
        _ decision: Decision,
        for assetID: String,
        madeFavorite: Bool = false,
        addedToAlbumID: String? = nil,
        context: ModelContext
    ) {
        // The session starts only once something actually changes, so just
        // browsing a month leaves no empty session behind.
        if history.last(where: { $0.assetID == assetID }) == nil,
           let earlier = earlierDecisions[assetID] {
            // Decided in an earlier session: changing it moves the decision
            // into this one. That session's summary keeps what happened then.
            guard earlier != decision, let existing = earlierRecord(for: assetID, context: context) else { return }
            let session = self.session ?? startSession(context: context)
            var action = Action(
                record: existing,
                previous: existing.decision,
                previousMadeFavorite: existing.madeFavorite,
                previousAlbumID: existing.addedToAlbumID,
                madeFavorite: madeFavorite,
                addedToAlbumID: addedToAlbumID
            )
            action.previousSessionID = existing.sessionID
            actions.append(action)

            existing.sessionID = session.id
            existing.decision = decision
            existing.decidedAt = .now
            if madeFavorite { existing.madeFavorite = true }
            if let addedToAlbumID { existing.addedToAlbumID = addedToAlbumID }
            earlierDecisions[assetID] = nil
            history.append(existing)
            if decision != .unmatch {
                session.keptCount += 1
            }
        } else if let existing = history.last(where: { $0.assetID == assetID }) {
            guard existing.decision != decision, let session else { return }
            actions.append(Action(
                record: existing,
                previous: existing.decision,
                previousMadeFavorite: existing.madeFavorite,
                previousAlbumID: existing.addedToAlbumID,
                madeFavorite: madeFavorite,
                addedToAlbumID: addedToAlbumID
            ))
            adjustKeptCount(session, from: existing.decision, to: decision)
            existing.decision = decision
            if madeFavorite { existing.madeFavorite = true }
            if let addedToAlbumID { existing.addedToAlbumID = addedToAlbumID }
        } else {
            let session = self.session ?? startSession(context: context)
            let record = PhotoDecision(
                assetID: assetID,
                decision: decision,
                sessionID: session.id,
                madeFavorite: madeFavorite,
                addedToAlbumID: addedToAlbumID
            )
            context.insert(record)
            history.append(record)
            actions.append(Action(
                record: record, previous: nil, previousMadeFavorite: false, previousAlbumID: nil,
                madeFavorite: madeFavorite, addedToAlbumID: addedToAlbumID
            ))
            if decision != .unmatch {
                session.keptCount += 1
            }
        }
        // Save right away so decisions survive the app being quit.
        try? context.save()
    }

    /// Reverses the last gallery action. Returns the photo and any Photos
    /// changes that action made, for the caller to reverse.
    func undo(context: ModelContext) -> (assetID: String, madeFavorite: Bool, addedToAlbumID: String?)? {
        guard let action = actions.popLast() else { return nil }
        let record = action.record
        let assetID = record.assetID

        if let previousSessionID = action.previousSessionID, let previous = action.previous {
            // Hand the decision back to the earlier session it came from.
            if record.decision != .unmatch, let session {
                session.keptCount = max(session.keptCount - 1, 0)
            }
            record.sessionID = previousSessionID
            record.decision = previous
            record.madeFavorite = action.previousMadeFavorite
            record.addedToAlbumID = action.previousAlbumID
            history.removeAll { $0 === record }
            earlierDecisions[assetID] = previous
        } else if let previous = action.previous {
            if let session { adjustKeptCount(session, from: record.decision, to: previous) }
            record.decision = previous
            record.madeFavorite = action.previousMadeFavorite
            record.addedToAlbumID = action.previousAlbumID
        } else {
            if record.decision != .unmatch, let session {
                session.keptCount = max(session.keptCount - 1, 0)
            }
            history.removeAll { $0 === record }
            context.delete(record)
        }
        try? context.save()

        if !queue.contains(assetID) {
            // Decided before a relaunch, so it isn't in this visit's queue.
            queue.insert(assetID, at: min(position, queue.count))
        }
        return (assetID, action.madeFavorite, action.addedToAlbumID)
    }

    /// The stored decision from an earlier session (asset IDs are unique).
    private func earlierRecord(for assetID: String, context: ModelContext) -> PhotoDecision? {
        let descriptor = FetchDescriptor<PhotoDecision>(predicate: #Predicate { $0.assetID == assetID })
        return try? context.fetch(descriptor).first
    }

    private func adjustKeptCount(_ session: Session, from old: Decision, to new: Decision) {
        if old == .unmatch && new != .unmatch {
            session.keptCount += 1
        } else if old != .unmatch && new == .unmatch {
            session.keptCount = max(session.keptCount - 1, 0)
        }
    }

    private func startSession(context: ModelContext) -> Session {
        let session: Session
        switch mode {
        case .daily:
            session = Session(mode: .daily)
        case .month(let key):
            session = Session(mode: .month, monthKey: key.rawValue)
        }
        context.insert(session)
        self.session = session
        return session
    }

    /// Where Done, or running out of cards, leads: Your exes when there are
    /// any, otherwise Session complete. A session with zero exes ends here.
    func finish(context: ModelContext) -> AppRoute {
        if exesCount > 0, let session {
            return .yourExes(sessionID: session.id)
        }
        let endedID = session?.id
        if let session {
            session.endedAt = .now
            try? context.save()
            self.session = nil
            // history and actions are left as they are: the deck is on its way
            // out to Session complete (which has no way back to it), and
            // clearing them would flash it empty during the transition.
        }
        return .sessionComplete(sessionID: endedID)
    }
}

/// The deck's queue and pages, built off the main thread from plain values.
nonisolated struct DeckPlan: Sendable {
    var queue: [String] = []
    var queueMonths: [String: MonthKey] = [:]
    var pages: [String] = []

    init(mode: DeckMode, index: LibraryIndex, decided: Set<String>, dailyGoal: Int, doneToday: Int) {
        switch mode {
        case .daily:
            let queued = DailyPlan.queue(
                index: index,
                excluding: decided,
                limit: DailyPlan.batchSize(goal: dailyGoal, doneToday: doneToday)
            )
            queue = queued.map(\.assetID)
            for photo in queued {
                queueMonths[photo.assetID] = photo.month
            }
        case .month(let key):
            queue = (index.months[key] ?? []).filter { !decided.contains($0) }
            for assetID in queue {
                queueMonths[assetID] = key
            }
        }

        let month: MonthKey?
        switch mode {
        case .month(let key): month = key
        case .daily: month = queue.first.flatMap { queueMonths[$0] }
        }
        // Undated photos have no month to browse, so just the queue.
        pages = month.flatMap { index.months[$0] } ?? queue
        if let month {
            for assetID in pages where queueMonths[assetID] == nil {
                queueMonths[assetID] = month
            }
        }
    }
}
