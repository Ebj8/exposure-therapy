//
//  Theme.swift
//  ExposureTherapy
//
//  Colors, spacing, corner radii and sizes from SPEC.md → "Design system".
//

import SwiftUI

// MARK: - Colors

/// Named colors from Assets.xcassets, so views never contain hex values.
///
/// These are declared by hand instead of using Xcode's generated asset
/// symbols, because the generator skips "teal" and "white": SwiftUI already
/// has `Color.teal` and `Color.white`, and `.teal` would silently resolve to
/// the system teal. Those two are exposed as `brandTeal` and `brandWhite`.
extension ShapeStyle where Self == Color {
    static var rose: Color { Color("rose") }
    static var roseDark: Color { Color("roseDark") }
    static var blush: Color { Color("blush") }
    static var cream: Color { Color("cream") }
    static var plum: Color { Color("plum") }
    static var plumRaised: Color { Color("plumRaised") }
    static var muted: Color { Color("muted") }
    static var line: Color { Color("line") }
    static var brandTeal: Color { Color("teal") }
    static var tealLight: Color { Color("tealLight") }
    static var coral: Color { Color("coral") }
    static var brandWhite: Color { Color("white") }
}

// MARK: - Layout

enum Spacing {
    /// Padding between the screen edge and content.
    static let screen: CGFloat = 20
    /// Smallest gap between blocks.
    static let blockTight: CGFloat = 10
    /// Default gap between blocks.
    static let block: CGFloat = 14
    /// Largest gap between blocks.
    static let blockLoose: CGFloat = 18
}

enum Radius {
    /// Stat tiles and month tiles (14–18 pt).
    static let tile: CGFloat = 16
    /// Cards (20–26 pt).
    static let card: CGFloat = 24
    /// The swipe card.
    static let swipeCard: CGFloat = 30
    /// The app icon in the Home header.
    static let headerIcon: CGFloat = 10
}

enum Size {
    /// Minimum tap target.
    static let minTapTarget: CGFloat = 44
    /// The app icon in the Home header.
    static let headerIcon: CGFloat = 40
}
