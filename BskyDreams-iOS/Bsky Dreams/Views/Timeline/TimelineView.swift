import SwiftUI
import SwiftData

// MARK: - Zoom Level Configuration

struct TLZoomLevel {
    let seconds: TimeInterval
    let label: String
    let minEngagement: Int
}

let kTLZoomLevels: [TLZoomLevel] = [
    TLZoomLevel(seconds: 7 * 86400, label: "7d",  minEngagement: 50),
    TLZoomLevel(seconds: 3 * 86400, label: "3d",  minEngagement: 25),
    TLZoomLevel(seconds: 1 * 86400, label: "1d",  minEngagement: 10),
    TLZoomLevel(seconds: 12 * 3600, label: "12h", minEngagement: 5),
    TLZoomLevel(seconds: 4 * 3600,  label: "4h",  minEngagement: 2),
    TLZoomLevel(seconds: 3600,      label: "1h",  minEngagement: 0),
    TLZoomLevel(seconds: 20 * 60,   label: "20m", minEngagement: 0),
]

// MARK: - Card Layout Model

struct TLPositionedCard: Identifiable {
    let id: String          // post.uri — unique per post
    let post: PostView
    let left: CGFloat       // card's top-left x in canvas coordinates
    let top: CGFloat        // card's top-left y in canvas coordinates
    let axisX: CGFloat      // x of the dot on the time axis
    let isAbove: Bool
}

// MARK: - ISO8601 Date Parsers

private let tlISO8601Fractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private let tlISO8601: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

func tlParseDate(_ str: String) -> Date {
    tlISO8601Fractional.date(from: str) ?? tlISO8601.date(from: str) ?? Date()
}

// MARK: - TimelineView

