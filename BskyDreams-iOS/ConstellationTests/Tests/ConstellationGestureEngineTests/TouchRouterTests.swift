import Testing
@testable import ConstellationGestureEngine

// Helpers for collecting events
extension ConstellationTouchRouter {
    func collect(_ body: (ConstellationTouchRouter) -> Void) -> [Event] {
        var events: [Event] = []
        onEvent = { events.append($0) }
        body(self)
        onEvent = nil
        return events
    }
}

// MARK: - Gesture 1: Single tap selects a node

@Suite("Gesture 1 — Single Tap")
struct TapTests {

    @Test("Tap with no movement fires .tap at the original touch-down location")
    func tapAtExactLocation() {
        let router = ConstellationTouchRouter()
        let events = router.collect { r in
            r.touchBegan(id: 1, x: 150, y: 300)
            r.touchEnded(id: 1, x: 150, y: 300)
        }
        #expect(events.count == 1)
        guard case .tap(let pt) = events[0] else {
            Issue.record("Expected .tap, got \(events[0])"); return
        }
        #expect(pt.x == 150)
        #expect(pt.y == 300)
    }

    @Test("Tap with movement BELOW the drag threshold still fires .tap")
    func tapWithSubThresholdMovement() {
        let router = ConstellationTouchRouter(dragThreshold: 6)
        let events = router.collect { r in
            r.touchBegan(id: 1, x: 100, y: 100)
            r.touchMoved(id: 1, x: 103, y: 100)  // 3pt — below 6pt threshold
            r.touchEnded(id: 1, x: 103, y: 100)
        }
        #expect(events.count == 1)
        guard case .tap = events[0] else {
            Issue.record("Expected .tap for sub-threshold movement, got \(events[0])"); return
        }
    }

    @Test("Tap fires at the ORIGINAL touch-down point, not the lift point")
    func tapUsesStartLocation() {
        let router = ConstellationTouchRouter(dragThreshold: 6)
        let events = router.collect { r in
            r.touchBegan(id: 1, x: 200, y: 400)
            r.touchMoved(id: 1, x: 203, y: 400)  // tiny sub-threshold movement
            r.touchEnded(id: 1, x: 203, y: 400)
        }
        guard case .tap(let pt) = events.first else {
            Issue.record("Expected .tap"); return
        }
        // The tap location must be the START (200, 400), not the end (203, 400)
        #expect(pt.x == 200, "Tap must use the touch-down point for hitNode accuracy")
        #expect(pt.y == 400)
    }

    @Test("Movement ABOVE the drag threshold fires .panChanged/.panEnded, NOT .tap")
    func dragDoesNotFireTap() {
        let router = ConstellationTouchRouter(dragThreshold: 6)
        let events = router.collect { r in
            r.touchBegan(id: 1, x: 100, y: 100)
            r.touchMoved(id: 1, x: 120, y: 100)  // 20pt — above threshold
            r.touchEnded(id: 1, x: 120, y: 100)
        }
        let hasTap = events.contains { if case .tap = $0 { return true }; return false }
        #expect(!hasTap, "A drag must NOT fire .tap")
        let hasPanEnded = events.contains { if case .panEnded = $0 { return true }; return false }
        #expect(hasPanEnded, "A drag must fire .panEnded")
    }
}

// MARK: - Gesture 2: Single-finger drag moves a node

@Suite("Gesture 2 — Single-Finger Drag")
struct SingleFingerDragTests {

    @Test("Drag past threshold fires .panChanged with correct start and translation")
    func dragFiresPanChanged() {
        let router = ConstellationTouchRouter(dragThreshold: 6)
        let events = router.collect { r in
            r.touchBegan(id: 1, x: 50, y: 50)
            r.touchMoved(id: 1, x: 80, y: 60)   // 30pt right, 10pt down
        }
        let changed = events.compactMap { e -> (start: ConstellationTouchRouter.Point, translation: (width: Double, height: Double))? in
            if case .panChanged(let s, let t) = e { return (s, t) }; return nil
        }
        #expect(!changed.isEmpty, "Dragging 30pt must fire .panChanged")
        guard let last = changed.last else { return }
        #expect(last.start.x == 50, "Start must be the original touch-down x")
        #expect(last.start.y == 50, "Start must be the original touch-down y")
        #expect(last.translation.width  == 30, "Translation width = current - start")
        #expect(last.translation.height == 10, "Translation height = current - start")
    }

    @Test("Drag end fires .panEnded with the full translation")
    func dragFiresPanEnded() {
        let router = ConstellationTouchRouter(dragThreshold: 6)
        let events = router.collect { r in
            r.touchBegan(id: 1, x: 0, y: 0)
            r.touchMoved(id: 1, x: 100, y: 0)
            r.touchEnded(id: 1, x: 100, y: 0)
        }
        let ended = events.compactMap { e -> (start: ConstellationTouchRouter.Point, translation: (width: Double, height: Double))? in
            if case .panEnded(let s, let t) = e { return (s, t) }; return nil
        }
        #expect(ended.count == 1)
        guard let e = ended.first else { return }
        #expect(e.start.x == 0)
        #expect(e.translation.width == 100)
    }

