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

    /// Daily mode: decisions already made today before this queue, so the
    /// count reads "31 of 50 today" after a break.
    private(set) var dailyOffset = 0

    /// This session's decisions, oldest first, for multi-step undo.
    private(set) var history: [PhotoDecision] = []

    /// The open session, created on the first decision if there isn't one.
    @ObservationIgnored private var session: Session?
    /// Months of queued photos, for the daily deck's title.
    @ObservationIgnored private var queueMonths: [String: MonthKey] = [:]
    @ObservationIgnored private var index: LibraryIndex = .empty
    /// Decisions from earlier sessions, for marking neighbors in the filmstrip.
    /// This session's are read live from `history`, so rescues show up too.
    @ObservationIgnored private var earlierDecisions: [String: Decision] = [:]

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

    /// Month mode: the month. Daily mode: the top card's month, since the
    /// queue runs across months.
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
        queue.indices.contains(position) ? queue[position] : nil
    }

    var nextID: String? {
        queue.indices.contains(position + 1) ? queue[position + 1] : nil
    }

    /// The next 3 cards after the top one, for prefetching.
    var upcomingIDs: [String] {
        Array(queue.dropFirst(position + 1).prefix(3))
    }

    var isOutOfCards: Bool {
        isLoaded && position >= queue.count
    }

    /// 1-based position of the top card, for "{position} of {total}".
    var displayPosition: Int {
        min(position + 1, queue.count)
    }

    /// Share of the session decided, 0 to 1.
    var progress: Double {
        let total = dailyOffset + queue.count
        return total == 0 ? 0 : Double(dailyOffset + position) / Double(total)
    }

    // MARK: Loading

    func load(index: LibraryIndex, dailyGoal: Int, context: ModelContext) {
        guard !isLoaded else { return }
        self.index = index

        // Skip anything already decided, including exes still waiting for a Breakup.
        let allDecisions = (try? context.fetch(FetchDescriptor<PhotoDecision>())) ?? []
        let decided = Set(allDecisions.map(\.assetID))
        switch mode {
        case .daily:
            let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
            let doneToday = DailyPlan.doneToday(decisions: allDecisions, sessions: sessions)
            // After today's goal is met, "Keep going anyway" starts a fresh count.
            dailyOffset = doneToday < dailyGoal ? doneToday : 0
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

        session = openSession(context: context)
        if let session {
            let sessionID = session.id
            let descriptor = FetchDescriptor<PhotoDecision>(
                predicate: #Predicate { $0.sessionID == sessionID },
                sortBy: [SortDescriptor(\.decidedAt)]
            )
            history = (try? context.fetch(descriptor)) ?? []
        }
        let sessionIDs = Set(history.map(\.assetID))
        for record in allDecisions where !sessionIDs.contains(record.assetID) {
            earlierDecisions[record.assetID] = record.decision
        }
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

    // MARK: Neighbors (filmstrip and peek)

    /// Where a photo stands, for marking it in the filmstrip and peek.
    enum NeighborStatus {
        case current
        case kept
        case ex
        case undecided
    }

    /// The photo plus nearby photos from the same month, in library order:
    /// a window of up to `radius * 2 + 1` photos, centered on the photo when
    /// possible. Near the start or end of a month the window shifts to fill
    /// from the other side instead of reaching into the next month.
    func neighbors(of assetID: String, radius: Int) -> [String] {
        guard let month = queueMonths[assetID] ?? month(of: assetID),
              let ids = index.months[month],
              let position = ids.firstIndex(of: assetID)
        else { return [assetID] }

        let width = min(radius * 2 + 1, ids.count)
        let start = min(max(position - radius, 0), ids.count - width)
        return Array(ids[start..<(start + width)])
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

    // MARK: Deciding

    /// Records a decision for the top card and moves to the next one.
    /// `madeFavorite` and `addedToAlbumID` note Photos changes this decision
    /// made, so undo can reverse them.
    func decide(
        _ decision: Decision,
        madeFavorite: Bool = false,
        addedToAlbumID: String? = nil,
        context: ModelContext
    ) {
        guard let assetID = currentID else { return }
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
        if decision != .unmatch {
            session.keptCount += 1
        }
        // Save right away so decisions survive the app being quit.
        try? context.save()
        position += 1
    }

    // MARK: Undo

    var canUndo: Bool {
        !history.isEmpty
    }

    /// The decision Undo would reverse.
    var lastDecision: PhotoDecision? {
        history.last
    }

    /// Removes the most recent decision and puts its photo back on top.
    /// Reversing any Photos change is the caller's job, before calling this.
    func undo(context: ModelContext) {
        guard let record = history.popLast() else { return }
        let assetID = record.assetID

        if record.decision != .unmatch, let session {
            session.keptCount = max(session.keptCount - 1, 0)
        }
        context.delete(record)
        try? context.save()

        if position > 0 && queue[position - 1] == assetID {
            position -= 1
        } else {
            // Decided before a relaunch, so it isn't in this visit's queue.
            queue.insert(assetID, at: position)
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
            // Undo only reaches back through the current session.
            history = []
        }
        return .sessionComplete(sessionID: endedID)
    }
}
