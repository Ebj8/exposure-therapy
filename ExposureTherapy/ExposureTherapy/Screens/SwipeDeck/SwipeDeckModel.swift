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
    /// Unmatched photos in this session, waiting for a Breakup.
    private(set) var exesCount = 0
    private(set) var isLoaded = false

    /// The open session, created on the first decision if there isn't one.
    @ObservationIgnored private var session: Session?

    init(mode: DeckMode) {
        self.mode = mode
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
            let descriptor = FetchDescriptor<PhotoDecision>(predicate: #Predicate { $0.sessionID == sessionID })
            exesCount = ((try? context.fetch(descriptor)) ?? []).filter { $0.decision == .unmatch }.count
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
    func decide(_ decision: Decision, context: ModelContext) {
        guard let assetID = currentID else { return }
        let session = self.session ?? startSession(context: context)

        context.insert(PhotoDecision(assetID: assetID, decision: decision, sessionID: session.id))
        if decision == .unmatch {
            exesCount += 1
        } else {
            session.keptCount += 1
        }
        // Save right away so decisions survive the app being quit.
        try? context.save()
        position += 1
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
        if exesCount > 0 {
            return .yourExes
        }
        if let session {
            session.endedAt = .now
            try? context.save()
            self.session = nil
        }
        return .sessionComplete
    }
}
