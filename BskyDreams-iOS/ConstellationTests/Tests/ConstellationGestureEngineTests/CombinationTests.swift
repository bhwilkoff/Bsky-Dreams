import Testing
import Darwin
@testable import ConstellationGestureEngine

// MARK: - Shared test harness

/// Simulates the ConstellationView state machine:
/// TouchRouter events → GestureEngine routing → state mutations
private final class GestureSimulator {

    let canvas: (width: Double, height: Double)
    var nodes: [GraphNode]
    var zoom:      Double = 1.0
    var panOffset: (width: Double, height: Double) = (0, 0)

    // Internal book-keeping (mirrors ConstellationView's @State)
    private var basePan:          (width: Double, height: Double) = (0, 0)
    private var baseZoom:         Double = 1.0
    private var dragTargetNodeId: String? = nil
    private var nodeDragStartPos: (x: Double, y: Double) = (0, 0)
    private var dragRoutingDone:  Bool = false

    var tapCount:      Int = 0
    var lastTapHit:    String? = nil   // id of the node that was tapped
    var panEndCount:   Int = 0
    var pinchEndCount: Int = 0

    init(canvas: (width: Double, height: Double) = (400, 800),
         nodes: [GraphNode] = []) {
        self.canvas = canvas
        self.nodes  = nodes
    }

    // MARK: Convenience geometry

    func screenPos(_ node: GraphNode) -> (x: Double, y: Double) {
        (
            x: canvas.width  / 2 + node.x * zoom + panOffset.width,
            y: canvas.height / 2 + node.y * zoom + panOffset.height
        )
    }

    // MARK: Event dispatch — called by the test with events from ConstellationTouchRouter

    func handle(_ event: ConstellationTouchRouter.Event) {
        switch event {

        case .tap(let pt):
            tapCount += 1
            let hit = ConstellationGestureEngine.hitNode(
                at:         (x: pt.x, y: pt.y),
                nodes:      nodes,
                canvasSize: canvas,
                zoom:       zoom,
                panOffset:  panOffset,
                maxDegree:  1
            )
            lastTapHit = hit?.id

        case .panChanged(let start, let translation):
            let dist = hypot(translation.width, translation.height)
            if !dragRoutingDone && dist > 6 {
                dragRoutingDone = true
                let route = ConstellationGestureEngine.routeDrag(
                    startPoint: (x: start.x, y: start.y),
                    nodes:      nodes,
                    canvasSize: canvas,
                    zoom:       zoom,
                    panOffset:  panOffset,
                    maxDegree:  1
                )
                switch route {
                case .nodeDrag(let nodeId, let startPos):
                    dragTargetNodeId = nodeId
                    nodeDragStartPos = startPos
                case .backgroundPan:
                    dragTargetNodeId = nil
                }
            }
            if let nodeId = dragTargetNodeId {
                let newPos = ConstellationGestureEngine.draggedNodePosition(
                    startGraphPos: nodeDragStartPos,
                    translation:   translation,
                    zoom:          zoom
                )
                if let idx = nodes.firstIndex(where: { $0.id == nodeId }) {
                    nodes[idx].x = newPos.x
                    nodes[idx].y = newPos.y
                }
            } else if dist > 6 {
                panOffset = (
                    width:  basePan.width  + translation.width,
                    height: basePan.height + translation.height
                )
            }

        case .panEnded(_, let translation):
            if dragTargetNodeId != nil {
                // node drag ended — nothing special needed for tests
            } else {
                // background pan ended — lock basePan
                basePan = (
                    width:  basePan.width  + translation.width,
                    height: basePan.height + translation.height
                )
                panOffset = basePan
            }
            dragTargetNodeId = nil
            dragRoutingDone  = false
            panEndCount += 1

        case .pinchChanged(let scale):
            zoom = max(0.3, min(4.0, baseZoom * scale))

        case .pinchEnded:
            baseZoom = zoom
            pinchEndCount += 1
        }
    }
}

