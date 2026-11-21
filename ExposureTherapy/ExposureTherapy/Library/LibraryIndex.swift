//
//  LibraryIndex.swift
//  ExposureTherapy
//
//  SPEC.md → Data → Reading the library. A snapshot of every image's
//  localIdentifier, grouped by creation month, oldest first.
//

import Foundation
import Photos

nonisolated struct LibraryIndex: Sendable {
    /// Asset IDs per month, in creation-date order.
    var months: [MonthKey: [String]] = [:]
    /// Asset IDs of photos with no creation date.
    var undated: [String] = []

    static let empty = LibraryIndex()

    /// Number of images in the library now.
    var totalCount: Int {
        months.values.reduce(undated.count) { $0 + $1.count }
    }

    /// Fetches every image in the library, oldest first, and groups the IDs
    /// by month in the phone's calendar. This touches every asset, so call
    /// it off the main actor.
    static func fetch(calendar: Calendar = .current) -> LibraryIndex {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let assets = PHAsset.fetchAssets(with: .image, options: options)

        var index = LibraryIndex()
        assets.enumerateObjects { asset, _, _ in
            if let date = asset.creationDate {
                index.months[MonthKey(date: date, calendar: calendar), default: []].append(asset.localIdentifier)
            } else {
                index.undated.append(asset.localIdentifier)
            }
        }
        return index
    }
}
