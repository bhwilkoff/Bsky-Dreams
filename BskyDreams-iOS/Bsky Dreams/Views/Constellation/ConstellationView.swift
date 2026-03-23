import SwiftUI

// MARK: - Models

enum EdgeType: String {
    case reply, follow, mutual

    var edgeColor: Color {
        switch self {
        case .reply:  return Color.white.opacity(0.3)
        case .follow: return Color.nbBlue.opacity(0.5)
        case .mutual: return Color.nbBlue.opacity(0.7)
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .reply:  return 1.5
        case .follow: return 1.5
        case .mutual: return 2.5
        }
    }

    var isDashed: Bool { self == .follow }

    var linkDistance: CGFloat {
        switch self {
        case .mutual: return 80
        case .follow: return 110
        case .reply:  return 70
        }
    }

    var linkStrength: CGFloat {
        switch self {
        case .mutual: return 0.8
        case .follow: return 0.4
        case .reply:  return 0.6
        }
    }
}

struct GraphNode: Identifiable {
    let id: String
    var handle: String
    var displayName: String?
    var avatar: String?
    var weight: Int = 0
    var degree: Int = 0
    var isSeed: Bool = false
    var x: CGFloat
    var y: CGFloat
    // Velocity for momentum-based physics (like D3's velocity Verlet)
    var vx: CGFloat = 0
    var vy: CGFloat = 0

    var did: String { id }

    func radius(maxDegree: Int) -> CGFloat {
        if isSeed { return 18 }
        let base: CGFloat = 7
        let scale = sqrt(CGFloat(max(degree, 0)) / CGFloat(max(maxDegree, 1)))
        return min(base + scale * 8, 15)
    }
}

extension GraphNode: Equatable {
    static func == (lhs: GraphNode, rhs: GraphNode) -> Bool {
        lhs.id == rhs.id && lhs.x == rhs.x && lhs.y == rhs.y
    }
}

struct GraphEdge: Identifiable {
    var id: String { "\(from)|\(to)" }
    let from: String
    let to: String
    var weight: Int = 1
    var type: EdgeType = .reply
}

// MARK: - UIKit Gesture Capture
//
// Root cause: SwiftUI's _UIHostingView adds gesture recognizers with
// delaysTouchesBegan = true. This delays:
//   (a) raw UIView touchesBegan delivery to descendant views
//   (b) UIGestureRecognizer recognition on descendant views
//
// Neither UIView.touchesBegan overrides nor UIGestureRecognizer subclasses
// on a UIView are reliably immune to this delay when placed as descendants.
//
// The ONLY reliable fix: implement touch logic inside a UIGestureRecognizer
// SUBCLASS's own touchesBegan/touchesMoved/touchesEnded overrides. The gesture
// recognizer system dispatches touches to recognizer instances BEFORE applying
// delaysTouchesBegan delays to the responder chain. A recognizer's touch
// methods fire immediately, unconditionally, for every touch event — they are
// structurally immune to ancestor delaysTouchesBegan flags.
//
// This recognizer never transitions to .recognized/.began — it stays passive,
// emitting callbacks and resetting to .failed at end of each gesture sequence.
// cancelsTouchesInView = false so it never disrupts SwiftUI's own recognizers.

private final class _ConstellationGestureRecognizer: UIGestureRecognizer {

    // viewSize is view?.bounds.size — always the UIView's real laid-out size.
    // This is passed so callers never need a GeometryProxy in gesture callbacks.
    // (GeometryProxy captured in SwiftUI closures can be .zero on first render,
    //  before any @State change triggers a re-render with the correct size.)
    var onTap:         ((CGPoint, CGSize) -> Void)?   // location, viewSize
    var onPanChange:   ((CGPoint, CGSize, CGSize) -> Void)?  // start, translation, viewSize
    var onPanEnd:      ((CGPoint, CGSize) -> Void)?
    var onPinchChange: ((CGFloat) -> Void)?
    var onPinchEnd:    (() -> Void)?

    private let dragThreshold: CGFloat = 6

    // Active touch tracking: UITouch → position at touch-down (startPts)
    //                         UITouch → last known position (curPts)
    private var startPts: [UITouch: CGPoint] = [:]
    private var curPts:   [UITouch: CGPoint] = [:]