// Convenience: run a body of router events through a simulator
extension GestureSimulator {
    func run(dragThreshold: Double = 6, _ body: (ConstellationTouchRouter) -> Void) {
        let router = ConstellationTouchRouter(dragThreshold: dragThreshold)
        router.onEvent = { [self] event in self.handle(event) }
        body(router)
    }
}

// MARK: - Suite 1: Each gesture works independently, no prior warm-up needed

@Suite("Combination — Each Gesture Works Independently (No Warm-Up)")
struct IndependentGestureTests {

    let seedNode = GraphNode(id: "seed", handle: "alice", isSeed: true, x: 0, y: 0)
    // screen pos at zoom=1, pan=0: (200, 400)

    @Test("Gesture 1: Tap on a node fires immediately and hits the correct node")
    func tapImmediately() {
        var sim = GestureSimulator(nodes: [seedNode])
        sim.run { r in
            r.touchBegan(id: 1, x: 200, y: 400)
            r.touchEnded(id: 1, x: 200, y: 400)
        }
        #expect(sim.tapCount == 1,        "Tap must fire on first interaction, no warm-up")
        #expect(sim.lastTapHit == "seed", "Tap must hit the seed node")
    }

    @Test("Gesture 2: Single-finger drag on a node moves the node immediately")
    func nodeDragImmediately() {
        var sim = GestureSimulator(nodes: [seedNode])
        let startX = 200.0, startY = 400.0
        sim.run { r in
            r.touchBegan(id: 1, x: startX,      y: startY)
            r.touchMoved(id: 1, x: startX + 50, y: startY + 30)
            r.touchEnded(id: 1, x: startX + 50, y: startY + 30)
        }
        #expect(abs(sim.nodes[0].x - 50) < 0.5, "Node x must move 50pt right (zoom=1)")
        #expect(abs(sim.nodes[0].y - 30) < 0.5, "Node y must move 30pt down (zoom=1)")
        // Pan offset must stay at zero — this was a node drag, not a background pan
        #expect(sim.panOffset.width  == 0, "Pan must not change during node drag")
        #expect(sim.panOffset.height == 0, "Pan must not change during node drag")
    }

    @Test("Gesture 3: Single-finger drag on empty space pans the viewport immediately")
    func backgroundPanImmediately() {
        var sim = GestureSimulator(nodes: [seedNode])
        sim.run { r in
            r.touchBegan(id: 1, x: 10,  y: 10)
            r.touchMoved(id: 1, x: 80,  y: 60)   // 70pt right, 50pt down
            r.touchEnded(id: 1, x: 80,  y: 60)
        }
        #expect(abs(sim.panOffset.width  - 70) < 0.5, "Pan must move viewport right by 70pt")
        #expect(abs(sim.panOffset.height - 50) < 0.5, "Pan must move viewport down by 50pt")
        // Node must NOT have moved
        #expect(sim.nodes[0].x == 0, "Node must not move during background pan")
        #expect(sim.nodes[0].y == 0, "Node must not move during background pan")
    }

    @Test("Gesture 4: Two-finger pinch zooms immediately")
    func pinchImmediately() {
        var sim = GestureSimulator(nodes: [seedNode])
        sim.run { r in
            r.touchBegan(id: 1, x: 0,   y: 0)
            r.touchBegan(id: 2, x: 100, y: 0)  // start dist = 100
            r.touchMoved(id: 2, x: 200, y: 0)  // dist = 200 → scale = 2.0
            r.touchEnded(id: 2, x: 200, y: 0)
            r.touchEnded(id: 1, x: 0,   y: 0)
        }
        #expect(abs(sim.zoom - 2.0) < 0.01, "Zoom must reach 2.0 immediately")
        #expect(sim.pinchEndCount == 1)
    }
}

// MARK: - Suite 2: Gestures work correctly after state changes

@Suite("Combination — Gestures Work Correctly After State Changes")
struct PostStateChangeTests {

    let seedNode = GraphNode(id: "seed", handle: "alice", isSeed: true, x: 0, y: 0)