    @Test("panChanged fires for each move event while dragging")
    func panChangedFiresContinuously() {
        let router = ConstellationTouchRouter(dragThreshold: 6)
        var changedCount = 0
        router.onEvent = { if case .panChanged = $0 { changedCount += 1 } }
        router.touchBegan(id: 1, x: 0, y: 0)
        router.touchMoved(id: 1, x: 10, y: 0)   // triggers (10 > 6)
        router.touchMoved(id: 1, x: 20, y: 0)   // triggers
        router.touchMoved(id: 1, x: 30, y: 0)   // triggers
        #expect(changedCount == 3)
    }

    @Test("panChanged always reports translation from the original touch-down, not from the last event")
    func translationFromStartNotLastEvent() {
        let router = ConstellationTouchRouter(dragThreshold: 6)
        var lastTranslation: (width: Double, height: Double) = (0, 0)
        router.onEvent = {
            if case .panChanged(_, let t) = $0 { lastTranslation = t }
        }
        router.touchBegan(id: 1, x: 0, y: 0)
        router.touchMoved(id: 1, x: 10, y: 0)
        router.touchMoved(id: 1, x: 50, y: 0)
        // Translation must be (50, 0) from start, not (40, 0) since last event
        #expect(lastTranslation.width == 50, "Translation must accumulate from start, not from last event")
    }
}

// MARK: - Gesture 3: Two-finger pinch zooms

@Suite("Gesture 3 — Two-Finger Pinch")
struct PinchTests {

    @Test("Adding a second touch triggers pinch mode — no pan events emitted")
    func secondTouchStartsPinch() {
        let router = ConstellationTouchRouter()
        var events: [ConstellationTouchRouter.Event] = []
        router.onEvent = { events.append($0) }

        router.touchBegan(id: 1, x: 0, y: 0)
        router.touchBegan(id: 2, x: 100, y: 0)  // start distance = 100
        router.touchMoved(id: 2, x: 200, y: 0)  // distance = 200 → scale = 2.0

        let pans = events.filter { if case .panChanged = $0 { return true }; return false }
        #expect(pans.isEmpty, "No pan events should fire when pinching")

        let pinches = events.compactMap { e -> Double? in
            if case .pinchChanged(let s) = e { return s }; return nil
        }
        #expect(!pinches.isEmpty)
        #expect(abs(pinches.last! - 2.0) < 0.01, "Scale should be ~2.0 when distance doubles")
    }

    @Test("Pinch scale of 0.5 when fingers move closer")
    func pinchScaleDecreases() {
        let router = ConstellationTouchRouter()
        var lastScale: Double = 0
        router.onEvent = { if case .pinchChanged(let s) = $0 { lastScale = s } }

        router.touchBegan(id: 1, x: 0, y: 0)
        router.touchBegan(id: 2, x: 100, y: 0)  // start distance = 100
        router.touchMoved(id: 1, x: 0, y: 0)
        router.touchMoved(id: 2, x: 50, y: 0)   // distance = 50 → scale = 0.5

        #expect(abs(lastScale - 0.5) < 0.01, "Scale should be 0.5 when distance halves")
    }

    @Test("Lifting both pinch fingers fires .pinchEnded")
    func pinchEnds() {
        let router = ConstellationTouchRouter()
        var gotPinchEnded = false
        router.onEvent = { if case .pinchEnded = $0 { gotPinchEnded = true } }

        router.touchBegan(id: 1, x: 0, y: 0)
        router.touchBegan(id: 2, x: 100, y: 0)
        router.touchMoved(id: 2, x: 150, y: 0)
        router.touchEnded(id: 2, x: 150, y: 0)
        router.touchEnded(id: 1, x: 0, y: 0)

        #expect(gotPinchEnded)
    }

    @Test("Single-finger drag before pinch does not interfere with pinch scale")
    func prePinchDragDoesNotCorruptPinch() {
        let router = ConstellationTouchRouter()
        var pinchScales: [Double] = []
        router.onEvent = { if case .pinchChanged(let s) = $0 { pinchScales.append(s) } }

        // Background pan first
        router.touchBegan(id: 1, x: 0, y: 0)
        router.touchMoved(id: 1, x: 50, y: 0)
        // Second finger arrives — starts pinch
        router.touchBegan(id: 2, x: 100, y: 0)   // start dist = dist(50,0)→(100,0) = 50
        router.touchMoved(id: 2, x: 200, y: 0)   // dist = dist(50,0)→(200,0) = 150 → scale = 3.0

        #expect(!pinchScales.isEmpty)
        #expect(abs(pinchScales.last! - 3.0) < 0.01)
    }
}

