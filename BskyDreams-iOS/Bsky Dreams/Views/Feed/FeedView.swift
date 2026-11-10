import SwiftUI
import SwiftData

// MARK: - Home Feed (Discover | Following tabs)

struct FeedView: View {
    var toggleSidebar: () -> Void = {}

    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(NetworkMonitor.self) private var network
    @Environment(\.modelContext) private var modelContext
    @Environment(\.navColumn) private var navColumn

    /// This column's feed. The open Duo's second column keeps its own, so two home
    /// feeds (e.g. Following beside Trending) can sit side by side (iOS-DESIGN §10).
    private var feedMode: AppStore.FeedMode {
        get { navColumn == .secondary ? store.secondaryFeedMode : store.feedMode }
        nonmutating set {
            if navColumn == .secondary { store.secondaryFeedMode = newValue } else { store.feedMode = newValue }
        }
    }

    // Discovery sources (Conversations + Trending). Following uses getTimeline only.
    private let discoverFeedURI  = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"
    private let withFriendsURI   = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/with-friends"

    @State private var items: [FeedItem] = []
    @State private var cursor: String?
    @State private var cursorWithFriends: String?
    @State private var cursorBestOf: String?
    @State private var cursorForYou: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var replyingToURI: String? = nil
    @State private var showCompose = false
    @State private var scrollToTopTrigger = 0
    @State private var toggleWidth: CGFloat = 390
    @State private var discoverLooped = false
    @State private var autoFetchCount = 0
    /// Bumped on tab switch so an in-flight load for the OLD tab can't land its
    /// results (or cursors) into the new one.
    @State private var loadGeneration = 0
    /// Per-post "why this is in Discover" reason chips (Discover mode only).
    @State private var whyReasons: [String: String] = [:]