    private var didDrag        = false
    private var isPinching     = false
    private var pinchStartDist: CGFloat = 1
    private var justEndedPinch = false   // suppresses post-pinch spurious tap

    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false   // never disrupt SwiftUI's own recognizers
        delaysTouchesBegan   = false
        delaysTouchesEnded   = false
    }

    // Never prevent other recognizers; never be prevented — pure passive observer.
    override func canPrevent(_ other: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by other: UIGestureRecognizer) -> Bool { false }

    // MARK: - Touch handling (called by the recognizer system — immune to delaysTouchesBegan)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for t in touches {
            let pt = t.location(in: view)
            startPts[t] = pt
            curPts[t]   = pt
        }
        if startPts.count == 2 && !isPinching {
            isPinching     = true
            justEndedPinch = false
            // End any in-progress single-finger drag cleanly before entering pinch mode
            if didDrag, let p = firstTouch() { emitPanEnd(p); didDrag = false }
            pinchStartDist = max(pinchDist(), 1)
        }
        // 3+ simultaneous touches: ignored
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        for t in touches { curPts[t] = t.location(in: view) }

        if isPinching && startPts.count == 2 {
            onPinchChange?(max(pinchDist(), 1) / pinchStartDist)
            return
        }
        guard startPts.count == 1, let p = firstTouch() else { return }
        let s = startPts[p]!, c = curPts[p]!
        let dx = c.x - s.x, dy = c.y - s.y
        if hypot(dx, dy) >= dragThreshold {
            didDrag = true
            onPanChange?(s, CGSize(width: dx, height: dy), view?.bounds.size ?? .zero)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        for t in touches { curPts[t] = t.location(in: view) }

        if isPinching {
            for t in touches { startPts.removeValue(forKey: t); curPts.removeValue(forKey: t) }
            if startPts.count < 2 {
                isPinching = false
                onPinchEnd?()
                if !startPts.isEmpty {
                    // Reset remaining finger's start so it pans from its current position
                    for k in startPts.keys { startPts[k] = curPts[k] }
                    didDrag = false; justEndedPinch = true
                }
            }
            if startPts.isEmpty { state = .failed }
            return
        }

        guard let p = touches.first ?? firstTouch() else { state = .failed; return }
        if didDrag {
            emitPanEnd(p)
        } else if !justEndedPinch {
            onTap?(startPts[p] ?? .zero, view?.bounds.size ?? .zero)
        }
        startPts.removeValue(forKey: p); curPts.removeValue(forKey: p)
        didDrag = false; justEndedPinch = false
        if startPts.isEmpty { state = .failed }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if didDrag,   let p = firstTouch() { emitPanEnd(p) }
        if isPinching { onPinchEnd?() }
        state = .failed
    }

    override func reset() {
        super.reset()
        startPts.removeAll(); curPts.removeAll()
        didDrag = false; isPinching = false; justEndedPinch = false
    }

    // MARK: - Helpers

    private func firstTouch() -> UITouch? { startPts.keys.first }

    private func pinchDist() -> CGFloat {
        let pts = startPts.keys.compactMap { curPts[$0] }
        guard pts.count >= 2 else { return 1 }
        return hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y)
    }

    private func emitPanEnd(_ touch: UITouch) {
        guard let s = startPts[touch], let c = curPts[touch] else { return }
        onPanEnd?(s, CGSize(width: c.x - s.x, height: c.y - s.y))
    }
}

private struct ConstellationGestureCapture: UIViewRepresentable {
    var onTap:         (CGPoint, CGSize) -> Void   // location, viewSize
    var onPanChange:   (CGPoint, CGSize, CGSize) -> Void  // start, translation, viewSize
    var onPanEnd:      (CGPoint, CGSize) -> Void
    var onPinchChange: (CGFloat) -> Void
    var onPinchEnd:    () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor        = .clear
        v.isMultipleTouchEnabled = true
        let gr = _ConstellationGestureRecognizer()
        v.addGestureRecognizer(gr)
        context.coordinator.recognizer = gr
        updateRecognizer(gr)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let gr = context.coordinator.recognizer { updateRecognizer(gr) }
    }

    private func updateRecognizer(_ gr: _ConstellationGestureRecognizer) {
        gr.onTap         = onTap
        gr.onPanChange   = onPanChange
        gr.onPanEnd      = onPanEnd
        gr.onPinchChange = onPinchChange
        gr.onPinchEnd    = onPinchEnd
    }

    final class Coordinator {
        var recognizer: _ConstellationGestureRecognizer?
    }
}

// MARK: - ConstellationView

struct ConstellationView: View {
    var initialActor: String? = nil

