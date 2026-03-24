import SwiftUI
import Charts

struct AnalyticsView: View {
    /// When pushed as a navigation destination (e.g. from ProfileView), this is set
    /// to the target actor's handle so data loads immediately at init. When nil the
    /// view is the sidebar tab and loads the signed-in user by default.
    var initialActor: String? = nil

    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store

    @State private var posts: [PostView] = []
    @State private var profile: ActorProfile? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var searchActor = ""
    @State private var sortBy: SortOption = .likes

    enum SortOption: String, CaseIterable {
        case likes = "Likes"
        case reposts = "Reposts"
        case replies = "Replies"
    }

    // Flat list of (postIndex, metric, count) used for the stacked bar chart.
    // Reposts are added first so they stack on the bottom; likes stack on top —
    // matching the web app's coral-on-top / green-on-bottom visual.
    private struct ChartItem: Identifiable {
        let id = UUID()
        let postIndex: Int
        let count: Int
        let metric: String          // "Likes" or "Reposts"
    }

    // MARK: - Computed data

    // Last 25 posts oldest → newest so the bar chart reads left-to-right in time.
    private var recentPostsForChart: [PostView] { Array(posts.prefix(25).reversed()) }

    private var chartItems: [ChartItem] {
        recentPostsForChart.enumerated().flatMap { i, post in [
            ChartItem(postIndex: i, count: post.repostCount ?? 0, metric: "Reposts"),
            ChartItem(postIndex: i, count: post.likeCount  ?? 0, metric: "Likes"),
        ]}
    }

    // Pre-built [index: "Mar 5"] map consumed by the chart X-axis marks.
    private var xAxisLabels: [Int: String] {
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        return Dictionary(uniqueKeysWithValues: recentPostsForChart.enumerated().compactMap { i, post in
            // Use HeatmapBuilder's parser — handles fractional-seconds timestamps.
            guard let date = HeatmapBuilder.parseISO8601(post.indexedAt) else { return nil }
            return (i, fmt.string(from: date))
        })
    }

    // Delegates entirely to HeatmapBuilder — see HeatmapBuilder.swift for the logic.
    private var heatmapWeeks: [[HeatmapEntry?]] {
        HeatmapBuilder.build(indexedAts: posts.map { $0.indexedAt })
    }

    private var sortedPosts: [PostView] {
        posts.sorted {
            switch sortBy {
            case .likes:   ($0.likeCount   ?? 0) > ($1.likeCount   ?? 0)
            case .reposts: ($0.repostCount ?? 0) > ($1.repostCount ?? 0)
            case .replies: ($0.replyCount  ?? 0) > ($1.replyCount  ?? 0)
            }
        }
    }

