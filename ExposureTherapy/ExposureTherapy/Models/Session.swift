//
//  Session.swift
//  ExposureTherapy
//
//  SPEC.md → Data → SwiftData models. A session ends at a Breakup, or at
//  Done with zero exes.
//

import Foundation
import SwiftData

nonisolated enum SessionMode: String, Codable, Sendable {
    case daily
    case month
}

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var mode: SessionMode
    /// `MonthKey.rawValue` for month sessions; nil for daily sessions.
    var monthKey: String?
    var startedAt: Date
    var endedAt: Date?
    var keptCount: Int
    var deletedCount: Int
    var bytesFreed: Int64

    init(
        id: UUID = UUID(),
        mode: SessionMode,
        monthKey: String? = nil,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        keptCount: Int = 0,
        deletedCount: Int = 0,
        bytesFreed: Int64 = 0
    ) {
        self.id = id
        self.mode = mode
        self.monthKey = monthKey
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.keptCount = keptCount
        self.deletedCount = deletedCount
        self.bytesFreed = bytesFreed
    }
}
