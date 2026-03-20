import Foundation

/// Pure-Swift touch state machine — no UIKit dependency, fully testable.
///
/// Callers drive it with touchBegan/touchMoved/touchEnded/touchCancelled,
/// using any Hashable value as a touch identifier (on-device: ObjectIdentifier(uiTouch)).
///
/// Emits four event types that map 1-to-1 to the four required gestures:
///   .tap           → single-finger lift with < dragThreshold movement
///   .panChanged    → single-finger drag (called continuously while moving)
///   .panEnded      → single-finger drag released
///   .pinchChanged  → two-finger scale change (relative to the pinch start distance)
///   .pinchEnded    → two-finger gesture released
public final class ConstellationTouchRouter {

    // MARK: - Public types

    public struct Point: Equatable {
        public var x, y: Double
        public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    }

    public enum Event: Equatable {
        case tap(Point)
        case panChanged(start: Point, translation: (width: Double, height: Double))
        case panEnded(start: Point, translation: (width: Double, height: Double))
        case pinchChanged(Double)   // scale relative to pinch-start distance
        case pinchEnded

        // Equatable conformance for tuple members (tuples aren't Equatable by default)
        public static func == (lhs: Event, rhs: Event) -> Bool {
            switch (lhs, rhs) {
            case (.tap(let a), .tap(let b)):
                return a == b
            case (.panChanged(let sa, let ta), .panChanged(let sb, let tb)):
                return sa == sb && ta.width == tb.width && ta.height == tb.height
            case (.panEnded(let sa, let ta), .panEnded(let sb, let tb)):
                return sa == sb && ta.width == tb.width && ta.height == tb.height
            case (.pinchChanged(let a), .pinchChanged(let b)):
                return a == b
            case (.pinchEnded, .pinchEnded):
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Configuration

    /// Minimum movement (in points) before a touch is treated as a drag instead of a tap.
    public let dragThreshold: Double

    // MARK: - Callback

    public var onEvent: ((Event) -> Void)?

    // MARK: - Private state

    private struct TrackedTouch {
        var id: AnyHashable
        var start: Point
        var current: Point
    }

    /// At most 2 touches tracked simultaneously.
    private var tracked: [TrackedTouch] = []

    /// True once the primary touch has moved past dragThreshold.
    private var didDrag = false

    /// True when two touches are active (pinch mode).
    private var isPinching = false

    /// True when a pinch just ended — suppresses the spurious .tap that would
    /// otherwise fire when the last remaining finger is lifted.
    private var justEndedPinch = false

    /// Distance between the two touches when the pinch began.
    private var pinchStartDist: Double = 1

    // MARK: - Init

    public init(dragThreshold: Double = 6) {
        self.dragThreshold = dragThreshold
    }

    // MARK: - Input

    public func touchBegan(id: AnyHashable, x: Double, y: Double) {
        let pt = Point(x, y)

        if tracked.isEmpty {
            // First finger — start single-touch tracking
            tracked.append(TrackedTouch(id: id, start: pt, current: pt))
            didDrag = false

        } else if tracked.count == 1 && !isPinching {
            // Second finger — switch to pinch mode
            tracked.append(TrackedTouch(id: id, start: pt, current: pt))
            isPinching = true

            // End any in-progress single-finger drag cleanly before switching
            if didDrag, let primary = tracked.first {
                let tx = primary.current.x - primary.start.x
                let ty = primary.current.y - primary.start.y
                emit(.panEnded(start: primary.start, translation: (tx, ty)))
                didDrag = false
            }

            // Record initial pinch distance
            pinchStartDist = max(dist(tracked[0].current, tracked[1].current), 1)
        }
        // 3+ simultaneous fingers ignored
    }

    public func touchMoved(id: AnyHashable, x: Double, y: Double) {
        guard let idx = tracked.firstIndex(where: { $0.id == id }) else { return }
        tracked[idx].current = Point(x, y)

        if isPinching && tracked.count == 2 {
            // Pinch: report scale relative to start distance
            let d = max(dist(tracked[0].current, tracked[1].current), 1)
            emit(.pinchChanged(d / pinchStartDist))
            return
        }

        // Single-touch drag
        guard tracked.count == 1 else { return }
        let t = tracked[0]
        let tx = t.current.x - t.start.x
        let ty = t.current.y - t.start.y
        if sqrt(tx*tx + ty*ty) >= dragThreshold {
            didDrag = true
            emit(.panChanged(start: t.start, translation: (tx, ty)))
        }
    }

    public func touchEnded(id: AnyHashable, x: Double, y: Double) {
        guard let idx = tracked.firstIndex(where: { $0.id == id }) else { return }
        tracked[idx].current = Point(x, y)

        if isPinching {
            // Remove this touch from the pinch
            tracked.remove(at: idx)
            if tracked.count < 2 {
                isPinching = false
                emit(.pinchEnded)
                // If one finger remains, reset its start so it can pan from current position
                if !tracked.isEmpty {
                    let i = tracked.startIndex
                    tracked[i].start   = tracked[i].current
                    didDrag            = false
                    justEndedPinch     = true  // suppress tap from this finger's lift
                }
            }
            return
        }

        // Single-touch end
        let t = tracked[idx]
        let tx = t.current.x - t.start.x
        let ty = t.current.y - t.start.y

        if didDrag {
            emit(.panEnded(start: t.start, translation: (tx, ty)))
        } else if !justEndedPinch {
            emit(.tap(t.start))
        }

        tracked.remove(at: idx)
        didDrag        = false
        justEndedPinch = false
    }

    public func touchCancelled() {
        // Clean up — emit terminal events if mid-gesture
        if didDrag, let t = tracked.first {
            let tx = t.current.x - t.start.x
            let ty = t.current.y - t.start.y
            emit(.panEnded(start: t.start, translation: (tx, ty)))
        }
        if isPinching {
            emit(.pinchEnded)
        }
        tracked.removeAll()
        didDrag        = false
        isPinching     = false
        justEndedPinch = false
    }

    // MARK: - Helpers

    private func dist(_ a: Point, _ b: Point) -> Double {
        sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
    }

    private func emit(_ event: Event) {
        onEvent?(event)
    }
}
