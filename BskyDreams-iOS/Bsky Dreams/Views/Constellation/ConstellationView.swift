import SwiftUI

// MARK: - Models

enum EdgeType: String {
    case reply, follow, mutual

    var edgeColor: Color {
        switch self {
        case .reply:  return Color.nbBlack.opacity(0.3)
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

// Gestures are SwiftUI's own (SpatialTapGesture, DragGesture, MagnifyGesture) on the
// graph itself (2026-11-16). The old UIKit recognizer layer stopped receiving touches
// inside the native TabView / Duo columns (verified by a device UI test: 0 touches).

// MARK: - ConstellationView

struct ConstellationView: View {
    var initialActor: String? = nil

    @Environment(AuthManager.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Graph data
    @State private var searchQuery = ""
    @State private var nodes: [GraphNode] = []
    @State private var edges: [GraphEdge] = []
    @State private var isLoading = false
    @State private var statsText = ""
    @State private var errorMessage: String? = nil
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
            if let errorMessage {
                NBErrorBanner(
                    message: errorMessage,
                    retry: { Task { await buildGraph() } },
                    onDismiss: { self.errorMessage = nil }
                )
                .padding(.top, 8)
            }
            if isLoading {
                ProgressView("Building network graph...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if nodes.isEmpty {
                ContentUnavailableView(
                    "No Network Data",
                    systemImage: "network",
                    description: Text("Search a topic or an @handle to see who is talking with whom")
                )
            } else {
                graphCanvas
            }
        }
        .nbOfflineBanner()
        .nbNavBar(title: "CONSTELLATION")   // tab root: system tab bar/sidebar; pushed: system back button
        // Color scheme adapts to system setting — all graph colors use adaptive nbBlack/nbBorder
        // tokens so labels, edges, and borders remain legible in both light and dark mode.
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
                TextField("A topic or an @handle…", text: $searchQuery)
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
            let size = geo.size
            ZStack {
                Color.clear

                // Edges: one Canvas (GPU), never per-edge views.
                let nodeSnap = nodes
                let byID = Dictionary(uniqueKeysWithValues: nodeSnap.map { ($0.id, $0) })
                Canvas { context, canvasSize in
                    let cx = canvasSize.width  / 2 + panOffset.width
                    let cy = canvasSize.height / 2 + panOffset.height
                    let s  = zoom
                    for edge in edges {
                        guard let from = byID[edge.from], let to = byID[edge.to] else { continue }
                        let dimmed = selectedNode != nil
                            && edge.from != selectedNode?.id
                            && edge.to   != selectedNode?.id
                        var path = Path()
                        path.move(to:    CGPoint(x: cx + from.x * s, y: cy + from.y * s))
                        path.addLine(to: CGPoint(x: cx + to.x   * s, y: cy + to.y   * s))
                        let color = dimmed ? Color.nbBlack.opacity(0.05) : edge.type.edgeColor
                        context.stroke(path, with: .color(color),
                                       style: StrokeStyle(lineWidth: edge.type.lineWidth,
                                                          dash: edge.type.isDashed ? [4, 3] : []))
                    }
                }
                .allowsHitTesting(false)

                // People. Drawing only — touches are handled by the graph's gestures below,
                // so a node never swallows a pan. Each is an accessibility element.
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
                    ConstellationNodeView(node: node, isSelected: isSelected,
                                          showLabel: showLabel, maxDegree: md)
                        .opacity(dimmed ? 0.15 : 1.0)
                        .scaleEffect(zoom)
                        .position(screenPos(node, size))
                        .allowsHitTesting(false)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(node.isSeed ? "@\(node.handle), the center" : "@\(node.handle)")
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { select(node) }
                }
            }
            .contentShape(Rectangle())
            // Tap a person to select them; tap empty space to clear.
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        if let hit = hitNode(value.location, size) { select(hit) } else { select(nil) }
                    }
            )
            // Drag a person to move them, or drag the background to pan.
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in dragChanged(value, size: size) }
                    .onEnded { _ in dragEnded() }
            )
            // Pinch to zoom.
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in zoom = max(0.3, min(4.0, baseZoom * value.magnification)) }
                    .onEnded { _ in baseZoom = zoom }
            )
            .clipped()
        }
        .overlay(alignment: .bottomTrailing) { graphControls }
        .overlay(alignment: .bottom) {
            if let node = selectedNode {
                SelectedNodePanel(
                    node: node,
                    onDismiss: { select(nil) },
                    onViewProfile: { profileToOpen = node },
                    onExplore: { handle in
                        select(nil)
                        searchQuery = "@\(handle)"
                        Task { await buildGraph() }
                    }
                )
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Select a person (or nil to clear), with a light haptic.
    private func select(_ node: GraphNode?) {
        let fresh = node.flatMap { n in nodes.first(where: { $0.id == n.id }) }
        let next: GraphNode? = (fresh != nil && selectedNode?.id == fresh?.id) ? nil : fresh
        if node != nil { Haptics.selection() }
        if reduceMotion { selectedNode = next }
        else { withAnimation(.easeInOut(duration: 0.15)) { selectedNode = next } }
    }

    private func dragChanged(_ value: DragGesture.Value, size: CGSize) {
        // First movement decides: a person under the finger is dragged, else the graph pans.
        if !dragRoutingDone {
            dragRoutingDone = true
            if let hit = hitNode(value.startLocation, size) {
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
        if let nodeId = dragTargetNodeId, let idx = nodes.firstIndex(where: { $0.id == nodeId }) {
            nodes[idx].x  = nodeDragStartPos.x + value.translation.width  / zoom
            nodes[idx].y  = nodeDragStartPos.y + value.translation.height / zoom
            nodes[idx].vx = 0
            nodes[idx].vy = 0
        } else {
            panOffset = CGSize(width: basePan.width + value.translation.width,
                               height: basePan.height + value.translation.height)
        }
    }

    private func dragEnded() {
        if dragTargetNodeId != nil {
            fixedNodeId = nil
            kickSim(alpha: 0.4)
        } else {
            basePan = panOffset
        }
        dragTargetNodeId = nil
        dragRoutingDone  = false
    }

    private var graphControls: some View {
        // (The node/edge count already sits in the header — no second counter here.)
        VStack(spacing: 8) {
            Button("Reset View") {
                let reset = {
                    panOffset = .zero
                    basePan   = .zero
                    zoom      = 1.0
                    baseZoom  = 1.0
                    selectedNode = nil
                }
                if reduceMotion { reset() }
                else { withAnimation(.spring(duration: 0.4), reset) }
            }
            .buttonStyle(NeubrutalistButtonStyle())
        }
        .padding(12)
        .padding(.bottom, selectedNode != nil ? 140 : 20)
        .animation(.easeInOut(duration: 0.2), value: selectedNode != nil)
    }

    // MARK: - Coordinate helpers

    private func screenPos(_ node: GraphNode, _ size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width  / 2 + node.x * zoom + panOffset.width,
            y: size.height / 2 + node.y * zoom + panOffset.height
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
                // At 100pt apart, 180/d² = 0.018 vs gravity 0.02·100 = 2 — repulsion only
                // acted at touching distance, so small graphs collapsed into a ~100pt knot
                // with colliding labels (device review 2026-10-08). Rebalanced:
                let repulsion: CGFloat = node.isSeed ? 6000 : 3000

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
                fx -= node.x * 0.01
                fy -= node.y * 0.01

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
        errorMessage = nil
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

            guard !nodeMap.isEmpty else {
                errorMessage = "Nobody turned up for that one. Try another topic or handle."
                return
            }

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

        } catch {
            errorMessage = "The network map didn't come together. Check your connection and try again."
        }
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
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.nbBorder, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
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
                                  Color.nbBlack.opacity(0.3),
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
                .foregroundStyle(Color.nbBlack.opacity(showLabel ? 0.8 : 0))
                .lineLimit(1)
                .frame(maxWidth: 64)
        }
    }
}
