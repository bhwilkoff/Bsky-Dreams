import Testing
@testable import ConstellationGestureEngine

@Suite("ConstellationGestureEngine — Single-Finger Node Drag")
struct GestureEngineTests {

    // MARK: Shared helpers
    let canvas = (width: 400.0, height: 800.0)
    let zoom   = 1.0
    let pan    = (width: 0.0, height: 0.0)

    // A node sitting at graph-center (0, 0) = screen (200, 400)
    var centerNode: GraphNode { GraphNode(id: "n1", handle: "alice", x: 0, y: 0) }

    // A node offset from center: graph (50, 50) = screen (250, 450)
    var offsetNode: GraphNode { GraphNode(id: "n2", handle: "bob", x: 50, y: 50) }

    // MARK: - Hit-testing

    @Test("Touching a node returns that node")
    func hitTestReturnsNode() {
        let result = ConstellationGestureEngine.hitNode(
            at:         (x: 200, y: 400),   // screen center = graph (0,0) = centerNode position
            nodes:      [centerNode],
            canvasSize: canvas, zoom: zoom, panOffset: pan, maxDegree: 1
        )
        #expect(result?.id == "n1")
    }

    @Test("Touching empty space returns nil")
    func hitTestMissesEmptySpace() {
        let result = ConstellationGestureEngine.hitNode(
            at:         (x: 20, y: 20),     // top-left corner, far from the node
            nodes:      [centerNode],
            canvasSize: canvas, zoom: zoom, panOffset: pan, maxDegree: 1
        )
        #expect(result == nil)
    }

    @Test("Touching an offset node returns the correct node")
    func hitTestOffsetNode() {
        let result = ConstellationGestureEngine.hitNode(
            at:         (x: 250, y: 450),   // screen pos of offsetNode
            nodes:      [centerNode, offsetNode],
            canvasSize: canvas, zoom: zoom, panOffset: pan, maxDegree: 1
        )
        #expect(result?.id == "n2")
    }

    @Test("Hit-test respects zoom: at zoom=2 node appears further from screen edge")
    func hitTestRespectZoom() {
        // centerNode at graph (0,0).  At zoom=2 its screen pos is still (200,400).
        // A point 10pt to the right in screen space = graph (5, 0) — still inside radius.
        let result = ConstellationGestureEngine.hitNode(
            at:         (x: 210, y: 400),
            nodes:      [centerNode],
            canvasSize: canvas, zoom: 2.0, panOffset: pan, maxDegree: 1
        )
        #expect(result?.id == "n1")
    }

    @Test("Hit-test respects pan offset")
    func hitTestRespectsPan() {
        // Pan by (50, 50) → centerNode now at screen (250, 450)
        let pannedOffset = (width: 50.0, height: 50.0)
        let result = ConstellationGestureEngine.hitNode(
            at:         (x: 250, y: 450),
            nodes:      [centerNode],
            canvasSize: canvas, zoom: zoom, panOffset: pannedOffset, maxDegree: 1
        )
        #expect(result?.id == "n1")
    }

    // MARK: - Drag routing

    @Test("Single-finger drag ON a node routes to nodeDrag — not backgroundPan")
    func singleFingerOnNodeRoutesToNodeDrag() throws {
        let route = ConstellationGestureEngine.routeDrag(
            startPoint: (x: 200, y: 400),   // exactly on centerNode
            nodes:      [centerNode],
            canvasSize: canvas, zoom: zoom, panOffset: pan, maxDegree: 1
        )
        guard case .nodeDrag(let nodeId, _) = route else {
            Issue.record("Expected .nodeDrag but got .backgroundPan — single-finger drag broken")
            return
        }
        #expect(nodeId == "n1")
    }