    // Seen post tracking — @State instead of @Query so SwiftData inserts don't
    // trigger ForEach re-renders of every visible card on each mark-seen event.
    @State private var seenURISet: Set<String> = []
    private let seenMaxAge: TimeInterval = 7 * 24 * 3600 // 7 days

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                loadingState
            } else if let err = errorMessage, items.isEmpty, !network.isOffline {
                errorState(err)
            } else {
                feedList
            }
        }
        // System navigation bar (iOS-DESIGN §1.5, §10): on iPhone Duo the New Post item
        // moves into the vertical bar beside the status bar, as Apple's own apps do.
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button { scrollToTopTrigger += 1 } label: {
                    ZStack {
                        Image(systemName: "cloud.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.nbAccent)
                        Image(systemName: "cloud")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color.nbBlack)
                            .fontWeight(.black)
                    }
                    .frame(height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Bsky Dreams — scroll to top")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("New Post", systemImage: "square.and.pencil") { showCompose = true }
            }
        }
        .task {
            // Load seen URIs from SwiftData once, then manage in memory.
            // Avoids @Query cascade re-renders on every mark-seen insert.
            if seenURISet.isEmpty {
                let descriptor = FetchDescriptor<SeenPost>()
                seenURISet = Set((try? modelContext.fetch(descriptor))?.map { $0.uri } ?? [])
            }
            if items.isEmpty { await loadFeed() }
        }
        .sheet(isPresented: $showCompose) {
            ComposeView()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppStore.seenPostsMergedNotification)) { _ in
            // Cloud merge completed — refresh in-memory set so newly synced URIs are filtered
            let descriptor = FetchDescriptor<SeenPost>()
            seenURISet = Set((try? modelContext.fetch(descriptor))?.map { $0.uri } ?? [])
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if errorMessage != nil {
                errorMessage = nil
                items = []
                cursor = nil
                Task { await loadFeed() }
            }
        }
        .onChange(of: auth.session?.accessJwt) { old, new in
            guard old != nil && new != nil && old != new else { return }
            if errorMessage != nil {
                errorMessage = nil
                items = []
                cursor = nil
                Task { await loadFeed() }
            }
        }
    }

    private var feedList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 0).id("feed-top")

                    if network.isOffline {
                        NBOfflineBanner()
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                    }

                    if let err = errorMessage, !items.isEmpty {
                        NBErrorBanner(message: err) {
                            Task { await loadFeed() }
                        }
                        .padding(.top, 10)
                    }

                    HintBanner(id: "feed.welcome", text: "Tap a post to open the conversation. Pull down to refresh.")
                        .padding(.top, 10)

                    // Feed selector: Following · Conversations · Trending
                    feedModeToggle
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                    if items.isEmpty && !isLoading && errorMessage == nil {
                        NBEmptyState(
                            icon: "checkmark.circle",
                            title: "You're all caught up",
                            message: "No new posts right now",
                            actionTitle: "Refresh",
                            action: {
                                Task {
                                    let descriptor = FetchDescriptor<SeenPost>()
                                    seenURISet = Set((try? modelContext.fetch(descriptor))?.map { $0.uri } ?? [])
                                    items = []
                                    cursor = nil; cursorWithFriends = nil; cursorBestOf = nil; cursorForYou = nil
                                    discoverLooped = false
                                    autoFetchCount = 0
                                    await loadFeed()
                                }
                            }
                        )
                        .padding(.top, 40)
                    }

                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            if feedMode.isDiscovery, let why = whyReasons[item.post.uri] {
                                DiscoverWhyChip(text: why)
                            } else if let reposted = item.repostAttribution {
                                DiscoverWhyChip(text: reposted)
                            }
                            PostCardView(
                                post: item.post,
                                showParentPreview: item.reply != nil,
                                onReply: { post in
                                    let isOpening = replyingToURI != post.uri
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        replyingToURI = isOpening ? post.uri : nil
                                    }
                                    if isOpening {
                                        // Scroll the tapped post into view so it's visible above the reply box
                                        Task {
                                            try? await Task.sleep(for: .milliseconds(400))
                                            withAnimation { proxy.scrollTo(post.uri, anchor: .center) }
                                        }
                                    }
                                }
                            )
                        }
                        .id(item.post.uri)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .onAppear {
                            markPostSeen(item.post)
                            // Trigger next page when within last 10 items — loads ahead
                            // of the scroll position so images are cached before they're visible.
                            let count = items.count
                            if let idx = items.lastIndex(where: { $0.id == item.id }),
                               idx >= count - 10 {
                                Task { await loadFeed(loadMore: true) }
                            }
                        }
                    }

                    if isLoading && !items.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .nbReadableWidth()
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let uri = replyingToURI,
                   let item = items.first(where: { $0.post.uri == uri }) {
                    InlineReplyView(replyTo: item.post) {
                        withAnimation(.easeInOut(duration: 0.2)) { replyingToURI = nil }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: replyingToURI)
            .refreshable {
                // Re-sync seen set from SwiftData so cloud-merged posts are respected
                let descriptor = FetchDescriptor<SeenPost>()
                seenURISet = Set((try? modelContext.fetch(descriptor))?.map { $0.uri } ?? [])
                let previousURIs = Set(items.map { $0.post.uri })
                items = []
                cursor = nil; cursorWithFriends = nil; cursorBestOf = nil; cursorForYou = nil
                discoverLooped = false
                autoFetchCount = 0
                await loadFeed()
                if errorMessage == nil, items.contains(where: { !previousURIs.contains($0.post.uri) }) {
                    Haptics.success()
                }
            }
            .onChange(of: scrollToTopTrigger) { _, _ in
                withAnimation { proxy.scrollTo("feed-top", anchor: .top) }
            }
        }
    }

    // MARK: - Neubrutalist Tab Toggle

    private var feedModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(AppStore.FeedMode.allCases, id: \.self) { mode in
                let selected = feedMode == mode
                Button {
                    if !selected {
                        Haptics.selection()
                        feedMode = mode
                        items = []
                        whyReasons.removeAll()
                        cursor = nil; cursorWithFriends = nil; cursorBestOf = nil; cursorForYou = nil
                        discoverLooped = false
                        autoFetchCount = 0
                        loadGeneration += 1
                        isLoading = false
                        Task { await loadFeed() }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if toggleShowsIcons {
                            Image(systemName: mode.icon)
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text(mode.rawValue.uppercased())
                            .font(.syne(toggleLabelSize, weight: .bold))
                            .tracking(0.3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)   // safety only — the size above already fits
                    }
                    // Three tabs share ~390pt: chrome caps below accessibility sizes,
                    // where "CONVERSATIONS" truncated to "CONVE…" (device, accessibility3).
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    .foregroundStyle(selected ? Color.white : Color.nbBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
                    .background(selected ? Color.nbAccent : Color.nbWhite)
                }
                .accessibilityLabel(mode.rawValue)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
        .background(
            Color.nbBlack
                .offset(x: 3, y: 3)
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { toggleWidth = $0 }
    }

    // One label size for all three tabs, derived from the toggle's measured width, so
    // "CONVERSATIONS" is never the only one shrunk (it was, in a ~310pt Duo column).
    // Width per tab ≈ 9.75 × size + padding (+14pt with the icon); icons drop out first.
    private var toggleShowsIcons: Bool { toggleWidth >= 380 }
    private var toggleLabelSize: CGFloat {
        let perTab = toggleWidth / 3 - 12 - (toggleShowsIcons ? 14 : 0)
        return min(12, max(9, perTab / 9.75))
    }

    private var loadingState: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if network.isOffline {
                    NBOfflineBanner()
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                }
                ForEach(0..<5, id: \.self) { _ in
                    NBSkeletonPostRow()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
            }
            .nbReadableWidth()
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        // Rule §2: one error primitive everywhere (coral banner + Retry).
        VStack {
            NBErrorBanner(message: "Couldn't load your feed. \(message)", retry: { Task { await loadFeed() } })
            Spacer()
        }
        .padding(.top, 10)
    }

    // MARK: - Seen Posts

    private func markPostSeen(_ post: PostView) {
        guard !store.feedSeenBypass else { return }
        guard seenURISet.insert(post.uri).inserted else { return }
        modelContext.insert(SeenPost(uri: post.uri, likeCount: post.likeCount ?? 0, repostCount: post.repostCount ?? 0))
        if let did = auth.session?.did {
            // Apply the same 7-day window used by TVView and the background flush.
            // seenURISet is pre-populated from ALL SwiftData entries (no age filter),
            // so using it directly would upload stale URIs and inflate the cloud record.
            let cutoff = Date().addingTimeInterval(-seenMaxAge)
            let descriptor = FetchDescriptor<SeenPost>(predicate: #Predicate { $0.seenAt >= cutoff })
            let recentURIs = (try? modelContext.fetch(descriptor))?.map { $0.uri } ?? Array(seenURISet)
            store.scheduleSeenSync(uris: recentURIs, did: did)
        }
    }

    /// Simple seen check matching the web app: filter if uri is in the map.
    /// The bypass flag lets users see everything for the rest of the session.
    private func isPostSeen(_ post: PostView) -> Bool {
        guard !store.feedSeenBypass else { return false }
        return seenURISet.contains(post.uri)
    }

    // MARK: - Load Feed

    private func loadFeed(loadMore: Bool = false) async {
        guard !isLoading else { return }
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil
        defer { if generation == loadGeneration { isLoading = false } }

        do {
            let mergedFeed: [FeedItem]
            let seenSnapshot: Set<String>? = store.feedSeenBypass ? nil : seenURISet

            // The user's own moderation (muted words, label/adult prefs, labelers) is built
            // once per session and applied to ALL feeds — including Following.
            if !store.discoverContextReady, let did = auth.session?.did {
                await store.buildDiscoverContext(did: did)
            }
            let prefs = store.moderationPrefs

            switch feedMode {
            case .following:
                // Following = your follows, chronological. Pure getTimeline (reverse-chron
                // of the people you follow) — a clean "catch up on your people" feed,
                // distinct from the ranked discovery feeds. Honors your moderation.
                let fetchCursor = loadMore ? cursor : nil
                let timeline = try await ATProtocolClient.shared.getTimeline(limit: 40, cursor: fetchCursor)
                guard generation == loadGeneration else { return }
                cursor = timeline.cursor

                var seen = Set<String>()
                mergedFeed = timeline.feed.filter {
                    seen.insert($0.post.uri).inserted && $0.post.isEnglish && !DiscoverEngine.shouldHide($0, prefs: prefs)
                }
                // Keep the API's chronological order (do NOT re-rank).

            case .conversations, .trending:
                // Personalized discovery. Sources: whats-hot (trending) + with-friends
                // (social graph). hot-classic was removed (identical for every account; the
                // generic NSFW firehose). Conversations rewards discussion; Trending rewards
                // popularity. Both apply the same network+topic personalization + moderation.
                let fetchCursor: String?
                if loadMore && discoverLooped { fetchCursor = nil }
                else { fetchCursor = loadMore ? cursor : nil }

                async let primary = ATProtocolClient.shared.getFeed(uri: discoverFeedURI, limit: 40, cursor: fetchCursor)
                async let friends = try? ATProtocolClient.shared.getFeed(uri: withFriendsURI, limit: 30, cursor: loadMore ? cursorWithFriends : nil)

                let p = try await primary
                let f = await friends
                guard generation == loadGeneration else { return }
                cursor = p.cursor
                cursorWithFriends = f?.cursor

                var all = p.feed
                if let f { all.append(contentsOf: f.feed) }

                let tags = store.interestTags
                let conversational = feedMode == .conversations
                var seen = Set<String>()
                mergedFeed = all
                    .filter { seen.insert($0.post.uri).inserted && $0.post.isEnglish && !DiscoverEngine.shouldHide($0, prefs: prefs) }
                    .sorted { DiscoverEngine.score($0, conversational: conversational, interestTags: tags) > DiscoverEngine.score($1, conversational: conversational, interestTags: tags) }
            }

            if loadMore {
                let existingUris = Set(items.map { $0.post.uri })
                let newItems = mergedFeed.filter { item in
                    guard !existingUris.contains(item.post.uri) else { return false }
                    return !(seenSnapshot?.contains(item.post.uri) ?? false)
                }
                items.append(contentsOf: newItems)
                if feedMode.isDiscovery {
                    for it in newItems { whyReasons[it.post.uri] = DiscoverEngine.why(it, interestTags: store.interestTags) }
                }

                let urlsToWarm = newItems.flatMap { feedItemImageURLs(for: $0.post) }
                Task.detached(priority: .background) { prefetchImageURLs(urlsToWarm) }

                if feedMode.isDiscovery && cursor == nil && !discoverLooped && !mergedFeed.isEmpty {
                    discoverLooped = true
                }
                let hasMore = cursor != nil || cursorWithFriends != nil || cursorBestOf != nil || cursorForYou != nil || discoverLooped
                if newItems.isEmpty && hasMore && autoFetchCount < 3 {
                    autoFetchCount += 1
                    isLoading = false   // release our own guard, or the recursion is a no-op
                    await loadFeed(loadMore: true)
                } else {
                    autoFetchCount = 0
                }
            } else {
                var seen = Set<String>()
                items = mergedFeed.filter { item in
                    guard seen.insert(item.post.uri).inserted else { return false }
                    return !(seenSnapshot?.contains(item.post.uri) ?? false)
                }
                if feedMode.isDiscovery {
                    whyReasons.removeAll()
                    for it in items { whyReasons[it.post.uri] = DiscoverEngine.why(it, interestTags: store.interestTags) }
                }
                let urlsToWarm = items.flatMap { feedItemImageURLs(for: $0.post) }
                Task.detached(priority: .background) { prefetchImageURLs(urlsToWarm) }
                cursor = mergedFeed.isEmpty ? nil : cursor
                discoverLooped = false
                autoFetchCount = 0
            }
        } catch {
            guard generation == loadGeneration else { return }
            Haptics.error()
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - "Why is this in Discover?" chip
// A small, honest line of provenance above a Discover post. Transparency is the point:
// the user should understand why a post reached them, not face an opaque "for you" box.

struct DiscoverWhyChip: View {
    let text: String

    private var icon: String {
        if text.hasPrefix("From someone you follow") || text.hasPrefix("Followed by") { return "person.2.fill" }
        if text.hasPrefix("Reposted by") { return "arrow.2.squarepath" }
        if text.hasPrefix("Matches your interest") { return "number" }
        if text.hasPrefix("Active conversation") { return "bubble.left.and.bubble.right.fill" }
        return "sparkles"
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.inter(11, weight: .medium))
                .lineLimit(2)   // wraps at large text instead of "37 rep…"
        }
        .foregroundStyle(Color.nbTextSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .padding(.leading, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Why you're seeing this: \(text)")
    }
}
