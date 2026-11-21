//
//  PreviewData.swift
//  ExposureTherapy
//
//  Sample library and SwiftData records for Previews. Never reads the real
//  photo library. Roughly matches the Home mockup: in 2019, Jan–Mar and May
//  are done, June is 62% reviewed, and October has no photos.
//

import Foundation
import Photos
import SwiftData

enum PreviewData {
    /// Photos per month in the sample library. Missing months have no photos.
    private static let photoCounts: [MonthKey: Int] = {
        var counts: [MonthKey: Int] = [:]
        for month in 1...12 {
            counts[MonthKey(year: 2018, month: month)] = 20 + month
            if month != 10 {
                counts[MonthKey(year: 2019, month: month)] = 50
            }
            if month <= 4 {
                counts[MonthKey(year: 2020, month: month)] = 35
            }
        }
        return counts
    }()

    /// How many photos in each month have a keep decision.
    private static let reviewedCounts: [MonthKey: Int] = {
        var counts: [MonthKey: Int] = [:]
        for month in 1...12 {
            counts[MonthKey(year: 2018, month: month)] = 20 + month
        }
        for month in [1, 2, 5] {
            counts[MonthKey(year: 2019, month: month)] = 50
        }
        // March: 45 kept here plus 5 deleted (see `deletedMonthKeys`).
        counts[MonthKey(year: 2019, month: 3)] = 45
        counts[MonthKey(year: 2019, month: 6)] = 31
        return counts
    }()

    /// Five photos deleted from March 2019, which no longer appear in the library.
    static let deletedMonthKeys = Array(repeating: MonthKey(year: 2019, month: 3).rawValue, count: 5)

    private static func assetID(_ key: MonthKey, _ number: Int) -> String {
        "preview-\(key.rawValue)-\(number)"
    }

    static let index: LibraryIndex = {
        var index = LibraryIndex()
        for (key, count) in photoCounts {
            // March 2019 lost 5 photos to a Breakup.
            let remaining = key == MonthKey(year: 2019, month: 3) ? count - 5 : count
            index.months[key] = (0..<remaining).map { assetID(key, $0) }
        }
        index.undated = ["preview-undated-0", "preview-undated-1"]
        return index
    }()

    static let reviewedIDs: Set<String> = {
        var ids: Set<String> = []
        for (key, count) in reviewedCounts {
            for number in 0..<count {
                ids.insert(assetID(key, number))
            }
        }
        return ids
    }()

    static let progress = LibraryProgress(index: index, reviewedIDs: reviewedIDs, deletedMonthKeys: deletedMonthKeys)

    static func library(authorization: PHAuthorizationStatus = .authorized) -> PhotoLibrary {
        PhotoLibrary(previewIndex: index, authorization: authorization)
    }

    /// An in-memory store holding the sample decisions and deletions.
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer(
                for: PhotoDecision.self, DeletedPhoto.self, Session.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let context = container.mainContext
            let sessionID = UUID()
            for id in reviewedIDs {
                context.insert(PhotoDecision(assetID: id, decision: .keep, sessionID: sessionID))
            }
            for (number, monthKey) in deletedMonthKeys.enumerated() {
                context.insert(DeletedPhoto(assetID: "preview-deleted-\(number)", bytes: 2_400_000, monthKey: monthKey))
            }
            return container
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }()
}
