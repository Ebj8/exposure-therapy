//
//  YourExesModel.swift
//  ExposureTherapy
//
//  SPEC.md → Screens → 3. Your exes, and Deletion (Breakup). Lists one
//  session's exes, toggles rescues, and runs the Breakup.
//

import Foundation
import SwiftData

@Observable
final class YourExesModel {
    struct Ex: Identifiable {
        let record: PhotoDecision
        var id: String { record.assetID }
        /// Rescued photos are kept; the rest are deleted at Breakup.
        var isRescued: Bool { record.decision != .unmatch }
    }

    let sessionID: UUID
    /// Everyone unmatched in this session when the screen opened, including
    /// any rescued since, so a rescue can be undone in place.
    private(set) var exes: [Ex] = []
    private(set) var session: Session?
    private(set) var isLoaded = false
    private(set) var isBreakingUp = false

    init(sessionID: UUID) {
        self.sessionID = sessionID
    }

    /// e.g. "June 2019 session".
    var sessionLabel: String {
        guard let session else { return "" }
        if session.mode == .month, let rawKey = session.monthKey, let key = MonthKey(rawValue: rawKey) {
            return "\(key.title) session"
        }
        return "Today's session"
    }

    /// Photos the Breakup will delete. Updates live as photos are rescued.
    var deleteCount: Int {
        exes.filter { !$0.isRescued }.count
    }

    func load(context: ModelContext) {
        guard !isLoaded else { return }
        let id = sessionID
        session = try? context.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })).first
        let descriptor = FetchDescriptor<PhotoDecision>(
            predicate: #Predicate { $0.sessionID == id },
            sortBy: [SortDescriptor(\.decidedAt)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        exes = records.filter { $0.decision == .unmatch }.map(Ex.init)
        isLoaded = true
    }

    /// Rescue or un-rescue. Saved straight away, so leaving with "Not yet"
    /// or quitting keeps the choice. Nothing changes in Photos.
    func toggleRescue(_ ex: Ex, context: ModelContext) {
        guard !isBreakingUp else { return }
        if ex.isRescued {
            ex.record.decision = .unmatch
            session?.keptCount = max((session?.keptCount ?? 1) - 1, 0)
        } else {
            ex.record.decision = .keep
            session?.keptCount += 1
        }
        try? context.save()
    }

    /// Deletes every un-rescued ex, after iOS confirms. Records the deletion
    /// and closes the session only if it succeeds.
    func breakup(library: PhotoLibrary, context: ModelContext) async -> DeletionResult {
        guard !isBreakingUp else { return .cancelled }
        isBreakingUp = true
        defer { isBreakingUp = false }

        let doomed = exes.filter { !$0.isRescued }.map(\.record)
        // Sizes and months must be read before the photos are gone.
        let candidates = await library.deletionCandidates(for: doomed.map(\.assetID))
        let result = await library.deletePhotos(candidates.map(\.assetID))
        guard result == .deleted else { return result }

        // The unmatch records stay: the Swipe deck underneath still holds
        // them, and with the session closed and a DeletedPhoto row written,
        // they're no longer pending.
        for candidate in candidates {
            context.insert(DeletedPhoto(assetID: candidate.assetID, bytes: candidate.bytes, monthKey: candidate.monthKey))
        }
        if let session {
            session.deletedCount += candidates.count
            session.bytesFreed += candidates.reduce(0) { $0 + $1.bytes }
            session.endedAt = .now
        }
        try? context.save()
        return .deleted
    }
}
