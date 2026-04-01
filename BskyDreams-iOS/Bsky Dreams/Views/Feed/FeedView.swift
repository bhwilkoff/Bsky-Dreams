import SwiftUI
import SwiftData

// MARK: - Home Feed (Discover | Following tabs)

struct FeedView: View {
    var toggleSidebar: () -> Void = {}

    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(\.modelContext) private var modelContext

    // Discover sources
    private let discoverFeedURI  = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"
    private let hotClassicURI    = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/hot-classic"
    private let withFriendsURI   = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/with-friends"
    // Following sources
    private let bestOfFollowsURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/best-of-follows"
    private let forYouURI        = "at://did:plc:3guzzweuqraryl3rdkimjamk/app.bsky.feed.generator/for-you"

    @State private var items: [FeedItem] = []
    @State private var cursor: String?
    @State private var cursorHotClassic: String?
    @State private var cursorWithFriends: String?
    @State private var cursorBestOf: String?
    @State private var cursorForYou: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var replyingToURI: String? = nil
    @State private var showCompose = false
    @State private var scrollToTopTrigger = 0
    @State private var discoverLooped = false
    @State private var autoFetchCount = 0

    // Seen post tracking — @State instead of @Query so SwiftData inserts don't
    // trigger ForEach re-renders of every visible card on each mark-seen event.
    @State private var seenURISet: Set<String> = []
    private let seenMaxAge: TimeInterval = 7 * 24 * 3600 // 7 days

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                loadingState
            } else if let err = errorMessage, items.isEmpty {
                errorState(err)
            } else {
                feedList
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            feedNavBar
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

    // Extracted to a struct so SwiftUI can skip re-renders when inputs haven't changed
    private var feedNavBar: some View {
        FeedNavBar(
            onToggleSidebar: toggleSidebar,
            onScrollToTop: { scrollToTopTrigger += 1 },
            onCompose: { showCompose = true }
        )
    }

    private var feedList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 0).id("feed-top")

                    // NB Feed mode toggle
                    feedModeToggle
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                    ForEach(items) { item in
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
                items = []
                cursor = nil; cursorHotClassic = nil; cursorWithFriends = nil; cursorBestOf = nil; cursorForYou = nil
                discoverLooped = false
                autoFetchCount = 0
                await loadFeed()
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
                Button {
                    if store.feedMode != mode {
                        store.feedMode = mode
                        items = []
                        cursor = nil; cursorHotClassic = nil; cursorWithFriends = nil; cursorBestOf = nil; cursorForYou = nil
                        discoverLooped = false
                        autoFetchCount = 0
                        Task { await loadFeed() }
                    }
                } label: {
                    Text(mode.rawValue.uppercased())
                        .font(.syne(13, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(store.feedMode == mode ? Color.white : Color.nbBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(store.feedMode == mode ? Color.nbAccent : Color.nbWhite)
                }
            }
        }
        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
        .background(
            Color.nbBlack
                .offset(x: 3, y: 3)
        )
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.2)
            Text("Loading feed...")
                .font(.inter(14))
                .foregroundStyle(Color.nbTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.nbAccent)
            Text(message)
                .font(.inter(14))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") { Task { await loadFeed() } }
                .nbButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let mergedFeed: [FeedItem]
            let seenSnapshot: Set<String>? = store.feedSeenBypass ? nil : seenURISet

            switch store.feedMode {
            case .following:
                // Hybrid following: chronological timeline + best-of-follows + collaborative "For You"
                let fetchCursor = loadMore ? cursor : nil

                async let timelineResult = ATProtocolClient.shared.getTimeline(limit: 30, cursor: fetchCursor)
                async let bestOfResult = try? ATProtocolClient.shared.getFeed(uri: bestOfFollowsURI, limit: 20, cursor: loadMore ? cursorBestOf : nil)
                async let forYouResult = try? ATProtocolClient.shared.getFeed(uri: forYouURI, limit: 20, cursor: loadMore ? cursorForYou : nil)

                let timeline = try await timelineResult
                let bestOf = await bestOfResult
                let forYou = await forYouResult

                cursor = timeline.cursor
                cursorBestOf = bestOf?.cursor
                cursorForYou = forYou?.cursor

                var all = timeline.feed
                if let bestOf { all.append(contentsOf: bestOf.feed) }
                if let forYou { all.append(contentsOf: forYou.feed) }

                var seen = Set<String>()
                mergedFeed = all.filter { seen.insert($0.post.uri).inserted }
                    .sorted { trendingScore($0.post) > trendingScore($1.post) }

            case .discover:
                // Hybrid discover: 3 feeds in parallel — personalized trending, network-wide
                // trending, and social-graph trending. Failures on secondary feeds are ignored.
                let fetchCursor: String?
                if loadMore && discoverLooped { fetchCursor = nil }
                else { fetchCursor = loadMore ? cursor : nil }

                async let primary = ATProtocolClient.shared.getFeed(uri: discoverFeedURI, limit: 30, cursor: fetchCursor)
                async let classic = try? ATProtocolClient.shared.getFeed(uri: hotClassicURI, limit: 20, cursor: loadMore ? cursorHotClassic : nil)
                async let friends = try? ATProtocolClient.shared.getFeed(uri: withFriendsURI, limit: 20, cursor: loadMore ? cursorWithFriends : nil)

                let p = try await primary
                let c = await classic
                let f = await friends

                cursor = p.cursor
                cursorHotClassic = c?.cursor
                cursorWithFriends = f?.cursor

                var all = p.feed
                if let c { all.append(contentsOf: c.feed) }
                if let f { all.append(contentsOf: f.feed) }

                var seen = Set<String>()
                mergedFeed = all.filter { seen.insert($0.post.uri).inserted }
                    .sorted { trendingScore($0.post) > trendingScore($1.post) }
            }

            if loadMore {
                let existingUris = Set(items.map { $0.post.uri })
                let newItems = mergedFeed.filter { item in
                    guard !existingUris.contains(item.post.uri) else { return false }
                    return !(seenSnapshot?.contains(item.post.uri) ?? false)
                }
                items.append(contentsOf: newItems)

                let urlsToWarm = newItems.flatMap { feedItemImageURLs(for: $0.post) }
                Task.detached(priority: .background) { prefetchImageURLs(urlsToWarm) }

                if store.feedMode == .discover && cursor == nil && !discoverLooped && !mergedFeed.isEmpty {
                    discoverLooped = true
                }
                let hasMore = cursor != nil || cursorHotClassic != nil || cursorWithFriends != nil || cursorBestOf != nil || cursorForYou != nil || discoverLooped
                if newItems.isEmpty && hasMore && autoFetchCount < 3 {
                    autoFetchCount += 1
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
                let urlsToWarm = items.flatMap { feedItemImageURLs(for: $0.post) }
                Task.detached(priority: .background) { prefetchImageURLs(urlsToWarm) }
                cursor = mergedFeed.isEmpty ? nil : cursor
                discoverLooped = false
                autoFetchCount = 0
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// HN-style trending score: rewards posts that gain likes quickly.
    private func trendingScore(_ post: PostView) -> Double {
        let likes = Double(post.likeCount ?? 0)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let postDate = formatter.date(from: post.indexedAt) ?? Date()
        let hours = max(0, Date().timeIntervalSince(postDate) / 3600)
        return (likes - 1) / pow(hours + 2, 1.8)
    }
}

// MARK: - Feed Navigation Bar
// Extracted as a struct so SwiftUI identity-diffs inputs and skips re-renders
// when the feed state changes but the nav bar inputs haven't.

private struct FeedNavBar: View {
    let onToggleSidebar: () -> Void
    let onScrollToTop: () -> Void
    let onCompose: () -> Void

    var body: some View {
        ZStack(alignment: .center) {
            // Logo — absolutely centered, scaled to 36pt tall to match button box height
            Button(action: onScrollToTop) {
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
                .frame(height: 36)
            }
            .buttonStyle(.plain)

            // Hamburger and compose icon at edges — both 36×36 bordered squares
            HStack(spacing: 0) {
                // Hamburger
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.nbBlack)
                    .frame(width: 36, height: 36)
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                    .contentShape(Rectangle())
                    .onTapGesture { onToggleSidebar() }
                    .accessibilityLabel("Open sidebar")
                    .accessibilityAddTraits(.isButton)

                Spacer()

                // Compose / new post
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.nbBlack)
                    .frame(width: 36, height: 36)
                    .background(Color.nbWhite)
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                    .contentShape(Rectangle())
                    .onTapGesture { onCompose() }
                    .accessibilityLabel("New post")
                    .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Color.nbWhite)
        .overlay(alignment: .bottom) {
            Color.nbBorder.frame(height: 1)
        }
    }
}
