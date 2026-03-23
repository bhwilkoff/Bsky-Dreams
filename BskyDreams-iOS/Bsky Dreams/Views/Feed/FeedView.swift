import SwiftUI
import SwiftData

// MARK: - Home Feed (Discover | Following tabs)

struct FeedView: View {
    var toggleSidebar: () -> Void = {}

    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(\.modelContext) private var modelContext

    private let discoverFeedURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"

    @State private var items: [FeedItem] = []
    @State private var cursor: String?
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
                            if items.suffix(10).contains(where: { $0.id == item.id }) {
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
                cursor = nil
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
                        cursor = nil
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
            store.scheduleSeenSync(uris: Array(seenURISet), did: did)
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
            let response: FeedResponse
            let fetchCursor: String?
            if loadMore && discoverLooped && store.feedMode == .discover {
                fetchCursor = nil  // Discover exhausted — loop back to page 1
            } else {
                fetchCursor = loadMore ? cursor : nil
            }

            switch store.feedMode {
            case .following:
                response = try await ATProtocolClient.shared.getTimeline(limit: 50, cursor: fetchCursor)
            case .discover:
                response = try await ATProtocolClient.shared.getFeed(uri: discoverFeedURI, limit: 50, cursor: fetchCursor)
            }

            // Build seen set ONCE for this batch — avoids O(n) Set rebuild per item
            let seenSnapshot: Set<String>? = store.feedSeenBypass ? nil : seenURISet

            if loadMore {
                let existingUris = Set(items.map { $0.post.uri })
                let newItems = response.feed.filter { item in
                    guard !existingUris.contains(item.post.uri) else { return false }
                    return !(seenSnapshot?.contains(item.post.uri) ?? false)
                }
                items.append(contentsOf: newItems)

                // Pre-warm URLCache with images from newly appended posts
                let urlsToWarm = newItems.flatMap { feedItemImageURLs(for: $0.post) }
                Task.detached(priority: .background) { prefetchImageURLs(urlsToWarm) }

                if let newCursor = response.cursor {
                    cursor = newCursor
                    if discoverLooped { discoverLooped = false }
                    autoFetchCount = 0
                } else if store.feedMode == .discover && !discoverLooped && response.feed.count > 0 {
                    discoverLooped = true
                    cursor = nil
                } else {
                    cursor = response.cursor
                }

                if newItems.isEmpty && (cursor != nil || discoverLooped) && autoFetchCount < 3 {
                    autoFetchCount += 1
                    await loadFeed(loadMore: true)
                } else {
                    autoFetchCount = 0
                }
            } else {
                var seen = Set<String>()
                items = response.feed.filter { item in
                    guard seen.insert(item.post.uri).inserted else { return false }
                    return !(seenSnapshot?.contains(item.post.uri) ?? false)
                }
                let urlsToWarm = items.flatMap { feedItemImageURLs(for: $0.post) }
                Task.detached(priority: .background) { prefetchImageURLs(urlsToWarm) }
                cursor = response.cursor
                discoverLooped = false
                autoFetchCount = 0
            }
        } catch {
            errorMessage = error.localizedDescription
        }
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