    @Test("Single-finger drag on EMPTY space routes to backgroundPan")
    func singleFingerOnBackgroundRoutesPan() {
        let route = ConstellationGestureEngine.routeDrag(
            startPoint: (x: 20, y: 20),     // top-left corner, no node
            nodes:      [centerNode],
            canvasSize: canvas, zoom: zoom, panOffset: pan, maxDegree: 1
        )
        guard case .backgroundPan = route else {
            Issue.record("Expected .backgroundPan but got nodeDrag")
            return
        }
    }

    // MARK: - Node position after drag

    @Test("Dragging a node 50pt right in screen space moves it 50pt right in graph space (zoom=1)")
    func nodeDragTranslatesPosition() {
        let newPos = ConstellationGestureEngine.draggedNodePosition(
            startGraphPos: (x: 0, y: 0),
            translation:   (width: 50, height: 30),
            zoom:          1.0
        )
        #expect(newPos.x == 50)
        #expect(newPos.y == 30)
    }

    @Test("Dragging a node at zoom=2 moves it half the screen translation in graph space")
    func nodeDragRespectZoom() {
        let newPos = ConstellationGestureEngine.draggedNodePosition(
            startGraphPos: (x: 0, y: 0),
            translation:   (width: 100, height: 60),
            zoom:          2.0
        )
        #expect(newPos.x == 50)
        #expect(newPos.y == 30)
    }

    @Test("Dragging a node does NOT change panOffset")
    func nodeDragDoesNotPan() throws {
        var panOffset = (width: 0.0, height: 0.0)
        var nodes = [centerNode]
        let translation = (width: 50.0, height: 30.0)

        // Simulate the unified gesture routing
        let route = ConstellationGestureEngine.routeDrag(
            startPoint: (x: 200, y: 400),
            nodes:      nodes,
            canvasSize: canvas, zoom: zoom, panOffset: panOffset, maxDegree: 1
        )

        switch route {
        case .nodeDrag(let nodeId, let startPos):
            // Update node position
            let newPos = ConstellationGestureEngine.draggedNodePosition(
                startGraphPos: startPos, translation: translation, zoom: zoom
            )
            if let idx = nodes.firstIndex(where: { $0.id == nodeId }) {
                nodes[idx].x = newPos.x
                nodes[idx].y = newPos.y
            }
            // panOffset must NOT change
        case .backgroundPan:
            panOffset.width  += translation.width
            panOffset.height += translation.height
        }

        #expect(nodes[0].x == 50,    "Node should have moved right by 50pt")
        #expect(nodes[0].y == 30,    "Node should have moved down by 30pt")
        #expect(panOffset.width  == 0, "Pan must not change when dragging a node")
        #expect(panOffset.height == 0, "Pan must not change when dragging a node")
    }

    @Test("Background drag does NOT move any node")
    func backgroundDragDoesNotMoveNode() {
        var panOffset = (width: 0.0, height: 0.0)
        var nodes = [centerNode]
        let translation = (width: 80.0, height: 40.0)

        let route = ConstellationGestureEngine.routeDrag(
            startPoint: (x: 20, y: 20),     // empty space
            nodes:      nodes,
            canvasSize: canvas, zoom: zoom, panOffset: panOffset, maxDegree: 1
        )

        switch route {
        case .nodeDrag(let nodeId, let startPos):
            let newPos = ConstellationGestureEngine.draggedNodePosition(
                startGraphPos: startPos, translation: translation, zoom: zoom
            )
            if let idx = nodes.firstIndex(where: { $0.id == nodeId }) {
                nodes[idx].x = newPos.x
                nodes[idx].y = newPos.y
            }
        case .backgroundPan:
            panOffset.width  += translation.width
            panOffset.height += translation.height
        }

        #expect(nodes[0].x == 0,       "Node must NOT move during a background pan")
        #expect(nodes[0].y == 0,       "Node must NOT move during a background pan")
        #expect(panOffset.width  == 80, "Pan width should update during background drag")
        #expect(panOffset.height == 40, "Pan height should update during background drag")
    }
}