// MARK: - Gesture 4: Background pan moves the viewport

@Suite("Gesture 4 — Background Pan")
struct BackgroundPanTests {

    @Test("Background pan fires panChanged with the full translation from start")
    func backgroundPanTranslation() {
        let router = ConstellationTouchRouter(dragThreshold: 6)
        var translation: (width: Double, height: Double) = (0, 0)
        router.onEvent = { if case .panChanged(_, let t) = $0 { translation = t } }

        router.touchBegan(id: 1, x: 10, y: 20)
        router.touchMoved(id: 1, x: 90, y: 70)   // 80pt right, 50pt down

        #expect(translation.width  == 80)
        #expect(translation.height == 50)
    }

    @Test("Background pan ends with .panEnded, not .tap")
    func backgroundPanEndIsNotTap() {
        let router = ConstellationTouchRouter()
        var events: [ConstellationTouchRouter.Event] = []
        router.onEvent = { events.append($0) }

        router.touchBegan(id: 1, x: 0, y: 0)
        router.touchMoved(id: 1, x: 100, y: 0)
        router.touchEnded(id: 1, x: 100, y: 0)

        let hasTap = events.contains { if case .tap = $0 { return true }; return false }
        #expect(!hasTap)
        let hasPanEnded = events.contains { if case .panEnded = $0 { return true }; return false }
        #expect(hasPanEnded)
    }
}

// MARK: - Sequence tests: interactions in order

@Suite("Gesture Sequences — Real-world interaction flows")
struct GestureSequenceTests {

    @Test("Tap then drag: two independent gesture sequences work correctly in order")
    func tapThenDrag() {
        let router = ConstellationTouchRouter()
        var taps = 0
        var panEndeds = 0
        router.onEvent = {
            if case .tap    = $0 { taps      += 1 }
            if case .panEnded = $0 { panEndeds += 1 }
        }

        // Gesture 1: tap
        router.touchBegan(id: 1, x: 100, y: 100)
        router.touchEnded(id: 1, x: 100, y: 100)

        // Gesture 2: drag
        router.touchBegan(id: 2, x: 50, y: 50)
        router.touchMoved(id: 2, x: 150, y: 50)
        router.touchEnded(id: 2, x: 150, y: 50)

        #expect(taps == 1)
        #expect(panEndeds == 1)
    }

    @Test("Back-to-back taps each fire .tap independently")
    func consecutiveTaps() {
        let router = ConstellationTouchRouter()
        var tapCount = 0
        var tapLocations: [ConstellationTouchRouter.Point] = []
        router.onEvent = {
            if case .tap(let pt) = $0 { tapCount += 1; tapLocations.append(pt) }
        }

        router.touchBegan(id: 1, x: 100, y: 100)
        router.touchEnded(id: 1, x: 100, y: 100)

        router.touchBegan(id: 2, x: 200, y: 200)
        router.touchEnded(id: 2, x: 200, y: 200)

        #expect(tapCount == 2)
        #expect(tapLocations[0] == ConstellationTouchRouter.Point(100, 100))
        #expect(tapLocations[1] == ConstellationTouchRouter.Point(200, 200))
    }

    @Test("Pinch followed by single-finger pan works correctly")
    func pinchThenPan() {
        let router = ConstellationTouchRouter()
        var gotPinchEnded = false
        var gotPan = false
        router.onEvent = {
            if case .pinchEnded   = $0 { gotPinchEnded = true }
            if case .panChanged   = $0 { gotPan = true }
        }

        // Pinch
        router.touchBegan(id: 1, x: 0, y: 0)
        router.touchBegan(id: 2, x: 100, y: 0)
        router.touchMoved(id: 2, x: 200, y: 0)
        router.touchEnded(id: 2, x: 200, y: 0)
        router.touchEnded(id: 1, x: 0, y: 0)

        // Single-finger pan
        router.touchBegan(id: 3, x: 50, y: 50)
        router.touchMoved(id: 3, x: 150, y: 50)

        #expect(gotPinchEnded)
        #expect(gotPan)
    }

    @Test("Cancellation mid-drag fires .panEnded, not .tap")
    func cancelMidDragFiresPanEnded() {
        let router = ConstellationTouchRouter()
        var events: [ConstellationTouchRouter.Event] = []
        router.onEvent = { events.append($0) }

        router.touchBegan(id: 1, x: 0, y: 0)
        router.touchMoved(id: 1, x: 50, y: 0)
        router.touchCancelled()

        let hasPanEnded = events.contains { if case .panEnded = $0 { return true }; return false }
        let hasTap      = events.contains { if case .tap      = $0 { return true }; return false }
        #expect(hasPanEnded)
        #expect(!hasTap)
    }
}
