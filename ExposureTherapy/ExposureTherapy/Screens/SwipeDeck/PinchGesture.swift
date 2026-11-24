//
//  PinchGesture.swift
//  ExposureTherapy
//
//  A pinch that reports where the fingers are as well as how far apart,
//  so a photo can zoom and follow two fingers at once. SwiftUI's
//  MagnifyGesture only knows where the pinch started, so iOS 18 and later
//  use UIKit's pinch recognizer; iOS 17 falls back to zoom without moving.
//

import SwiftUI
import UIKit

/// One update of a pinch, in the coordinates of the view it's attached to.
struct PinchValue {
    /// How far apart the fingers are compared with the start (1 is no change).
    let scale: CGFloat
    /// Between the fingers when the pinch began.
    let startLocation: CGPoint
    /// Between the fingers now.
    let location: CGPoint
}

extension View {
    /// Calls `changed` as a two-finger pinch moves and `ended` when it ends.
    /// Works alongside the view's other gestures.
    func onPinch(changed: @escaping (PinchValue) -> Void, ended: @escaping () -> Void) -> some View {
        modifier(PinchModifier(changed: changed, ended: ended))
    }
}

private struct PinchModifier: ViewModifier {
    let changed: (PinchValue) -> Void
    let ended: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.gesture(PinchRecognizer(changed: changed, ended: ended))
        } else {
            content.simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        changed(PinchValue(scale: value.magnification, startLocation: value.startLocation, location: value.startLocation))
                    }
                    .onEnded { _ in ended() }
            )
        }
    }
}

@available(iOS 18.0, *)
private struct PinchRecognizer: UIGestureRecognizerRepresentable {
    let changed: (PinchValue) -> Void
    let ended: () -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var startLocation: CGPoint?

        // Swiping and double-tap keep working; the deck sorts out which wins.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        let recognizer = UIPinchGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            // With one finger lifted the midpoint jumps to the other finger;
            // hold still until both are down again.
            guard recognizer.numberOfTouches >= 2 else { return }
            let location = context.converter.localLocation
            let start = context.coordinator.startLocation ?? location
            context.coordinator.startLocation = start
            changed(PinchValue(scale: recognizer.scale, startLocation: start, location: location))
        case .ended, .cancelled, .failed:
            context.coordinator.startLocation = nil
            ended()
        default:
            break
        }
    }
}