    private var avgLikes: Double {
        guard !posts.isEmpty else { return 0 }
        return Double(posts.reduce(0) { $0 + ($1.likeCount ?? 0) }) / Double(posts.count)
    }
    private var avgReposts: Double {
        guard !posts.isEmpty else { return 0 }
        return Double(posts.reduce(0) { $0 + ($1.repostCount ?? 0) }) / Double(posts.count)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                actorSelectorSection

                if isLoading {
                    ProgressView("Analyzing posts…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.nbAccent)
                        Text(err)
                            .font(.inter(14))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") { Task { await loadSelf() } }
                            .nbButton()
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if posts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.nbBorder)
                        Text("Enter a handle above and tap LOAD,\nor tap MY ANALYTICS for your own stats.")
                            .font(.inter(14))
                            .foregroundStyle(Color.nbTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    if let p = profile { profileStripCard(p) }
                    engagementCard
                    heatmapCard
                    topPostsCard
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        // When pushed as a navigation destination (initialActor set), show a back button.
        // When shown as the sidebar tab (initialActor nil), show the hamburger.
        .nbNavBar(title: "ANALYTICS", leading: {
            if initialActor != nil { NBBackButton() } else { NBHamburger() }
        })
        .task {
            if let actor = initialActor {
                // Pushed from a profile page — actor is known at init, load immediately.
                searchActor = actor
                await load(actor: actor)
            } else if let actor = store.pendingAnalyticsActor {
                // Sidebar tab appeared with a pending actor set by pendingAnalyticsActor.
                store.pendingAnalyticsActor = nil
                searchActor = actor
                await load(actor: actor)
            } else {
                await loadSelf()
            }
        }
        // Safety net: fires when the sidebar tab is already visible and
        // pendingAnalyticsActor is set (e.g. user taps Analytics twice from different profiles).
        .onChange(of: store.pendingAnalyticsActor) { _, newActor in
            guard initialActor == nil, let actor = newActor else { return }
            store.pendingAnalyticsActor = nil
            searchActor = actor
            Task { await load(actor: actor) }
        }
    }

    // MARK: - Actor selector

    private var actorSelectorSection: some View {
        VStack(spacing: 8) {
            // .bottom alignment so the LOAD button sits flush with the text input,
            // not the label that sits above it.
            HStack(alignment: .bottom, spacing: 8) {
                NBTextField(
                    placeholder: "handle.bsky.social",
                    text: $searchActor,
                    label: "Handle"
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                // LOAD button — padding(.vertical, 11) matches NBTextField input field padding
                // so the button height equals the input field height, not the full label+input height.
                let canLoad = !searchActor.trimmingCharacters(in: .whitespaces).isEmpty
                Text("LOAD")
                    .font(.syne(12, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(canLoad ? Color.white : Color.nbTextTertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(canLoad ? Color.nbAccent : Color.nbWhite)
                    .overlay(Rectangle().strokeBorder(
                        Color.nbBlack.opacity(canLoad ? 1 : 0.25), lineWidth: 2))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard canLoad else { return }
                        let handle = searchActor.trimmingCharacters(in: .whitespaces)
                        Task { await load(actor: handle) }
                    }
            }

            // Quick-load own profile
            Text("MY ANALYTICS")
                .font(.syne(12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.nbBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.nbWhite)
                .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                .background(Color.nbBlack.offset(x: 3, y: 3))
                .contentShape(Rectangle())
                .onTapGesture { Task { await loadSelf() } }
        }
    }

    // MARK: - Profile strip

    private func profileStripCard(_ p: ActorProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: avatar + name/handle (full width — no competing stats)
            HStack(spacing: 12) {
                AvatarView(url: p.avatar, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name)
                        .font(.syne(17, weight: .bold))
                        .foregroundStyle(Color.nbBlack)
                        .lineLimit(2)
                    Text("@\(p.handle)")
                        .font(.inter(13))
                        .foregroundStyle(Color.nbTextSecondary)
                        .lineLimit(1)
                }
            }
            // Bottom row: stats
            HStack(spacing: 0) {
                profileStat(value: p.followersCount ?? 0, label: "FOLLOWERS")
                Spacer()
                profileStat(value: p.followsCount   ?? 0, label: "FOLLOWING")
                Spacer()
                profileStat(value: p.postsCount     ?? 0, label: "POSTS")
            }
        }
        .padding(12)
        .background(Color.nbWhite)
        .nbBorder()
        .nbShadow()
    }

    private func profileStat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(formatCount(value))
                .font(.syne(16, weight: .bold))
                .foregroundStyle(Color.nbBlack)
            Text(label)
                .font(.inter(9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.nbTextTertiary)
        }
    }

    // MARK: - Engagement chart

    private var engagementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("ENGAGEMENT — LAST 25 POSTS")

            Chart(chartItems) { item in
                BarMark(
                    x: .value("Post",  item.postIndex),
                    y: .value("Count", item.count),
                    stacking: .standard
                )
                .foregroundStyle(by: .value("Metric", item.metric))
            }
            .chartForegroundStyleScale([
                "Likes":   Color.nbAccent,
                "Reposts": Color.nbLime,
            ])
            .chartLegend(.hidden)
            .chartXAxis {
                // Show a date label every 5th bar so the axis isn't crowded
                AxisMarks(values: [0, 5, 10, 15, 20]) { value in
                    AxisGridLine().foregroundStyle(Color.nbBorder)
                    AxisValueLabel {
                        if let i = value.as(Int.self), let label = xAxisLabels[i] {
                            Text(label)
                                .font(.inter(9))
                                .foregroundStyle(Color.nbTextSecondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Color.nbBorder)
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(formatCount(v))
                                .font(.inter(9))
                                .foregroundStyle(Color.nbTextSecondary)
                        }
                    }
                }
            }
            .frame(height: 180)

            // Legend row + average stats
            HStack(spacing: 0) {
                legendDot(color: Color.nbAccent, label: "Likes")
                    .padding(.trailing, 14)
                legendDot(color: Color.nbLime,   label: "Reposts")
                Spacer()
                Text(String(format: "Avg %.1f ♥  %.1f ↻", avgLikes, avgReposts))
                    .font(.inter(11))
                    .foregroundStyle(Color.nbTextTertiary)
            }
        }
        .padding(12)
        .background(Color.nbWhite)
        .nbBorder()
        .nbShadow()
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("POST FREQUENCY — 12 WEEKS")

            // Non-scrolling grid centered within the card. 12 columns × 7 rows.
            // Cell size 16×16pt, spacing 4pt → total width ≈ 250pt, fits all iPhone widths.
            HStack(alignment: .top, spacing: 4) {
                // Day-of-week label column — M(Mon) W(Wed) F(Fri).
                // Use id: \.offset to avoid SwiftUI deduplicating the four "" entries.
                VStack(spacing: 4) {
                    ForEach(Array(["M", "", "W", "", "F", "", ""].enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.inter(8))
                            .foregroundStyle(Color.nbTextTertiary)
                            .frame(width: 10, height: 16, alignment: .trailing)
                    }
                }

                // heatmapWeeks: 12 columns × 7 rows, Mon-aligned, nil = future date
                ForEach(Array(heatmapWeeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 4) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, entry in
                            if let entry {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(heatmapCellColor(entry.count))
                                    .frame(width: 16, height: 16)
                            } else {
                                Color.clear.frame(width: 16, height: 16)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Discrete color scale legend  Less ■ ■ ■ ■ ■ More
            HStack(spacing: 5) {
                Text("Less")
                    .font(.inter(10))
                    .foregroundStyle(Color.nbTextTertiary)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapLevelColor(level))
                        .frame(width: 12, height: 12)
                }
                Text("More")
                    .font(.inter(10))
                    .foregroundStyle(Color.nbTextTertiary)
            }
        }
        .padding(12)
        .background(Color.nbWhite)
        .nbBorder()
        .nbShadow()
    }

    // 5 discrete levels matching the web app's GitHub-style green palette,
    // but mapped to the app's nbLime design token.
    private func heatmapCellColor(_ count: Int) -> Color {
        switch count {
        case 0:        return Color.nbHeatmapZero
        case 1, 2:     return Color.nbLime.opacity(0.35)
        case 3, 4:     return Color.nbLime.opacity(0.60)
        case 5, 6, 7:  return Color.nbLime.opacity(0.85)
        default:       return Color.nbLime
        }
    }

    private func heatmapLevelColor(_ level: Int) -> Color {
        switch level {
        case 0:  return Color.nbHeatmapZero
        case 1:  return Color.nbLime.opacity(0.35)
        case 2:  return Color.nbLime.opacity(0.60)
        case 3:  return Color.nbLime.opacity(0.85)
        default: return Color.nbLime
        }
    }

    // MARK: - Top posts

    private var topPostsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("TOP POSTS")
                Spacer()
                // Neubrutalist segmented toggle — white text on accent when active
                HStack(spacing: 0) {
                    ForEach(SortOption.allCases, id: \.self) { opt in
                        Text(opt.rawValue.uppercased())
                            .font(.syne(10, weight: .bold))
                            .tracking(0.3)
                            .foregroundStyle(sortBy == opt ? Color.white : Color.nbBlack)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(sortBy == opt ? Color.nbAccent : Color.nbWhite)
                            .contentShape(Rectangle())
                            .onTapGesture { sortBy = opt }
                    }
                }
                .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
            }