struct TimelineScrubberView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedSearch.createdAt) private var savedSearches: [SavedSearch]

    @State private var query: String = ""
    @State private var zoomIndex: Int = 2          // default "1d"
    @State private var windowEnd: Date = .now
    @State private var windowStart: Date = .now.addingTimeInterval(-86400)
    @State private var showDatePickers: Bool = false
    @State private var startDate: Date = .now.addingTimeInterval(-86400)
    @State private var endDate: Date = .now
    @State private var allPosts: [PostView] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSaveAlert: Bool = false
    @State private var channelName: String = ""

    private var currentZoom: TLZoomLevel { kTLZoomLevels[zoomIndex] }
    private var windowSpan: TimeInterval { windowEnd.timeIntervalSince(windowStart) }

    var body: some View {
        VStack(spacing: 0) {
            controlsBar

            ZStack {
                Color.nbWhite.ignoresSafeArea()
                contentArea
            }
        }
        .nbNavBar(title: "TIMELINE", leading: { NBHamburger() })
        .alert("Save as Channel", isPresented: $showSaveAlert) {
            TextField("Channel name", text: $channelName)
            Button("Save") { persistChannel() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give this timeline search a name to save it as a channel.")
        }
        .onAppear {
            if let pending = store.pendingTimelineQuery {
                query = pending
                store.pendingTimelineQuery = nil
                Task { await doSearch() }
            } else if query.isEmpty, let handle = auth.session?.handle {
                // Auto-load the current user's profile timeline on first open
                query = "@\(handle)"
                Task { await doSearch() }
            }
        }
        .onChange(of: store.pendingTimelineQuery) { _, newVal in
            guard let q = newVal else { return }
            query = q
            store.pendingTimelineQuery = nil
            Task { await doSearch() }
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            loadingView
        } else if let err = errorMessage {
            errorView(err)
        } else if !allPosts.isEmpty {
            GeometryReader { geo in
                timelineCanvas(viewportWidth: geo.size.width,
                               viewportHeight: geo.size.height)
            }
        } else if !query.isEmpty {
            emptyView
        } else {
            placeholderView
        }
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        VStack(spacing: 0) {
            // Row 1: search input
            HStack(spacing: 6) {
                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "calendar.day.timeline.leading")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.nbTextTertiary)

                    TextField("@handle, #tag, or keywords…", text: $query)
                        .font(.inter(14))
                        .foregroundStyle(Color.nbBlack)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .submitLabel(.go)
                        .onSubmit { Task { await doSearch() } }

                    if !query.isEmpty {
                        Button {
                            query = ""
                            allPosts = []
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.nbTextTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(Color.nbWhite)
                .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))

                // GO button
                Button { Task { await doSearch() } } label: {
                    Text("GO")
                        .font(.syne(12, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(query.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.nbTextTertiary
                                    : Color.nbAccent)
                        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)

                // Save-as-channel bookmark
                Button {
                    channelName = query.trimmingCharacters(in: .whitespaces)
                    showSaveAlert = true
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 14))
                        .foregroundStyle(query.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? Color.nbBlack.opacity(0.25)
                                         : Color.nbBlack)
                        .frame(width: 38, height: 38)
                        .background(Color.nbWhite)
                        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Save as channel")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider().background(Color.nbBorder)

            // Row 2: zoom controls + date range
            HStack(spacing: 8) {
                // Zoom out
                zoomBtn("−") {
                    guard zoomIndex > 0 else { return }
                    Haptics.selection()
                    zoomIndex -= 1
                    applyZoom()
                }
                .accessibilityLabel("Zoom out")

                // Zoom label
                Text(currentZoom.label)
                    .font(.syne(13, weight: .bold))
                    .foregroundStyle(Color.nbBlack)
                    .frame(minWidth: 40)
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(Color.nbWhite)
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))

                // Zoom in
                zoomBtn("+") {
                    guard zoomIndex < kTLZoomLevels.count - 1 else { return }
                    Haptics.selection()
                    zoomIndex += 1
                    applyZoom()
                }
                .accessibilityLabel("Zoom in")

                Spacer()

                // Date range toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showDatePickers.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(dateRangeLabel)
                            .font(.inter(10))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.nbBlack)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(showDatePickers ? Color.nbBlack.opacity(0.07) : Color.nbWhite)
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Collapsible date pickers
            if showDatePickers {
                Divider().background(Color.nbBorder)
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FROM")
                            .font(.syne(9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.nbTextTertiary)
                        DatePicker("", selection: $startDate,
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .onChange(of: startDate) { _, _ in applyCustomRange() }
                    }
                    Text("→")
                        .font(.inter(14))
                        .foregroundStyle(Color.nbTextTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TO")
                            .font(.syne(9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(Color.nbTextTertiary)
                        DatePicker("", selection: $endDate,
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .onChange(of: endDate) { _, _ in applyCustomRange() }
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider().background(Color.nbBlack)
        }
        .background(Color.nbWhite)
    }

    private func zoomBtn(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.nbBlack)
                .frame(width: 32, height: 32)
                .background(Color.nbWhite)
                .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var dateRangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = windowSpan < 86400 ? "MM/dd HH:mm" : "MM/dd"
        return "\(fmt.string(from: windowStart)) → \(fmt.string(from: windowEnd))"
    }

    // MARK: - Loading / Empty States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.nbAccent)
                .scaleEffect(1.2)
            Text("Loading timeline…")
                .font(.inter(14))
                .foregroundStyle(Color.nbTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.nbAccent)
            Text(message)
                .font(.inter(13))
                .foregroundStyle(Color.nbTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        NBEmptyState(
            icon: "chart.xyaxis.line",
            title: "NO POSTS FOUND",
            message: "Try zooming out or widening the date range."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderView: some View {
        VStack(spacing: 20) {
            ZStack {
                DiagonalStripeBackground()
                    .opacity(0.5)
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(Color.nbAccent.opacity(0.6))
            }
            .frame(width: 110, height: 110)
            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
            .background(Color.nbBlack.offset(x: 3, y: 3))

            VStack(spacing: 8) {
                Text("TIMELINE")
                    .font(.syne(20, weight: .bold))
                    .foregroundStyle(Color.nbBlack)
                Text("Search for @handles, #tags, or keywords\nto see posts plotted across time.")
                    .font(.inter(14))
                    .foregroundStyle(Color.nbTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Timeline Canvas

    @ViewBuilder
    private func timelineCanvas(viewportWidth vw: CGFloat, viewportHeight vh: CGFloat) -> some View {
        let canvasW = max(vw * 3, 900)
        let canvasH = max(300, vh)
        let cards = buildLayout(canvasW: canvasW, canvasH: canvasH)

        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // SVG-equivalent: axis line, tick marks, labels, connector lines, dots
                    TLAxisCanvas(
                        cards: cards,
                        windowStart: windowStart,
                        windowSpan: windowSpan,
                        canvasW: canvasW,
                        canvasH: canvasH
                    )
                    .frame(width: canvasW, height: canvasH)

                    // Post cards — absolutely positioned over the canvas
                    ForEach(cards) { card in
                        TLPostCard(post: card.post)
                            .frame(width: 158, height: 72)
                            .offset(x: card.left, y: card.top)
                            .onTapGesture {
                                store.navigationPath.append(
                                    PostDestination(uri: card.post.uri, post: card.post)
                                )
                            }
                    }

                    // Invisible center anchor — uses .position() (not .offset()) so
                    // ScrollViewReader can find the actual layout position.
                    Color.clear
                        .frame(width: 1, height: 1)
                        .position(x: canvasW / 2, y: canvasH / 2)
                        .id("tl-center")
                }
                .frame(width: canvasW, height: canvasH)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    proxy.scrollTo("tl-center", anchor: .center)
                }
            }
            .onChange(of: allPosts.count) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    proxy.scrollTo("tl-center", anchor: .center)
                }
            }
        }
    }

    // MARK: - Lane Layout Algorithm

    private func buildLayout(canvasW: CGFloat, canvasH: CGFloat) -> [TLPositionedCard] {
        guard !allPosts.isEmpty else { return [] }

        let CARD_W: CGFloat  = 158
        let CARD_H: CGFloat  = 72
        let LANE_H: CGFloat  = 76    // CARD_H + 4pt breathing room
        let GAP_AXIS: CGFloat = 10   // gap from axis line to nearest card edge
        let TICK_H: CGFloat  = 26    // space reserved below axis for tick labels
        let CARD_GAP: CGFloat = 6    // minimum horizontal gap between adjacent cards

        let axY = canvasH / 2
        let maxLanesAbove = max(1, Int(floor((axY - GAP_AXIS) / LANE_H)))
        let maxLanesBelow = max(1, Int(floor((canvasH - axY - TICK_H) / LANE_H)))

        let pxPerSec = canvasW / CGFloat(windowSpan)
        let wStart = windowStart.timeIntervalSince1970

        // Filter by engagement threshold for this zoom level
        let minEng = currentZoom.minEngagement
        let byEngagement = allPosts.sorted { engScore($0) > engScore($1) }
        let filtered = byEngagement.filter { engScore($0) >= minEng }
        // If nothing passes the threshold, show all posts (rare edge case)
        let toLayout = (filtered.isEmpty ? byEngagement : filtered)
            .sorted { tlParseDate($0.record.createdAt) < tlParseDate($1.record.createdAt) }

        // Track the rightmost card right-edge per lane to detect collisions
        var laneAboveEnd = [CGFloat](repeating: -CARD_W, count: maxLanesAbove)
        var laneBelowEnd = [CGFloat](repeating: -CARD_W, count: maxLanesBelow)

        var result: [TLPositionedCard] = []

        for post in toLayout {
            let t = tlParseDate(post.record.createdAt).timeIntervalSince1970
            let cx = CGFloat(t - wStart) * pxPerSec
            // Clamp card so it never overflows canvas edges
            let cardLeft = max(0, min(cx - CARD_W / 2, canvasW - CARD_W))
            let cardRight = cardLeft + CARD_W + CARD_GAP
            // Dot stays within canvas bounds
            let axisX = min(max(cx, 4), canvasW - 4)

            // Try lanes in order: lane 0 above, lane 0 below, lane 1 above, lane 1 below…
            // This distributes cards evenly on both sides of the axis.
            for i in 0..<max(maxLanesAbove, maxLanesBelow) {
                var placed = false

                if i < maxLanesAbove, laneAboveEnd[i] <= cardLeft {
                    let cardTop = axY - GAP_AXIS - CARD_H - CGFloat(i) * LANE_H
                    laneAboveEnd[i] = cardRight
                    result.append(TLPositionedCard(
                        id: post.uri,
                        post: post,
                        left: cardLeft,
                        top: cardTop,
                        axisX: axisX,
                        isAbove: true
                    ))
                    placed = true
                }

                if !placed, i < maxLanesBelow, laneBelowEnd[i] <= cardLeft {
                    let cardTop = axY + TICK_H + CGFloat(i) * LANE_H
                    laneBelowEnd[i] = cardRight
                    result.append(TLPositionedCard(
                        id: post.uri,
                        post: post,
                        left: cardLeft,
                        top: cardTop,
                        axisX: axisX,
                        isAbove: false
                    ))
                    placed = true
                }

                if placed { break }
            }
            // If no lane fits, the post is skipped — user can zoom in to see it
        }

        return result
    }

    // MARK: - Helpers

    private func engScore(_ post: PostView) -> Int {
        (post.likeCount ?? 0) + (post.repostCount ?? 0) + (post.replyCount ?? 0)
    }

    private func applyZoom() {
        windowStart = windowEnd.addingTimeInterval(-currentZoom.seconds)
        startDate = windowStart
        endDate = windowEnd
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task { await fetchPosts() }
    }

    private func applyCustomRange() {
        guard startDate < endDate else { return }
        windowStart = startDate
        windowEnd = endDate
        // Find the zoom level closest to the user's chosen span
        let span = endDate.timeIntervalSince(startDate)
        if let best = kTLZoomLevels.enumerated().min(by: {
            abs($0.element.seconds - span) < abs($1.element.seconds - span)
        }) {
            zoomIndex = best.offset
        }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task { await fetchPosts() }
    }

    private func doSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        // Reset to default 1-day window
        zoomIndex = 2
        windowEnd = .now
        windowStart = windowEnd.addingTimeInterval(-currentZoom.seconds)
        startDate = windowStart
        endDate = windowEnd
        await fetchPosts()
    }

    @MainActor
    private func fetchPosts() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        allPosts = []

        let sinceStr = tlISO8601.string(from: windowStart)
        let untilStr = tlISO8601.string(from: windowEnd)

        do {
            var posts: [PostView] = []

            if q.hasPrefix("@") {
                // Author feed — walk backward through up to 6 pages (max ~300 posts)
                let handle = String(q.dropFirst())
                var cursor: String? = nil

                outer: for _ in 0..<6 {
                    let resp = try await ATProtocolClient.shared.getAuthorFeed(
                        actor: handle, limit: 50, cursor: cursor, filter: "posts_no_replies"
                    )
                    for item in resp.feed where item.reason == nil {
                        let t = tlParseDate(item.post.record.createdAt).timeIntervalSince1970
                        if t < windowStart.timeIntervalSince1970 { break outer }
                        if t <= windowEnd.timeIntervalSince1970 { posts.append(item.post) }
                    }
                    cursor = resp.cursor
                    if cursor == nil || resp.feed.count < 50 { break }
                }

            } else {
                // Keyword / hashtag search — fetch latest + top, then merge & deduplicate
                let latestResp = try await ATProtocolClient.shared.searchPosts(
                    q: q, sort: "latest", limit: 50,
                    since: sinceStr, until: untilStr, lang: "en"
                )
                let topResp = try? await ATProtocolClient.shared.searchPosts(
                    q: q, sort: "top", limit: 50,
                    since: sinceStr, until: untilStr, lang: "en"
                )

                var seen = Set<String>()
                for post in latestResp.posts + (topResp?.posts ?? []) {
                    let t = tlParseDate(post.record.createdAt).timeIntervalSince1970
                    if !seen.contains(post.uri),
                       t >= windowStart.timeIntervalSince1970,
                       t <= windowEnd.timeIntervalSince1970 {
                        seen.insert(post.uri)
                        posts.append(post)
                    }
                }
            }

            allPosts = posts

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func persistChannel() {
        let raw = query.trimmingCharacters(in: .whitespaces)
        let n   = channelName.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty, !n.isEmpty else { return }
        // Avoid saving duplicates
        guard !savedSearches.contains(where: {
            $0.channelType == "timeline" && $0.query == raw
        }) else { return }
        modelContext.insert(SavedSearch(name: n, query: raw, channelType: "timeline"))
    }
}

// MARK: - Axis Canvas (axis line, ticks, labels, connectors, dots)

struct TLAxisCanvas: View {
    let cards: [TLPositionedCard]
    let windowStart: Date
    let windowSpan: TimeInterval
    let canvasW: CGFloat
    let canvasH: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let axY      = size.height / 2
            let pxPerSec = size.width / CGFloat(windowSpan)
            let wStart   = windowStart.timeIntervalSince1970

            // ── Horizontal axis line ──────────────────────────────────────────
            var axisPath = Path()
            axisPath.move(to: CGPoint(x: 0, y: axY))
            axisPath.addLine(to: CGPoint(x: size.width, y: axY))
            ctx.stroke(axisPath, with: .color(Color.nbBlack), lineWidth: 2)

            // ── Tick marks & labels ──────────────────────────────────────────
            // Pick a tick interval that yields roughly 4–10 ticks
            let targetTicks = max(4, Int(size.width / 150))
            let candidates: [TimeInterval] = [
                60, 300, 600, 1800, 3600, 7200, 14400, 21600, 43200, 86400, 172800, 604800
            ]
            let rawInterval = windowSpan / Double(targetTicks)
            let tickInterval = candidates.min(by: {
                abs($0 - rawInterval) < abs($1 - rawInterval)
            }) ?? 3600

            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "en_US")
            fmt.dateFormat = tickInterval < 86400 ? "h:mm a" : "MM/dd"

            let firstTick = (floor(wStart / tickInterval) + 1) * tickInterval
            var t = firstTick
            while t <= wStart + windowSpan {
                let x = CGFloat(t - wStart) * pxPerSec

                // Tick mark — straddles the axis
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: axY - 6))
                tick.addLine(to: CGPoint(x: x, y: axY + 6))
                ctx.stroke(tick, with: .color(Color.nbTextTertiary), lineWidth: 1)

                // Label below the axis
                ctx.draw(
                    Text(fmt.string(from: Date(timeIntervalSince1970: t)))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.nbTextSecondary),
                    at: CGPoint(x: x, y: axY + 12),
                    anchor: .top
                )

                t += tickInterval
            }

            // ── Connector lines + dots ────────────────────────────────────────
            for card in cards {
                // Connector: dashed blue line from axis dot to the nearest card edge
                let edgeY: CGFloat = card.isAbove ? (card.top + 72) : card.top
                var conn = Path()
                conn.move(to: CGPoint(x: card.axisX, y: axY))
                conn.addLine(to: CGPoint(x: card.axisX, y: edgeY))
                ctx.stroke(
                    conn,
                    with: .color(Color.nbBlue.opacity(0.35)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )

                // Dot on the axis — coral fill with black stroke (neubrutalist)
                let dotR: CGFloat = 4
                let dotRect = CGRect(
                    x: card.axisX - dotR, y: axY - dotR,
                    width: dotR * 2, height: dotR * 2
                )
                ctx.fill(Ellipse().path(in: dotRect), with: .color(Color.nbAccent))
                ctx.stroke(Ellipse().path(in: dotRect), with: .color(Color.nbBlack),
                           lineWidth: 1.5)
            }
        }
    }
}