    @Environment(AuthManager.self) private var auth

    // Graph data
    @State private var searchQuery = ""
    @State private var nodes: [GraphNode] = []
    @State private var edges: [GraphEdge] = []
    @State private var isLoading = false
    @State private var statsText = ""
    @State private var selectedNode: GraphNode? = nil
    @State private var profileToOpen: GraphNode? = nil

    // Camera (pan + zoom)
    @State private var panOffset: CGSize = .zero
    @State private var basePan:   CGSize = .zero
    @State private var zoom:      CGFloat = 1.0
    @State private var baseZoom:  CGFloat = 1.0

    // Drag state
    @State private var fixedNodeId:      String?  = nil
    @State private var nodeDragStartPos: CGPoint  = .zero
    @State private var dragTargetNodeId: String?  = nil
    @State private var dragRoutingDone:  Bool     = false

    // Continuous physics simulation
    @State private var simAlpha:    CGFloat = 0.0
    @State private var isSimulating = false
    @State private var simTask: Task<Void, Never>? = nil

    private var maxDeg: Int { nodes.map(\.degree).max() ?? 1 }

    private var alwaysVisibleLabels: Set<String> {
        var set = Set(nodes.filter(\.isSeed).map(\.id))
        set.formUnion(nodes.sorted { $0.degree > $1.degree }.prefix(5).map(\.id))
        return set
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if !statsText.isEmpty { statsBar }
            if isLoading {
                ProgressView("Building network graph...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if nodes.isEmpty {
                ContentUnavailableView(
                    "No Network Data",
                    systemImage: "network",
                    description: Text("Search for a topic or @handle to explore their network")
                )
            } else {
                graphCanvas
            }
        }
        .nbNavBar(title: "CONSTELLATION", leading: {
            if initialActor != nil { NBBackButton() } else { NBHamburger() }
        })
        // Constellation is always a dark-canvas view — white graph edges, node labels, and
        // overlays require a dark background. Forcing dark ensures all design tokens resolve
        // to their dark-mode values and white colors remain legible on the graph.
        .preferredColorScheme(.dark)
        .sheet(item: $profileToOpen) { node in
            NavigationStack { ProfileView(actor: node.did) }
        }
        .task {
            if let actor = initialActor {
                searchQuery = "@\(actor)"
                await buildGraph()
            } else if searchQuery.isEmpty, let handle = auth.session?.handle {
                searchQuery = "@\(handle)"
                await buildGraph()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.nbTextTertiary)
                TextField("Search topic or @handle...", text: $searchQuery)
                    .font(.inter(15))
                    .submitLabel(.search)
                    .onSubmit { Task { await buildGraph() } }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.nbWhite)
            .nbBorder()
        }
        .padding(12)
        .background(Color.nbWhite)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.nbBlack).frame(height: 2)
        }
    }

    private var statsBar: some View {
        Text(statsText)
            .font(.syne(11, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(Color.nbTextSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.nbWhite)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.nbBorder).frame(height: 1)
            }
    }

    // MARK: - Graph Canvas

    private var graphCanvas: some View {
        GeometryReader { geo in
            ZStack {
                Color.nbBackground.ignoresSafeArea()

                // (gesture capture is the frontmost ZStack layer below)

                // Edges rendered via Canvas (GPU-accelerated, no per-edge views)
                let nodeSnap = nodes
                Canvas { context, size in
                    let cx = size.width  / 2 + panOffset.width
                    let cy = size.height / 2 + panOffset.height
                    let s  = zoom

                    for edge in edges {
                        guard
                            let from = nodeSnap.first(where: { $0.id == edge.from }),
                            let to   = nodeSnap.first(where: { $0.id == edge.to })
                        else { continue }

                        let dimmed = selectedNode != nil
                            && edge.from != selectedNode?.id
                            && edge.to   != selectedNode?.id

                        var path = Path()
                        path.move(to:    CGPoint(x: cx + from.x * s, y: cy + from.y * s))
                        path.addLine(to: CGPoint(x: cx + to.x   * s, y: cy + to.y   * s))

                        let color = dimmed ? Color.white.opacity(0.04) : edge.type.edgeColor
                        let dash: [CGFloat] = edge.type.isDashed ? [4, 3] : []
                        context.stroke(
                            path,
                            with: .color(color),
                            style: StrokeStyle(lineWidth: edge.type.lineWidth, dash: dash)
                        )
                    }
                }
                .allowsHitTesting(false)    // touches fall through to the background layer

                // Nodes — each positioned by their graph coordinates
                let alwaysVisible = alwaysVisibleLabels
                let md = maxDeg
                ForEach(nodes) { node in
                    let isSelected  = selectedNode?.id == node.id
                    let isConnected = edges.contains {
                        ($0.from == node.id && $0.to   == selectedNode?.id) ||
                        ($0.to   == node.id && $0.from == selectedNode?.id)
                    }
                    let dimmed    = selectedNode != nil && !isSelected && !isConnected
                    let showLabel = alwaysVisible.contains(node.id) || isSelected

                    ConstellationNodeView(
                        node: node,
                        isSelected: isSelected,
                        showLabel: showLabel,
                        maxDegree: md
                    )
                    .opacity(dimmed ? 0.15 : 1.0)
                    .scaleEffect(zoom)
                    .position(screenPos(node, geo))
                    .allowsHitTesting(false)
                }

                // ── UIKit gesture capture (frontmost layer) ──────────────────────
                // UIPanGestureRecognizer fires the instant the finger moves — no
                // arbiter delay. UIPinchGestureRecognizer runs simultaneously via
                // shouldRecognizeSimultaneouslyWith. Both are on the same UIView so
                // UIKit itself arbitrates cleanly with no SwiftUI involvement.
                ConstellationGestureCapture(
                    onTap: { tapLoc, viewSize in
                        if let hit = hitNode(tapLoc, viewSize) {
                            let fresh = nodes.first(where: { $0.id == hit.id })
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedNode = (selectedNode?.id == hit.id) ? nil : fresh
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedNode = nil }
                        }
                    },
                    onPanChange: { startLoc, translation, viewSize in
                        let dist = hypot(translation.width, translation.height)

                        // First significant movement: decide node drag vs background pan
                        if !dragRoutingDone && dist > 6 {
                            dragRoutingDone = true
                            if let hit = hitNode(startLoc, viewSize) {
                                dragTargetNodeId = hit.id
                                nodeDragStartPos = CGPoint(x: hit.x, y: hit.y)
                                fixedNodeId      = hit.id
                                if let idx = nodes.firstIndex(where: { $0.id == hit.id }) {
                                    nodes[idx].vx = 0
                                    nodes[idx].vy = 0
                                }
                                kickSim(alpha: 0.7)
                            }
                        }

                        if let nodeId = dragTargetNodeId {
                            if let idx = nodes.firstIndex(where: { $0.id == nodeId }) {
                                nodes[idx].x  = nodeDragStartPos.x + translation.width  / zoom
                                nodes[idx].y  = nodeDragStartPos.y + translation.height / zoom
                                nodes[idx].vx = 0
                                nodes[idx].vy = 0
                            }
                        } else if dist > 6 {
                            panOffset = CGSize(
                                width:  basePan.width  + translation.width,
                                height: basePan.height + translation.height
                            )
                        }
                    },
                    onPanEnd: { _, _ in
                        // Tap detection is handled by onTap (UITapGestureRecognizer).
                        // onPanEnd only needs to finalize drag/pan state.
                        if dragTargetNodeId != nil {
                            fixedNodeId = nil
                            kickSim(alpha: 0.4)
                        } else {
                            basePan = panOffset
                        }

                        dragTargetNodeId = nil
                        dragRoutingDone  = false
                    },
                    onPinchChange: { scale in
                        zoom = max(0.3, min(4.0, baseZoom * scale))
                    },
                    onPinchEnd: {
                        baseZoom = zoom
                    }
                )
                // ↑ Must fill the entire ZStack so hitTest covers all touch positions.
                // Without this, UIViewRepresentable defaults to zero intrinsic size and
                // bounds.contains(point) returns false for all touches on first render.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .clipped()
        }
        .overlay(alignment: .bottomTrailing) { graphControls }
        .overlay(alignment: .bottom) {
            if let node = selectedNode {
                SelectedNodePanel(
                    node: node,
                    onDismiss:     { withAnimation { selectedNode = nil } },
                    onViewProfile: { profileToOpen = node },
                    onExplore: { handle in
                        withAnimation { selectedNode = nil }
                        searchQuery = "@\(handle)"
                        Task { await buildGraph() }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var graphControls: some View {
        VStack(spacing: 8) {
            Text("\(nodes.count) nodes · \(edges.count) edges")
                .font(.inter(11))
                .foregroundStyle(.white.opacity(0.6))
            Button("Reset View") {
                withAnimation(.spring(duration: 0.4)) {
                    panOffset = .zero
                    basePan   = .zero
                    zoom      = 1.0
                    baseZoom  = 1.0
                    selectedNode = nil
                }
            }
            .font(.inter(12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.nbAccent.opacity(0.8))
            .nbBorder()
        }
        .padding(12)
        .padding(.bottom, selectedNode != nil ? 140 : 20)
        .animation(.easeInOut(duration: 0.2), value: selectedNode != nil)
    }

    // MARK: - Coordinate helpers

    private func screenPos(_ node: GraphNode, _ geo: GeometryProxy) -> CGPoint {
        CGPoint(
            x: geo.size.width  / 2 + node.x * zoom + panOffset.width,
            y: geo.size.height / 2 + node.y * zoom + panOffset.height
        )
    }

    private func graphCoord(_ screen: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(
            x: (screen.x - size.width  / 2 - panOffset.width)  / zoom,
            y: (screen.y - size.height / 2 - panOffset.height) / zoom
        )
    }

    /// Returns the node whose circle contains `screenPt`, or nil.
    /// size must be the UIView's actual bounds.size — never a GeometryProxy
    /// captured in a SwiftUI closure, which may be .zero on first render.
    private func hitNode(_ screenPt: CGPoint, _ size: CGSize) -> GraphNode? {
        let gp = graphCoord(screenPt, size)
        let md = maxDeg
        return nodes.first { node in
            let r = node.radius(maxDegree: md) + 10  // generous touch target
            return hypot(node.x - gp.x, node.y - gp.y) < r
        }
    }

    // MARK: - Continuous physics simulation

    /// Re-energise the simulation. Safe to call even while already running.
    private func kickSim(alpha: CGFloat = 1.0) {
        simAlpha = max(simAlpha, alpha)
        guard !isSimulating else { return }   // already running — alpha bump is enough
        isSimulating = true
        simTask = Task { await runSim() }
    }

    private func runSim() async {
        // Only clear isSimulating if we weren't cancelled (a new sim may have taken over)
        defer { if !Task.isCancelled { isSimulating = false } }

        // Alpha decay matching D3 defaults: 0.0228 ≈ 1 - 0.94^(1/tick)
        // At 60 fps: 0.94^85 ≈ 0.005 → ~1.4 s to settle from alpha=1
        let alphaDecay: CGFloat = 0.94
        let friction:   CGFloat = 0.85      // velocity damping each tick
        let minAlpha:   CGFloat = 0.005

        while simAlpha > minAlpha && !Task.isCancelled {
            let md      = maxDeg
            let alpha   = simAlpha
            let fixedId = fixedNodeId
            let edgeSnap = edges

            var updates: [(id: String, x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat)] = []

            for node in nodes {
                if node.id == fixedId { continue }  // pinned node follows the finger, not physics

                var fx: CGFloat = 0
                var fy: CGFloat = 0
                let repulsion: CGFloat = node.isSeed ? 400 : 180

                // Repulsion (many-body charge)
                for other in nodes where other.id != node.id {
                    let dx = node.x - other.x
                    let dy = node.y - other.y
                    let dist = max(hypot(dx, dy), 1)
                    let f = repulsion / (dist * dist)
                    fx += (dx / dist) * f
                    fy += (dy / dist) * f
                }

                // Spring (link force) — distance and strength vary by edge type
                for edge in edgeSnap where edge.from == node.id || edge.to == node.id {
                    let otherId = edge.from == node.id ? edge.to : edge.from
                    if let other = nodes.first(where: { $0.id == otherId }) {
                        let dx  = other.x - node.x
                        let dy  = other.y - node.y
                        let dist = max(hypot(dx, dy), 1)
                        let displacement = dist - edge.type.linkDistance
                        let k = edge.type.linkStrength * 0.01
                        fx += (dx / dist) * displacement * k
                        fy += (dy / dist) * displacement * k
                    }
                }

                // Gravity toward center
                fx -= node.x * 0.02
                fy -= node.y * 0.02

                // Collision avoidance
                let r = node.radius(maxDegree: md)
                for other in nodes where other.id != node.id {
                    let dx   = node.x - other.x
                    let dy   = node.y - other.y
                    let dist = max(hypot(dx, dy), 0.1)
                    let minD = r + other.radius(maxDegree: md) + 6
                    if dist < minD {
                        let push = (minD - dist) * 0.5
                        fx += (dx / dist) * push
                        fy += (dy / dist) * push
                    }
                }

                // Velocity Verlet integration with alpha cooling + friction
                let newVx = (node.vx + fx * alpha) * friction
                let newVy = (node.vy + fy * alpha) * friction
                updates.append((node.id, node.x + newVx, node.y + newVy, newVx, newVy))
            }

            // Apply all position updates in one pass
            for u in updates {
                if let idx = nodes.firstIndex(where: { $0.id == u.id }) {
                    nodes[idx].x  = u.x
                    nodes[idx].y  = u.y
                    nodes[idx].vx = u.vx
                    nodes[idx].vy = u.vy
                }
            }

            simAlpha *= alphaDecay

            do {
                try await Task.sleep(nanoseconds: 16_000_000)   // ~60 fps
            } catch {
                break   // cancelled — defer will skip clearing isSimulating
            }
        }
        // defer { if !Task.isCancelled { isSimulating = false } } handles cleanup
    }

    // MARK: - Build Graph

    private func buildGraph() async {
        guard !searchQuery.isEmpty else { return }
        // Cancel any running simulation before building new graph
        simTask?.cancel()
        simTask      = nil
        simAlpha     = 0
        isSimulating = false
        isLoading    = true
        nodes        = []
        edges        = []
        statsText    = ""
        selectedNode = nil
        panOffset    = .zero
        basePan      = .zero
        zoom         = 1.0
        baseZoom     = 1.0
        fixedNodeId  = nil
        defer { isLoading = false }

        do {
            let query         = searchQuery.trimmingCharacters(in: .whitespaces)
            // Profile mode only when query explicitly starts with "@".
            // Single words and hashtag searches (e.g. "bluesky", "#ai") must use keyword mode.
            let isProfileMode = query.hasPrefix("@")
            let seedHandle    = isProfileMode ? query.replacingOccurrences(of: "@", with: "") : nil

            var nodeMap: [String: (ActorProfile, Int, Bool)] = [:]     // DID → (profile, count, isSeed)
            var edgeMap: [String: (String, String, Int, EdgeType)] = [:] // key → (from, to, weight, type)

            func addNode(_ author: ActorProfile, bonus: Int = 0, isSeed: Bool = false) {
                if nodeMap[author.did] == nil {
                    nodeMap[author.did] = (author, 0, isSeed)
                }
                let e = nodeMap[author.did]!
                nodeMap[author.did] = (e.0, e.1 + 1 + bonus, e.2 || isSeed)
            }

            func addEdge(_ didA: String, _ didB: String, type: EdgeType) {
                guard !didA.isEmpty, !didB.isEmpty, didA != didB else { return }
                let a = min(didA, didB), b = max(didA, didB)
                let key = "\(a)|\(b)"
                if var ex = edgeMap[key] {
                    ex.2 += 1
                    if type == .mutual || (type == .follow && ex.3 == .reply) { ex.3 = type }
                    edgeMap[key] = ex
                } else {
                    edgeMap[key] = (a, b, 1, type)
                }
            }

            if let seedHandle {
                // ── Profile mode: posts + follows + followers in parallel ──────────
                async let postsTask     = ATProtocolClient.shared.getAuthorFeed(actor: seedHandle, limit: 100, filter: "posts_and_replies")
                async let followsTask   = ATProtocolClient.shared.getActorFollows(actor: seedHandle, limit: 100)
                async let followersTask = ATProtocolClient.shared.getActorFollowers(actor: seedHandle, limit: 100)

                let postsResult     = try? await postsTask
                let followsResult   = try? await followsTask
                let followersResult = try? await followersTask

                var seedDid: String? = nil

                for item in (postsResult?.feed ?? []) {
                    let p = item.post
                    addNode(p.author)
                    if seedDid == nil && p.author.handle.lowercased() == seedHandle.lowercased() {
                        seedDid = p.author.did
                    }
                    if let parent = item.reply?.parent?.postView {
                        addNode(parent.author)
                        addEdge(p.author.did, parent.author.did, type: .reply)
                    } else if let uri = p.record.reply?.parent.uri {
                        let parts = uri.components(separatedBy: "/")
                        if parts.count >= 3 { addEdge(p.author.did, parts[2], type: .reply) }
                    }
                }

                let followsDids   = Set((followsResult   ?? []).map(\.did))
                let followersDids = Set((followersResult ?? []).map(\.did))
                (followsResult   ?? []).forEach { addNode($0, bonus: 1) }
                (followersResult ?? []).forEach { addNode($0, bonus: 1) }

                if seedDid == nil {
                    if let profile = try? await ATProtocolClient.shared.getProfile(actor: seedHandle) {
                        addNode(profile, bonus: 5, isSeed: true)
                        seedDid = profile.did
                    }
                } else if let did = seedDid {
                    let e = nodeMap[did]!
                    nodeMap[did] = (e.0, e.1, true)
                }

                if let did = seedDid {
                    followsDids.forEach   { addEdge(did, $0, type: followersDids.contains($0) ? .mutual : .follow) }
                    followersDids.forEach { if !followsDids.contains($0) { addEdge($0, did, type: .follow) } }
                }

            } else {
                // ── Keyword mode ──────────────────────────────────────────────────
                let result = try await ATProtocolClient.shared.searchPosts(q: query, sort: "latest", limit: 100)
                for post in result.posts {
                    addNode(post.author)
                    if let uri = post.record.reply?.parent.uri {
                        let parts = uri.components(separatedBy: "/")
                        if parts.count >= 3 { addEdge(post.author.did, parts[2], type: .reply) }
                    }
                }
            }

            guard !nodeMap.isEmpty else { return }

            // Prune weak reply edges in large graphs
            if nodeMap.count > 30 {
                edgeMap = edgeMap.filter { _, v in v.3 != .reply || v.2 >= 2 }
            }
            edgeMap = edgeMap.filter { _, v in nodeMap[v.0] != nil && nodeMap[v.1] != nil }

            // Compute degree
            var degreeMap: [String: Int] = [:]
            edgeMap.values.forEach {
                degreeMap[$0.0, default: 0] += 1
                degreeMap[$0.1, default: 0] += 1
            }

            // Score and cap at 60 nodes
            let sorted60 = nodeMap
                .sorted { scoreNode($0.key, $0.value, edgeMap, degreeMap) > scoreNode($1.key, $1.value, edgeMap, degreeMap) }
                .prefix(60)

            let keepDids = Set(sorted60.map(\.key))
            edgeMap = edgeMap.filter { _, v in keepDids.contains(v.0) && keepDids.contains(v.1) }

            var finalDeg: [String: Int] = [:]
            edgeMap.values.forEach {
                finalDeg[$0.0, default: 0] += 1
                finalDeg[$0.1, default: 0] += 1
            }

            // Circular initial placement — seed near center
            let count = sorted60.count
            let nodeList: [GraphNode] = sorted60.enumerated().map { i, entry in
                let angle  = 2 * Double.pi * Double(i) / Double(max(count, 1))
                let radius = entry.value.2 ? Double.random(in: 0...20) : 150.0 + Double.random(in: -40...40)
                return GraphNode(
                    id:          entry.key,
                    handle:      entry.value.0.handle,
                    displayName: entry.value.0.displayName,
                    avatar:      entry.value.0.avatar,
                    weight:      entry.value.1,
                    degree:      finalDeg[entry.key] ?? 0,
                    isSeed:      entry.value.2,
                    x:           radius * cos(angle),
                    y:           radius * sin(angle)
                )
            }

            let edgeList = edgeMap.values.map { GraphEdge(from: $0.0, to: $0.1, weight: $0.2, type: $0.3) }

            let replyCount  = edgeList.filter { $0.type == .reply  }.count
            let mutualCount = edgeList.filter { $0.type == .mutual }.count
            let followCount = edgeList.filter { $0.type == .follow }.count
            var parts = ["\(nodeList.count) PEOPLE"]
            if replyCount  > 0 { parts.append("\(replyCount) \(replyCount  == 1 ? "REPLY" : "REPLIES")") }
            if mutualCount > 0 { parts.append("\(mutualCount) MUTUAL\(mutualCount == 1 ? "" : "S")") }
            if followCount > 0 { parts.append("\(followCount) FOLLOW\(followCount == 1 ? "" : "S")") }

            nodes     = nodeList
            edges     = edgeList
            statsText = parts.joined(separator: " · ")

            // Kick off continuous physics — will run until settled (~1.4 s)
            kickSim(alpha: 1.0)

        } catch {}
    }

    private func scoreNode(
        _ did: String,
        _ data: (ActorProfile, Int, Bool),
        _ edgeMap: [String: (String, String, Int, EdgeType)],
        _ degreeMap: [String: Int]
    ) -> Double {
        if data.2 { return 1e9 }
        let degree  = Double(degreeMap[did] ?? 0)
        let mutuals = Double(edgeMap.values.filter { ($0.0 == did || $0.1 == did) && $0.3 == .mutual }.count)
        return mutuals * 10 + degree * 3 + Double(data.1)
    }
}

// MARK: - Selected Node Panel

private struct SelectedNodePanel: View {
    let node: GraphNode
    let onDismiss:     () -> Void
    let onViewProfile: () -> Void
    let onExplore:     (String) -> Void

    @State private var followersCount: Int? = nil
    @State private var followsCount:   Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.nbBorder)
                .frame(width: 40, height: 4)
                .padding(.vertical, 8)

            HStack(spacing: 12) {
                AvatarView(url: node.avatar, size: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.displayName ?? "@\(node.handle)")
                        .font(.syne(16, weight: .bold))
                        .foregroundStyle(Color.nbBlack)
                        .lineLimit(1)
                    Text("@\(node.handle)")
                        .font(.inter(12))
                        .foregroundStyle(Color.nbTextSecondary)
                    HStack(spacing: 12) {
                        if let n = followersCount { statLabel(n, "followers") }
                        if let n = followsCount   { statLabel(n, "following") }
                        if followersCount == nil && followsCount == nil {
                            Text("···")
                                .font(.inter(12))
                                .foregroundStyle(Color.nbTextTertiary)
                        }
                    }
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.nbTextSecondary)
                        .frame(width: 28, height: 28)
                        .overlay(Rectangle().strokeBorder(Color.nbBorder, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 8) {
                if !node.isSeed {
                    Button { onExplore(node.handle) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "network").font(.system(size: 11, weight: .semibold))
                            Text("EXPLORE").font(.syne(11, weight: .bold)).tracking(0.5)
                        }
                        .foregroundStyle(Color.nbBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.nbWhite)
                        .nbBorder()
                        .nbShadow(size: 2)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onViewProfile) {
                    HStack(spacing: 5) {
                        Image(systemName: "person").font(.system(size: 11, weight: .semibold))
                        Text("VIEW PROFILE").font(.syne(11, weight: .bold)).tracking(0.5)
                    }
                    .foregroundStyle(Color.nbWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.nbAccent)
                    .nbBorder()
                    .nbShadow(size: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color.nbWhite)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.nbBlack).frame(height: 2.5)
        }
        .task {
            if let p = try? await ATProtocolClient.shared.getProfile(actor: node.handle) {
                followersCount = p.followersCount
                followsCount   = p.followsCount
            }
        }
    }

    private func statLabel(_ n: Int, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(fmt(n)).font(.inter(12, weight: .semibold)).foregroundStyle(Color.nbBlack)
            Text(label).font(.inter(12)).foregroundStyle(Color.nbTextSecondary)
        }
    }

    private func fmt(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000) :
        n >= 1_000     ? String(format: "%.1fK", Double(n)/1_000) :
                         "\(n)"
    }
}

// MARK: - Node View

struct ConstellationNodeView: View {
    let node: GraphNode
    let isSelected: Bool
    let showLabel: Bool
    let maxDegree: Int

    private var size: CGFloat { node.radius(maxDegree: maxDegree) * 2 }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(
                        node.isSeed  ? Color.nbAccent.opacity(0.15) :
                        isSelected   ? Color.nbAccent.opacity(0.25) :
                                       Color.nbBlue.opacity(0.2)
                    )
                    .frame(width: size, height: size)

                if let avatar = node.avatar, let url = URL(string: avatar) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Color.clear }
                    .frame(width: size - 4, height: size - 4)
                    .clipShape(.circle)
                }
            }
            .overlay(
                Circle().strokeBorder(
                    isSelected  ? Color.nbLime   :
                    node.isSeed ? Color.nbAccent :
                                  Color.white.opacity(0.4),
                    lineWidth: (isSelected || node.isSeed) ? 2.5 : 1
                )
            )
            .shadow(
                color:  isSelected  ? Color.nbLime.opacity(0.8)   :
                        node.isSeed ? Color.nbAccent.opacity(0.5) : .clear,
                radius: 8
            )

            // Always reserve label height so position is stable
            Text(showLabel ? "@\(node.handle.components(separatedBy: ".").first ?? node.handle)" : " ")
                .font(.inter(9))
                .foregroundStyle(.white.opacity(showLabel ? 0.8 : 0))
                .lineLimit(1)
                .frame(maxWidth: 64)
        }
    }
}