    @Test("Tap hits node after a background pan shifts the viewport")
    func tapAfterPan() {
        var sim = GestureSimulator(nodes: [seedNode])

        // Step 1: background pan by (80, 50)
        sim.run { r in
            r.touchBegan(id: 1, x: 10, y: 10)
            r.touchMoved(id: 1, x: 90, y: 60)
            r.touchEnded(id: 1, x: 90, y: 60)
        }
        #expect(abs(sim.panOffset.width - 80) < 0.5)

        // Step 2: tap at node's NEW screen position
        let newScreen = sim.screenPos(sim.nodes[0])
        sim.run { r in
            r.touchBegan(id: 2, x: newScreen.x, y: newScreen.y)
            r.touchEnded(id: 2, x: newScreen.x, y: newScreen.y)
        }
        #expect(sim.tapCount  == 1,        "One tap must fire after pan")
        #expect(sim.lastTapHit == "seed",  "Tap at new screen pos must hit node after pan")
    }

    @Test("Tap hits node after a pinch zoom changes the scale")
    func tapAfterZoom() {
        var sim = GestureSimulator(nodes: [seedNode])

        // Step 1: pinch to zoom 2x
        sim.run { r in
            r.touchBegan(id: 1, x: 100, y: 400)
            r.touchBegan(id: 2, x: 300, y: 400)  // start dist = 200
            r.touchMoved(id: 2, x: 500, y: 400)  // dist = 400 → scale = 2.0
            r.touchEnded(id: 2, x: 500, y: 400)
            r.touchEnded(id: 1, x: 100, y: 400)
        }
        #expect(abs(sim.zoom - 2.0) < 0.1)

        // Step 2: tap at node's screen position (seed at (0,0) is still at screen center)
        let nodeScreen = sim.screenPos(sim.nodes[0])
        sim.run { r in
            r.touchBegan(id: 3, x: nodeScreen.x, y: nodeScreen.y)
            r.touchEnded(id: 3, x: nodeScreen.x, y: nodeScreen.y)
        }
        #expect(sim.tapCount  == 1,       "One tap must fire after zoom")
        #expect(sim.lastTapHit == "seed", "Tap must hit node after zoom using updated zoom")
    }

    @Test("Node drag correctly moves node after a background pan has shifted viewport")
    func nodeDragAfterPan() {
        var sim = GestureSimulator(
            nodes: [GraphNode(id: "n1", handle: "bob", isSeed: true, x: 0, y: 0)]
        )

        // Step 1: background pan by (60, 40)
        sim.run { r in
            r.touchBegan(id: 1, x: 10, y: 10)
            r.touchMoved(id: 1, x: 70, y: 50)
            r.touchEnded(id: 1, x: 70, y: 50)
        }

        // Step 2: drag the node from its shifted position
        let nodeScreen = sim.screenPos(sim.nodes[0])
        sim.run { r in
            r.touchBegan(id: 2, x: nodeScreen.x,      y: nodeScreen.y)
            r.touchMoved(id: 2, x: nodeScreen.x + 40, y: nodeScreen.y + 20)
            r.touchEnded(id: 2, x: nodeScreen.x + 40, y: nodeScreen.y + 20)
        }
        #expect(abs(sim.nodes[0].x - 40) < 0.5, "Node must move 40pt right in graph space")
        #expect(abs(sim.nodes[0].y - 20) < 0.5, "Node must move 20pt down in graph space")
        // Pan must not change further
        #expect(abs(sim.panOffset.width  - 60) < 0.5, "Pan must not change during node drag")
        #expect(abs(sim.panOffset.height - 40) < 0.5, "Pan must not change during node drag")
    }

