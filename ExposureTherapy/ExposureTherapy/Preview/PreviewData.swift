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
import UIKit

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

    /// A simple generated landscape for a sample asset ID like
    /// "preview-2019-06-12", dated within that month.
    static func cardPhoto(for assetID: String) -> CardPhoto {
        let parts = assetID.split(separator: "-")
        let number = parts.count == 4 ? Int(parts[3]) ?? 0 : 0
        var date: Date?
        if parts.count == 4, let year = Int(parts[1]), let month = Int(parts[2]) {
            date = Calendar.current.date(from: DateComponents(year: year, month: month, day: number % 28 + 1, hour: 20, minute: 42))
        }

        let hue = CGFloat(number * 37 % 360) / 360
        let size = CGSize(width: 600, height: 800)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(hue: hue, saturation: 0.3, brightness: 0.96, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(hue: 0.13, saturation: 0.3, brightness: 1, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 360, y: 160, width: 140, height: 140))
            UIColor(hue: hue, saturation: 0.45, brightness: 0.55, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 520, width: size.width, height: 280))
        }
        return CardPhoto(image: image, creationDate: date, fileSize: 2_400_000 + Int64(number) * 37_000)
    }

    static let albums = [
        PhotoAlbum(id: "preview-album-3", title: "Beach days", count: 48),
        PhotoAlbum(id: "preview-album-2", title: "Family", count: 212),
        PhotoAlbum(id: "preview-album-1", title: "Recipes", count: 17),
    ]

    /// A May 2019 session that just ended with a Breakup.
    static let completedSessionID = UUID()

    /// An open June 2019 session with 14 exes waiting for a Breakup.
    static let exesSessionID = UUID()

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
            // Finished sessions today and on the 6 days before: a 7-day streak.
            context.insert(Session(
                id: completedSessionID, mode: .month, monthKey: MonthKey(year: 2019, month: 5).rawValue,
                startedAt: .now.addingTimeInterval(-600), endedAt: .now,
                keptCount: 163, deletedCount: 47, bytesFreed: 212_000_000
            ))
            for daysAgo in 1...6 {
                let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
                context.insert(Session(mode: .month, monthKey: "2018-01", startedAt: day, endedAt: day, keptCount: 10))
            }

            let june = MonthKey(year: 2019, month: 6)
            context.insert(Session(id: exesSessionID, mode: .month, monthKey: june.rawValue))
            for number in 31..<45 {
                context.insert(PhotoDecision(assetID: assetID(june, number), decision: .unmatch, sessionID: exesSessionID))
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
