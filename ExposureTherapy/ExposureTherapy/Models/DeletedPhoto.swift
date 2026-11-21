//
//  DeletedPhoto.swift
//  ExposureTherapy
//
//  SPEC.md → Data → SwiftData models. Kept after deletion so stats survive
//  the photo being gone from the library.
//

import Foundation
import SwiftData

@Model
final class DeletedPhoto {
    var assetID: String
    var bytes: Int64
    var deletedAt: Date
    /// `MonthKey.rawValue` of the photo's creation month, or `MonthKey.undatedRawValue`.
    var monthKey: String

    init(assetID: String, bytes: Int64, deletedAt: Date = .now, monthKey: String) {
        self.assetID = assetID
        self.bytes = bytes
        self.deletedAt = deletedAt
        self.monthKey = monthKey
    }
}
