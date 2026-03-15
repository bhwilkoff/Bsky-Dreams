import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(AuthManager.self) private var auth
    @State private var posts: [PostView] = []
    @State private var isLoading = false
    @State private var actorDid: String = ""
    @State private var searchActor = ""
    @State private var sortBy: SortOption = .likes

    enum SortOption: String, CaseIterable {
        case likes = "Likes"
        case reposts = "Reposts"
        case replies = "Replies"
    }

    var sortedPosts: [PostView] {
        posts.sorted {
            switch sortBy {
            case .likes: ($0.likeCount ?? 0) > ($1.likeCount ?? 0)
            case .reposts: ($0.repostCount ?? 0) > ($1.repostCount ?? 0)
            case .replies: ($0.replyCount ?? 0) > ($1.replyCount ?? 0)
            }
        }
    }

    var chartData: [(String, Int, Int)] {
        Array(sortedPosts.prefix(25).enumerated().map { i, post -> (String, Int, Int) in
            let label = String(post.record.text.prefix(20))
            return (label, post.likeCount ?? 0, post.repostCount ?? 0)
        }.reversed())
    }

    var heatmapData: [HeatmapEntry] {
        let calendar = Calendar.current
        let now = Date()
        var counts: [Date: Int] = [:]

        for post in posts {
            if let date = ISO8601DateFormatter().date(from: post.indexedAt) {
                let day = calendar.startOfDay(for: date)
                counts[day, default: 0] += 1
            }
        }

        // Last 84 days (12 weeks)
        return (0..<84).compactMap { offset -> HeatmapEntry? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let day = calendar.startOfDay(for: date)
            return HeatmapEntry(date: day, count: counts[day] ?? 0)
        }.reversed()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Actor selector
                    actorSelector

                    if isLoading {
                        ProgressView("Analyzing posts...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if !posts.isEmpty {
                        // Engagement chart
                        engagementChart

                        // Heatmap
                        postFrequencyHeatmap

                        // Top posts table
                        topPostsTable
                    }
                }
                .padding(16)
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if let did = auth.session?.did {
                actorDid = did
                await load(did: did)
            }
        }
    }

    private var actorSelector: some View {
        HStack {
            NBTextField(placeholder: "handle.bsky.social", text: $searchActor, label: "View Actor")
                .textInputAutocapitalization(.never)

            Button("Load") {
                Task { await load(handle: searchActor) }
            }
            .disabled(searchActor.isEmpty)
            .buttonStyle(NeubrutalistButtonStyle())
        }
    }

    private var engagementChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ENGAGEMENT — LAST 25 POSTS")
                .font(.syne(12, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.nbBlack.opacity(0.6))

            Chart {
                ForEach(Array(chartData.enumerated()), id: \.offset) { i, item in
                    BarMark(
                        x: .value("Post", i),
                        y: .value("Likes", item.1)
                    )
                    .foregroundStyle(Color.nbAccent)

                    BarMark(
                        x: .value("Post", i),
                        y: .value("Reposts", item.2)
                    )
                    .foregroundStyle(Color.nbLime)
                }
            }
            .frame(height: 200)
            .chartXAxis(.hidden)

            HStack(spacing: 16) {
                Label("Likes", systemImage: "square.fill").foregroundStyle(Color.nbAccent)
                Label("Reposts", systemImage: "square.fill").foregroundStyle(Color.nbLime)
            }
            .font(.inter(12))
        }
        .padding(12)
        .background(Color.nbWhite)
        .nbBorder()
        .nbShadow()
    }

    private var postFrequencyHeatmap: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("POST FREQUENCY — 12 WEEKS")
                .font(.syne(12, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.nbBlack.opacity(0.6))

            let weeks = stride(from: 0, to: heatmapData.count, by: 7).map {
                Array(heatmapData[$0..<min($0 + 7, heatmapData.count)])
            }
            let maxCount = heatmapData.map(\.count).max() ?? 1

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 3) {
                            ForEach(week) { entry in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cellColor(count: entry.count, max: maxCount))
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.nbWhite)
        .nbBorder()
        .nbShadow()
    }

    private func cellColor(count: Int, max: Int) -> Color {
        if count == 0 { return Color.nbBorder }
        let intensity = Double(count) / Double(max)
        return Color.nbAccent.opacity(0.2 + intensity * 0.8)
    }

    private var topPostsTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TOP POSTS")
                    .font(.syne(12, weight: .bold))
                    .tracking(1)

                Spacer()

                Picker("Sort by", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .font(.inter(13))
            }
            .foregroundStyle(Color.nbBlack.opacity(0.6))

            ForEach(Array(sortedPosts.prefix(10).enumerated()), id: \.offset) { i, post in
                HStack(spacing: 12) {
                    Text("\(i + 1)")
                        .font(.syne(16, weight: .bold))
                        .foregroundStyle(Color.nbAccent)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(post.record.text)
                            .font(.inter(13))
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            Label("\(post.likeCount ?? 0)", systemImage: "heart.fill")
                                .foregroundStyle(Color.nbAccent)
                            Label("\(post.repostCount ?? 0)", systemImage: "arrow.2.squarepath")
                                .foregroundStyle(Color.nbLime)
                            Label("\(post.replyCount ?? 0)", systemImage: "bubble.left.fill")
                                .foregroundStyle(Color.nbBlue)
                        }
                        .font(.inter(11))
                    }
                }
                .padding(.vertical, 6)

                if i < 9 { Divider() }
            }
        }
        .padding(12)
        .background(Color.nbWhite)
        .nbBorder()
        .nbShadow()
    }

    private func load(did: String? = nil, handle: String? = nil) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let actor: String
            if let handle, !handle.isEmpty {
                actor = handle
            } else if let did {
                actor = did
            } else { return }

            var allPosts: [PostView] = []
            var cursor: String? = nil
            for _ in 0..<5 { // fetch up to 5 pages (~250 posts)
                let resp = try await ATProtocolClient.shared.getAuthorFeed(
                    actor: actor,
                    limit: 50,
                    cursor: cursor
                )
                allPosts.append(contentsOf: resp.feed.map { $0.post })
                cursor = resp.cursor
                if cursor == nil { break }
            }
            posts = allPosts
        } catch {}
    }
}

struct HeatmapEntry: Identifiable {
    var id: Date { date }
    let date: Date
    let count: Int
}
