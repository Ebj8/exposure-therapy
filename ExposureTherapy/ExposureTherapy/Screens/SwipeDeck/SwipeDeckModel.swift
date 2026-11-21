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

    /// This session's decisions, oldest first, for multi-step undo.
    private(set) var history: [PhotoDecision] = []

    /// The open session, created on the first decision if there isn't one.
    @ObservationIgnored private var session: Session?

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

    var title: String {
        switch mode {
        case .daily: "Today's session"
        case .month(let key): key.title
        }
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

    /// Share of the queue decided, 0 to 1.
    var progress: Double {
        queue.isEmpty ? 0 : Double(position) / Double(queue.count)
    }

    // MARK: Loading

    func load(index: LibraryIndex, context: ModelContext) {
        guard !isLoaded else { return }

        // Skip anything already decided, including exes still waiting for a Breakup.
        let decided = Set(((try? context.fetch(FetchDescriptor<PhotoDecision>())) ?? []).map(\.assetID))
        switch mode {
        case .daily:
            // The daily queue arrives in Milestone 7.
            queue = []
        case .month(let key):
            queue = (index.months[key] ?? []).filter { !decided.contains($0) }
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
        if let session {
            session.endedAt = .now
            try? context.save()
            self.session = nil
            // Undo only reaches back through the current session.
            history = []
        }
        return .sessionComplete
    }
}