// MARK: - Timeline Post Card (158×72pt)

struct TLPostCard: View {
    let post: PostView

    private var truncatedText: String {
        let t = post.record.text
        return t.count > 80 ? String(t.prefix(77)) + "…" : t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Author row: tiny circular avatar + @handle
            HStack(spacing: 4) {
                AvatarView(url: post.author.avatar, size: 14)
                Text("@\(post.author.handle)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.nbBlue)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(height: 16)

            // Post text — 2-line clamp
            Text(truncatedText)
                .font(.system(size: 10))
                .foregroundStyle(Color.nbBlack)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 2)

            // Engagement footer
            HStack(spacing: 7) {
                engagementCell("bubble.left", post.replyCount ?? 0)
                engagementCell("arrow.2.squarepath", post.repostCount ?? 0)
                engagementCell("heart", post.likeCount ?? 0)
                Spacer(minLength: 0)
            }
            .frame(height: 12)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(width: 158, height: 72, alignment: .topLeading)
        .background(Color.nbWhite)
        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
        .background(Color.nbBlack.offset(x: 2, y: 2))
    }

    private func engagementCell(_ icon: String, _ count: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 7))
                .foregroundStyle(Color.nbTextTertiary)
            Text(count >= 1000 ? "\(count / 1000)k" : "\(count)")
                .font(.system(size: 8))
                .foregroundStyle(Color.nbTextSecondary)
        }
    }
}
