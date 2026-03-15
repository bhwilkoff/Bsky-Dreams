import SwiftUI

// Network graph — search-seeded, native SwiftUI force-directed visualization
struct ConstellationView: View {
    @State private var searchQuery = ""
    @State private var nodes: [GraphNode] = []
    @State private var edges: [GraphEdge] = []
    @State private var isLoading = false
    @State private var selectedNode: GraphNode? = nil
    @State private var graphOffset: CGSize = .zero
    @State private var graphScale: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.nbBlack.opacity(0.4))
                        TextField("Search to seed network...", text: $searchQuery)
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

                if isLoading {
                    ProgressView("Building network graph...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if nodes.isEmpty {
                    ContentUnavailableView(
                        "No Network Data",
                        systemImage: "network",
                        description: Text("Search for a topic to explore its network of conversations")
                    )
                } else {
                    graphCanvas
                }
            }
            .navigationTitle("Network Constellation")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedNode) { node in
                ProfileView(actor: node.did)
            }
        }
    }

    private var graphCanvas: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: "#0A0A14").ignoresSafeArea()

                // Edges
                ForEach(edges) { edge in
                    if let from = nodes.first(where: { $0.id == edge.from }),
                       let to = nodes.first(where: { $0.id == edge.to }) {
                        Path { path in
                            path.move(to: CGPoint(
                                x: from.x + geo.size.width / 2 + graphOffset.width,
                                y: from.y + geo.size.height / 2 + graphOffset.height
                            ))
                            path.addLine(to: CGPoint(
                                x: to.x + geo.size.width / 2 + graphOffset.width,
                                y: to.y + geo.size.height / 2 + graphOffset.height
                            ))
                        }
                        .stroke(Color.nbBlue.opacity(0.3), lineWidth: 1)
                    }
                }

                // Nodes
                ForEach(nodes) { node in
                    ConstellationNodeView(
                        node: node,
                        isSelected: selectedNode?.id == node.id
                    )
                    .position(
                        x: node.x + geo.size.width / 2 + graphOffset.width,
                        y: node.y + geo.size.height / 2 + graphOffset.height
                    )
                    .scaleEffect(graphScale)
                    .onTapGesture {
                        if selectedNode?.id == node.id {
                            selectedNode = nil
                        } else {
                            selectedNode = node
                        }
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { val in
                        graphOffset = CGSize(
                            width: graphOffset.width + val.translation.width / 20,
                            height: graphOffset.height + val.translation.height / 20
                        )
                    }
            )
            .gesture(
                MagnifyGesture()
                    .onChanged { val in
                        graphScale = max(0.3, min(3.0, val.magnification))
                    }
            )
        }
        .overlay(alignment: .bottomTrailing) {
            graphControls
        }
    }

    private var graphControls: some View {
        VStack(spacing: 8) {
            Text("\(nodes.count) nodes")
                .font(.inter(11))
                .foregroundStyle(.white.opacity(0.6))
            Button("Reset") {
                graphOffset = .zero
                graphScale = 1.0
                selectedNode = nil
            }
            .font(.inter(12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.nbAccent.opacity(0.8))
            .nbBorder()
        }
        .padding(12)
    }

    private func buildGraph() async {
        guard !searchQuery.isEmpty else { return }
        isLoading = true
        nodes = []
        edges = []
        defer { isLoading = false }

        do {
            let result = try await ATProtocolClient.shared.searchPosts(
                q: searchQuery,
                sort: "top",
                limit: 100
            )

            // Build nodes from unique authors
            var authorCounts: [String: (ActorProfile, Int)] = [:]
            for post in result.posts {
                let did = post.author.did
                if let existing = authorCounts[did] {
                    authorCounts[did] = (existing.0, existing.1 + 1)
                } else {
                    authorCounts[did] = (post.author, 1)
                }
            }

            // Build edges from reply relationships
            var edgeSet: Set<String> = []
            for post in result.posts {
                if let replyRef = post.record.reply {
                    let parentDid = extractDID(from: replyRef.parent.uri)
                    let authorDid = post.author.did
                    if parentDid != authorDid {
                        let edgeKey = "\(min(authorDid, parentDid))-\(max(authorDid, parentDid))"
                        if !edgeSet.contains(edgeKey) {
                            edgeSet.insert(edgeKey)
                        }
                    }
                }
            }

            // Cap at 80 nodes, highest count first
            let topAuthors = authorCounts.values
                .sorted { $0.1 > $1.1 }
                .prefix(80)

            // Place in force-directed layout (simple circular + jitter start)
            let nodeList = topAuthors.enumerated().map { i, pair -> GraphNode in
                let angle = 2 * Double.pi * Double(i) / Double(topAuthors.count)
                let radius = 150.0 + Double.random(in: -50...50)
                return GraphNode(
                    did: pair.0.did,
                    handle: pair.0.handle,
                    displayName: pair.0.displayName,
                    avatar: pair.0.avatar,
                    weight: pair.1,
                    x: radius * cos(angle),
                    y: radius * sin(angle)
                )
            }

            let nodeIds = Set(nodeList.map(\.did))
            let edgeList = edgeSet.compactMap { key -> GraphEdge? in
                let parts = key.components(separatedBy: "-")
                guard parts.count == 2,
                      nodeIds.contains(parts[0]),
                      nodeIds.contains(parts[1]) else { return nil }
                return GraphEdge(from: parts[0], to: parts[1])
            }

            await MainActor.run {
                nodes = nodeList
                edges = edgeList
            }

            // Simple force simulation iterations
            await simulateForces()
        } catch {}
    }

    private func simulateForces() async {
        for _ in 0..<50 {
            var newPositions: [(String, CGFloat, CGFloat)] = []

            for node in nodes {
                var fx: CGFloat = 0, fy: CGFloat = 0

                // Repulsion from other nodes
                for other in nodes where other.id != node.id {
                    let dx = node.x - other.x
                    let dy = node.y - other.y
                    let dist = max(sqrt(dx*dx + dy*dy), 1)
                    let force = 2000 / (dist * dist)
                    fx += (dx / dist) * force
                    fy += (dy / dist) * force
                }

                // Attraction along edges
                for edge in edges where edge.from == node.id || edge.to == node.id {
                    let otherId = edge.from == node.id ? edge.to : edge.from
                    if let other = nodes.first(where: { $0.id == otherId }) {
                        let dx = other.x - node.x
                        let dy = other.y - node.y
                        fx += dx * 0.01
                        fy += dy * 0.01
                    }
                }

                // Center gravity
                fx -= node.x * 0.02
                fy -= node.y * 0.02

                newPositions.append((node.id, node.x + fx * 0.1, node.y + fy * 0.1))
            }

            let positions = newPositions
            await MainActor.run {
                for (id, x, y) in positions {
                    if let idx = nodes.firstIndex(where: { $0.id == id }) {
                        nodes[idx].x = x
                        nodes[idx].y = y
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps
        }
    }

    private func extractDID(from uri: String) -> String {
        // at://did:plc:xxx/app.bsky.feed.post/rkey
        let parts = uri.components(separatedBy: "/")
        return parts.count >= 3 ? parts[2] : ""
    }
}

// MARK: - Graph Models

struct GraphNode: Identifiable {
    let id: String
    var did: String { id }
    let handle: String
    let displayName: String?
    let avatar: String?
    let weight: Int
    var x: CGFloat
    var y: CGFloat
}

struct GraphEdge: Identifiable {
    var id: String { "\(from)-\(to)" }
    let from: String
    let to: String
}

// MARK: - Node View

struct ConstellationNodeView: View {
    let node: GraphNode
    let isSelected: Bool

    var size: CGFloat { min(CGFloat(node.weight) * 4 + 16, 44) }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.nbAccent : Color.nbBlue.opacity(0.8))
                    .frame(width: size, height: size)

                if let avatar = node.avatar, let url = URL(string: avatar) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Color.clear }
                    .frame(width: size - 4, height: size - 4)
                    .clipShape(.circle)
                }
            }
            .shadow(color: isSelected ? Color.nbAccent : Color.nbBlue, radius: isSelected ? 8 : 4)

            Text(node.handle)
                .font(.inter(9))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .frame(maxWidth: 60)
        }
    }
}