            ForEach(Array(sortedPosts.prefix(15).enumerated()), id: \.offset) { i, post in
                Button {
                    store.navigationPath.append(PostDestination(uri: post.uri, post: post))
                } label: {
                    HStack(spacing: 10) {
                        // Rank badge
                        Text("\(i + 1)")
                            .font(.syne(18, weight: .bold))
                            .foregroundStyle(Color.nbAccent)
                            .frame(width: 28, alignment: .center)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.record.text)
                                .font(.inter(13))
                                .foregroundStyle(Color.nbBlack)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 14) {
                                Label("\(post.likeCount ?? 0)",   systemImage: "heart.fill")
                                    .foregroundStyle(Color.nbAccent)
                                Label("\(post.repostCount ?? 0)", systemImage: "arrow.2.squarepath")
                                    .foregroundStyle(Color.nbLime)
                                Label("\(post.replyCount ?? 0)",  systemImage: "bubble.left.fill")
                                    .foregroundStyle(Color.nbBlue)
                            }
                            .font(.inter(11))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.nbBlack.opacity(0.2))
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if i < min(sortedPosts.count, 15) - 1 {
                    Divider()
                }
            }
        }
        .padding(12)
        .background(Color.nbWhite)
        .nbBorder()
        .nbShadow()
    }

    // MARK: - Data loading

    private func loadSelf() async {
        guard let did = auth.session?.did else { return }
        searchActor = ""
        await load(actor: did)
    }

    private func load(actor: String) async {
        guard !actor.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        posts = []
        profile = nil
        defer { isLoading = false }

        do {
            // Profile and first batch fetched sequentially (both @MainActor)
            profile = try await ATProtocolClient.shared.getProfile(actor: actor)

            var allPosts: [PostView] = []
            var pageCursor: String? = nil

            // Up to 5 pages × 100 posts = 500 posts maximum
            for _ in 0..<5 {
                let resp = try await ATProtocolClient.shared.getAuthorFeed(
                    actor: actor,
                    limit: 100,
                    cursor: pageCursor,
                    filter: "posts_no_replies"
                )
                // strip reposts — keep only original posts by this author
                allPosts.append(contentsOf: resp.feed.filter { $0.reason == nil }.map { $0.post })
                pageCursor = resp.cursor
                if pageCursor == nil { break }
            }

            posts = allPosts
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Shared sub-views / helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.syne(12, weight: .bold))
            .tracking(1)
            .foregroundStyle(Color.nbTextSecondary)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay(RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.nbBlack.opacity(0.25), lineWidth: 1))
            Text(label)
                .font(.inter(12))
                .foregroundStyle(Color.nbTextSecondary)
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}

