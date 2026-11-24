//
//  Typography.swift
//  ExposureTherapy
//
//  Bundled fonts (listed under UIAppFonts in Info.plist). Names are the
//  fonts' PostScript names, not their file names.
//

import SwiftUI

extension Font {
    /// The weights of Inter bundled with the app.
    enum InterWeight: String {
        case regular = "Inter18pt-Regular"
        case semibold = "Inter18pt-SemiBold"
        case bold = "Inter18pt-Bold"
    }

    /// Bricolage Grotesque ExtraBold, for headings and big numbers. Uses the
    /// 24 pt optical-size cut, which suits the 19–36 pt heading range.
    /// Scales with Dynamic Type relative to `textStyle`.
    static func bricolage(_ size: CGFloat, relativeTo textStyle: TextStyle = .title) -> Font {
        .custom("BricolageGrotesque24pt-ExtraBold", size: size, relativeTo: textStyle)
    }

    /// Inter, for body text (12–16 pt).
    /// Scales with Dynamic Type relative to `textStyle`.
    static func inter(_ size: CGFloat, _ weight: InterWeight = .regular, relativeTo textStyle: TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: textStyle)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Text("Ready to let go?").font(.bricolage(34, relativeTo: .largeTitle))
        Text("Review 50 photos to reach your daily goal.").font(.bricolage(26))
        Text("Exposure Therapy").font(.bricolage(19, relativeTo: .headline))
        Text("Inter Regular 16").font(.inter(16))
        Text("Inter SemiBold 16").font(.inter(16, .semibold))
        Text("Inter Bold 16").font(.inter(16, .bold))
    }
    .foregroundStyle(.plum)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.cream)
}