    @Test("Node drag at zoom=2 moves node half the screen translation in graph space")
    func nodeDragAtZoom2() {
        var sim = GestureSimulator(
            nodes: [GraphNode(id: "n1", handle: "bob", isSeed: true, x: 0, y: 0)]
        )

        // Step 1: zoom to 2x
        sim.run { r in
            r.touchBegan(id: 1, x: 0,   y: 0)
            r.touchBegan(id: 2, x: 100, y: 0)
            r.touchMoved(id: 2, x: 200, y: 0)
            r.touchEnded(id: 2, x: 200, y: 0)
            r.touchEnded(id: 1, x: 0,   y: 0)
        }
        #expect(abs(sim.zoom - 2.0) < 0.01)

        // Step 2: drag node 100pt right in screen space
        let nodeScreen = sim.screenPos(sim.nodes[0])
        sim.run { r in
            r.touchBegan(id: 3, x: nodeScreen.x,       y: nodeScreen.y)
            r.touchMoved(id: 3, x: nodeScreen.x + 100, y: nodeScreen.y)
            r.touchEnded(id: 3, x: nodeScreen.x + 100, y: nodeScreen.y)
        }
        #expect(abs(sim.nodes[0].x - 50) < 0.5, "At zoom=2, 100pt screen → 50pt graph movement")
    }
}

// MARK: - Suite 3: Sequential gesture combinations (no warm-up between them)

@Suite("Combination — Sequential Gestures Don't Bleed Into Each Other")
struct SequentialGestureTests {

    let seedNode = GraphNode(id: "seed", handle: "alice", isSeed: true, x: 0, y: 0)

    @Test("Tap → node drag → tap: each gesture fires correctly in sequence")
    func tapThenDragThenTap() {
        var sim = GestureSimulator(nodes: [seedNode])

        // 1. Tap
        sim.run { r in
            r.touchBegan(id: 1, x: 200, y: 400)
            r.touchEnded(id: 1, x: 200, y: 400)
        }
        #expect(sim.tapCount == 1,        "First tap must fire")
        #expect(sim.lastTapHit == "seed", "First tap must hit node")

        // 2. Node drag
        sim.run { r in
            r.touchBegan(id: 2, x: 200, y: 400)
            r.touchMoved(id: 2, x: 250, y: 430)
            r.touchEnded(id: 2, x: 250, y: 430)
        }
        #expect(abs(sim.nodes[0].x - 50) < 0.5, "Node drag must move node right by 50pt")
        #expect(sim.tapCount == 1, "Drag must NOT fire an additional tap")

        // 3. Tap at node's new position
        let newScreen = sim.screenPos(sim.nodes[0])
        sim.run { r in
            r.touchBegan(id: 3, x: newScreen.x, y: newScreen.y)
            r.touchEnded(id: 3, x: newScreen.x, y: newScreen.y)
        }
        #expect(sim.tapCount == 2,        "Second tap must fire at new node position")
        #expect(sim.lastTapHit == "seed", "Second tap must still hit the moved node")
    }

    @Test("Background pan → tap: tap hits node at its shifted screen position")
    func panThenTap() {
        var sim = GestureSimulator(nodes: [seedNode])

        // 1. Background pan
        sim.run { r in
            r.touchBegan(id: 1, x: 10,  y: 10)
            r.touchMoved(id: 1, x: 110, y: 10)   // 100pt right
            r.touchEnded(id: 1, x: 110, y: 10)
        }
        #expect(abs(sim.panOffset.width - 100) < 0.5)

        // 2. Tap at node's new screen center
        let newScreen = sim.screenPos(sim.nodes[0])  // (300, 400)
        sim.run { r in
            r.touchBegan(id: 2, x: newScreen.x, y: newScreen.y)
            r.touchEnded(id: 2, x: newScreen.x, y: newScreen.y)
        }
        #expect(sim.tapCount  == 1,       "Tap must fire after pan")
        #expect(sim.lastTapHit == "seed", "Tap must hit node at new position after pan")
    }