// MARK: - Supporting types

struct HeatmapEntry: Identifiable {
    var id: Date { date }
    let date: Date
    let count: Int
}

// MARK: - HeatmapBuilder
//
// Standalone, testable computation of the post-frequency heatmap grid.
// Lives in this file so it is always part of the same compile unit as AnalyticsView.

struct HeatmapBuilder {

    // MARK: Public API

    /// Builds 12 columns × 7 rows of post counts aligned to calendar weeks.
    /// Row 0 = Monday, Row 6 = Sunday.  Nil entries = future dates.
    ///
    /// - Parameters:
    ///   - indexedAts: Raw ISO8601 timestamp strings from `PostView.indexedAt`.
    ///   - calendar:   Calendar to use for week arithmetic (injectable for tests).
    ///   - today:      Reference "today" date (injectable for deterministic tests).
    static func build(
        indexedAts: [String],
        calendar: Calendar = .current,
        today: Date = Date()
    ) -> [[HeatmapEntry?]] {
        let todayStart = calendar.startOfDay(for: today)

        // AT Protocol timestamps often carry fractional seconds (e.g. ".478Z").
        // The plain ISO8601DateFormatter returns nil for these — we must try
        // the fractional-seconds format first, then fall back.
        var counts: [Date: Int] = [:]
        for ts in indexedAts {
            if let date = parseISO8601(ts) {
                counts[calendar.startOfDay(for: date), default: 0] += 1
            }
        }

        // Find the Monday that started the current week.
        // Gregorian weekday: 1=Sun  2=Mon  …  7=Sat
        // daysFromMonday:     Mon=0  Tue=1  …  Sun=6
        let weekday = calendar.component(.weekday, from: todayStart)
        let daysFromMonday = (weekday == 1) ? 6 : weekday - 2
        guard
            let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday, to: todayStart),
            let startMonday = calendar.date(byAdding: .weekOfYear, value: -11, to: thisMonday)
        else { return [] }

        return (0..<12).map { week in
            (0..<7).map { day -> HeatmapEntry? in
                guard let date = calendar.date(byAdding: .day, value: week * 7 + day, to: startMonday)
                else { return nil }
                if date > todayStart { return nil }   // future — render as empty cell
                return HeatmapEntry(date: date, count: counts[date] ?? 0)
            }
        }
    }

    // MARK: Date parsing (also used by xAxisLabels in AnalyticsView)

    /// Parses an AT Protocol ISO8601 string, handling optional fractional seconds.
    static func parseISO8601(_ string: String) -> Date? {
        withFractionsFormatter.date(from: string)
            ?? plainFormatter.date(from: string)
    }

    // Static formatters — allocated once, reused on every call.
    private static let withFractionsFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plainFormatter = ISO8601DateFormatter()
}

// MARK: - HeatmapBuilder diagnostic preview
//
// Open this file in Xcode Canvas (Cmd+Option+Return) to run the test suite.
// Each row shows PASS (✓ green) or FAIL (✗ red) with the observed value.