    @Test("Pinch → single-finger node drag → tap: all three gestures work in order")
    func pinchThenDragThenTap() {
        var sim = GestureSimulator(nodes: [seedNode])

        // 1. Pinch to 2x
        sim.run { r in
            r.touchBegan(id: 1, x: 0,   y: 0)
            r.touchBegan(id: 2, x: 100, y: 0)
            r.touchMoved(id: 2, x: 200, y: 0)
            r.touchEnded(id: 2, x: 200, y: 0)
            r.touchEnded(id: 1, x: 0,   y: 0)
        }
        #expect(abs(sim.zoom - 2.0) < 0.01, "Zoom must be 2x after pinch")

        // 2. Single-finger drag on node
        let nodeScreen = sim.screenPos(sim.nodes[0])
        sim.run { r in
            r.touchBegan(id: 3, x: nodeScreen.x,      y: nodeScreen.y)
            r.touchMoved(id: 3, x: nodeScreen.x + 40, y: nodeScreen.y)
            r.touchEnded(id: 3, x: nodeScreen.x + 40, y: nodeScreen.y)
        }
        // At zoom=2, 40pt screen → 20pt graph
        #expect(abs(sim.nodes[0].x - 20) < 0.5, "Node must move 20pt right in graph space (zoom=2)")
        #expect(sim.tapCount == 0, "Drag must not fire tap")

        // 3. Tap at node's new screen pos
        let newScreen = sim.screenPos(sim.nodes[0])
        sim.run { r in
            r.touchBegan(id: 4, x: newScreen.x, y: newScreen.y)
            r.touchEnded(id: 4, x: newScreen.x, y: newScreen.y)
        }
        #expect(sim.tapCount  == 1,       "Tap must fire after pinch + drag")
        #expect(sim.lastTapHit == "seed", "Tap must hit node in its new position")
    }

    @Test("Node drag does NOT move viewport; background pan does NOT move node")
    func dragVsPanMutuallyExclusive() {
        var sim = GestureSimulator(
            nodes: [GraphNode(id: "n1", handle: "alice", isSeed: true, x: 0, y: 0)]
        )

        // 1. Node drag — should NOT change panOffset
        sim.run { r in
            r.touchBegan(id: 1, x: 200, y: 400)
            r.touchMoved(id: 1, x: 260, y: 440)
            r.touchEnded(id: 1, x: 260, y: 440)
        }
        #expect(abs(sim.nodes[0].x - 60) < 0.5, "Node moved right by 60pt")
        #expect(sim.panOffset.width  == 0, "Node drag must NOT change pan width")
        #expect(sim.panOffset.height == 0, "Node drag must NOT change pan height")

        // 2. Background pan — should NOT move node
        let nodeXBefore = sim.nodes[0].x
        let nodeYBefore = sim.nodes[0].y
        sim.run { r in
            r.touchBegan(id: 2, x: 10,  y: 10)
            r.touchMoved(id: 2, x: 90,  y: 70)   // 80pt right, 60pt down
            r.touchEnded(id: 2, x: 90,  y: 70)
        }
        #expect(abs(sim.panOffset.width  - 80) < 0.5, "Background pan must update pan width by 80pt")
        #expect(abs(sim.panOffset.height - 60) < 0.5, "Background pan must update pan height by 60pt")
        #expect(sim.nodes[0].x == nodeXBefore, "Background pan must NOT move node x")
        #expect(sim.nodes[0].y == nodeYBefore, "Background pan must NOT move node y")
    }
}

// MARK: - Suite 4: Full four-gesture independence check

@Suite("Combination — All Four Gestures Work Without Any Warm-Up")
struct AllFourGesturesTests {

    @Test("All four gestures — each fires correctly the first time, in isolation")
    func allFourGesturesIsolated() {
        let n = GraphNode(id: "n1", handle: "alice", isSeed: true, x: 0, y: 0)

        // Gesture 1: Tap
        var sim1 = GestureSimulator(nodes: [n])
        sim1.run { r in
            r.touchBegan(id: 1, x: 200, y: 400)
            r.touchEnded(id: 1, x: 200, y: 400)
        }
        #expect(sim1.tapCount  == 1,   "Gesture 1 (tap) must fire first-try")
        #expect(sim1.lastTapHit == "n1")

        // Gesture 2: Node drag
        var sim2 = GestureSimulator(nodes: [n])
        sim2.run { r in
            r.touchBegan(id: 1, x: 200, y: 400)
            r.touchMoved(id: 1, x: 230, y: 400)
            r.touchEnded(id: 1, x: 230, y: 400)
        }
        #expect(abs(sim2.nodes[0].x - 30) < 0.5, "Gesture 2 (node drag) must fire first-try")
        #expect(sim2.panOffset.width == 0)

        // Gesture 3: Background pan
        var sim3 = GestureSimulator(nodes: [n])
        sim3.run { r in
            r.touchBegan(id: 1, x: 10,  y: 10)
            r.touchMoved(id: 1, x: 70,  y: 40)
            r.touchEnded(id: 1, x: 70,  y: 40)
        }
        #expect(abs(sim3.panOffset.width  - 60) < 0.5, "Gesture 3 (background pan) must fire first-try")
        #expect(sim3.nodes[0].x == 0)

        // Gesture 4: Pinch zoom
        var sim4 = GestureSimulator(nodes: [n])
        sim4.run { r in
            r.touchBegan(id: 1, x: 0,   y: 0)
            r.touchBegan(id: 2, x: 100, y: 0)
            r.touchMoved(id: 2, x: 200, y: 0)
            r.touchEnded(id: 2, x: 200, y: 0)
            r.touchEnded(id: 1, x: 0,   y: 0)
        }
        #expect(abs(sim4.zoom - 2.0) < 0.01, "Gesture 4 (pinch) must fire first-try")
    }

    @Test("Full realistic session: pan → tap → drag → pinch → tap — all produce correct state")
    func realisticSession() {
        var sim = GestureSimulator(
            nodes: [GraphNode(id: "seed", handle: "alice", isSeed: true, x: 0, y: 0)]
        )

        // Step 1: pan the viewport right by 50pt
        sim.run { r in
            r.touchBegan(id: 1, x: 20,  y: 20)
            r.touchMoved(id: 1, x: 70,  y: 20)
            r.touchEnded(id: 1, x: 70,  y: 20)
        }
        #expect(abs(sim.panOffset.width - 50) < 0.5, "After pan: viewport shifted 50pt right")

        // Step 2: tap on the node (now at screen 250, 400)
        sim.run { r in
            r.touchBegan(id: 2, x: 250, y: 400)
            r.touchEnded(id: 2, x: 250, y: 400)
        }
        #expect(sim.tapCount  == 1,        "Tap must hit node after pan")
        #expect(sim.lastTapHit == "seed")

        // Step 3: drag node 40pt right (from its now-shifted screen pos 250,400)
        sim.run { r in
            r.touchBegan(id: 3, x: 250, y: 400)
            r.touchMoved(id: 3, x: 290, y: 400)
            r.touchEnded(id: 3, x: 290, y: 400)
        }
        #expect(abs(sim.nodes[0].x - 40) < 0.5, "Node drag moved node 40pt right in graph space")

        // Step 4: pinch to zoom 1.5x
        sim.run { r in
            r.touchBegan(id: 4, x: 100, y: 400)
            r.touchBegan(id: 5, x: 300, y: 400)  // dist = 200
            r.touchMoved(id: 5, x: 400, y: 400)  // dist = 300 → scale = 1.5
            r.touchEnded(id: 5, x: 400, y: 400)
            r.touchEnded(id: 4, x: 100, y: 400)
        }
        #expect(abs(sim.zoom - 1.5) < 0.05, "Zoom must be ~1.5 after pinch")

        // Step 5: tap on node again at its new screen position
        let finalScreen = sim.screenPos(sim.nodes[0])
        sim.run { r in
            r.touchBegan(id: 6, x: finalScreen.x, y: finalScreen.y)
            r.touchEnded(id: 6, x: finalScreen.x, y: finalScreen.y)
        }
        #expect(sim.tapCount  == 2,        "Second tap must fire after full interaction sequence")
        #expect(sim.lastTapHit == "seed",  "Second tap must hit node at its final position")
    }
}