private struct HeatmapTestResult {
    let name: String; let passed: Bool; let detail: String
}
private func heatmapCheck(_ name: String, _ passed: Bool, _ detail: String = "") -> HeatmapTestResult {
    HeatmapTestResult(name: name, passed: passed, detail: detail)
}
private func runHeatmapTests() -> [HeatmapTestResult] {
    var r: [HeatmapTestResult] = []
    let cal = Calendar.current

    // Fixed "today" = Tuesday 2025-03-18 for deterministic results
    var dc = DateComponents(); dc.year = 2025; dc.month = 3; dc.day = 18
    let fakeToday = cal.date(from: dc)!

    // T1: fractional-seconds timestamp parses
    r.append(heatmapCheck("T1 — Parse fractional-seconds timestamp",
        HeatmapBuilder.parseISO8601("2025-03-17T14:32:01.478Z") != nil))
    // T2: whole-seconds timestamp parses
    r.append(heatmapCheck("T2 — Parse whole-seconds timestamp",
        HeatmapBuilder.parseISO8601("2025-03-17T14:32:01Z") != nil))
    // T3: garbage returns nil
    r.append(heatmapCheck("T3 — Garbage string returns nil",
        HeatmapBuilder.parseISO8601("not-a-date") == nil))

    let grid = HeatmapBuilder.build(indexedAts: [], today: fakeToday)
    // T4/T5: grid dimensions
    r.append(heatmapCheck("T4 — Grid has 12 columns", grid.count == 12, "got \(grid.count)"))
    r.append(heatmapCheck("T5 — Each column has 7 rows",
        grid.allSatisfy { $0.count == 7 }, grid.map { $0.count }.description))

    // T6: post today lands in last column, row 1 (Tuesday)
    let g6 = HeatmapBuilder.build(indexedAts: ["2025-03-18T09:00:00.000Z"], today: fakeToday)
    r.append(heatmapCheck("T6 — Today's post: col 11, row 1 (Tue) count=1",
        g6[11][1]?.count == 1, "count=\(g6[11][1]?.count ?? -1)"))

    // T7: post 7 days ago lands in column 10, row 1
    let g7 = HeatmapBuilder.build(indexedAts: ["2025-03-11T09:00:00.000Z"], today: fakeToday)
    r.append(heatmapCheck("T7 — Post 7 days ago: col 10, row 1 count=1",
        g7[10][1]?.count == 1, "count=\(g7[10][1]?.count ?? -1)"))

    // T8: future date within current partial week is nil
    r.append(heatmapCheck("T8 — Wednesday of partial week is nil",
        grid[11][2] == nil, grid[11][2].map { "count=\($0.count)" } ?? "nil ✓"))

    // T9: 5 posts same day accumulate
    let g9 = HeatmapBuilder.build(
        indexedAts: Array(repeating: "2025-03-18T10:00:00.000Z", count: 5), today: fakeToday)
    r.append(heatmapCheck("T9 — 5 posts same day → count=5",
        g9[11][1]?.count == 5, "count=\(g9[11][1]?.count ?? -1)"))

    // T10: post at window start (2024-12-23 Mon = col 0, row 0)
    let g10 = HeatmapBuilder.build(indexedAts: ["2024-12-23T09:00:00Z"], today: fakeToday)
    r.append(heatmapCheck("T10 — Post at window start: col 0, row 0 count=1",
        g10[0][0]?.count == 1, "count=\(g10[0][0]?.count ?? -1)"))

    // T11: post before window start is not counted
    let g11 = HeatmapBuilder.build(indexedAts: ["2024-12-22T09:00:00Z"], today: fakeToday)
    let total11 = g11.flatMap { $0 }.compactMap { $0 }.map { $0.count }.reduce(0, +)
    r.append(heatmapCheck("T11 — Post before window start not counted",
        total11 == 0, "total=\(total11)"))

    return r
}

struct HeatmapBuilder_Previews: PreviewProvider {
    static var previews: some View {
        // Compute outside @ViewBuilder to avoid Swift 6 filter/RangeSet overload ambiguity.
        let results = runHeatmapTests()
        let passCount = results.reduce(0) { $0 + ($1.passed ? 1 : 0) }
        let allPassed = passCount == results.count
        let rows = Array(results.enumerated())   // id: \.offset avoids Range<Int> conformance issue

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("HEATMAPBUILDER TESTS")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                Spacer()
                Text("\(passCount)/\(results.count) PASSED")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(allPassed ? Color.green : Color.red)
            }
            .padding(10).background(Color.black).foregroundStyle(.white)
            ForEach(rows, id: \.offset) { i, res in
                HStack(alignment: .top, spacing: 8) {
                    Text(res.passed ? "✓" : "✗")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(res.passed ? Color.green : Color.red)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(res.name).font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(res.passed ? Color.primary : Color.red)
                        if !res.detail.isEmpty {
                            Text(res.detail).font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(i % 2 == 0 ? Color(.systemBackground) : Color(.secondarySystemBackground))
            }
        }
        .border(Color.black, width: 1)
        .previewLayout(.sizeThatFits)
    }
}
