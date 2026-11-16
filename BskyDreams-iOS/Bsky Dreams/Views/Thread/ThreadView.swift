import SwiftUI

struct ThreadView: View {
    let uri: String
    var initialPost: PostView?

    @State private var thread: ThreadViewPost?
    @State private var isLoading = true
    @Environment(NetworkMonitor.self) private var network
    @State private var errorMessage: String?
    @State private var replyingToURI: String? = nil
    @State private var replyingToPost: PostView? = nil
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var width: CGFloat = 0
    @State private var fold = FoldGeometry()

    var body: some View {
        Group {
            // Full-screen loading only on FIRST load — pull-to-refresh keeps content.
            if isLoading && thread == nil {
                ScrollView {
                    VStack(spacing: 8) {
                        if network.isOffline { NBOfflineBanner() }
                        ForEach(0..<3, id: \.self) { _ in NBSkeletonPostRow() }
                    }
                    .padding(12)
                }
                .accessibilityLabel("Loading conversation")
            } else if let thread {
                threadContent(thread)
            } else if errorMessage != nil {
                VStack(spacing: 12) {
                    if network.isOffline { NBOfflineBanner() }
                    NBErrorBanner(message: network.isOffline
                                    ? "You're offline. The conversation will load when you're back."
                                    : "This conversation didn't load.",
                                  retry: network.isOffline ? nil : { Task { await loadThread() } })
                    Spacer()
                }
                .padding(12)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onGeometryChange(for: FoldGeometry.self) { proxy in
            FoldGeometry(proxy: proxy)
        } action: { fold = $0 }
        .nbNavBar(title: "CONVERSATION", leading: { NBBackButton() })
        .task {
            openPendingReply(initialPost)
            await loadThread()
            openPendingReply(thread?.post?.post)
        }
    }

    /// "Reply in context" (AppStore.openReply): open the reply box for this post as the
    /// conversation appears.
    private func openPendingReply(_ post: PostView?) {
        guard let post, store.pendingReplyURI == uri, post.uri == uri else { return }
        store.pendingReplyURI = nil
        replyingToURI = post.uri
        replyingToPost = post
    }

    @ViewBuilder
    private func threadContent(_ thread: ThreadViewPost) -> some View {
        if let threadPost = thread.post {
            threadScroll(threadPost)
        } else {
            // Thread resolved but the root post is unavailable (deleted, blocked, or
            // not found). Show an explicit empty state rather than a blank screen.
            NBEmptyState(
                icon: "bubble.left.and.exclamationmark.bubble.right",
                title: "Post unavailable",
                message: "It may have been deleted, or it isn't visible to you."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Wide enough for two pages (One Column on the open Duo, a wide pushed screen):
    /// the post on the left page, what people are saying on the right — Stream's
    /// conversation beat, as a place you can stay (iOS-DESIGN §11).
    private var isTwoPage: Bool { width >= 760 }

    @ViewBuilder
    private func threadScroll(_ threadPost: ThreadPost) -> some View {
        if isTwoPage {
            twoPage(threadPost)
        } else {
            singleColumn(threadPost)
        }
    }

    private func twoPage(_ threadPost: ThreadPost) -> some View {
        let split: (CGFloat, CGFloat) = {
            if let f = fold.foldX, f.lowerBound > width * 0.3, f.upperBound < width * 0.7 {
                return (f.lowerBound, f.upperBound - f.lowerBound)
            }
            return ((width * 0.46).rounded(), 0)
        }()
        let replies = threadPost.replies ?? []
        return HStack(spacing: 0) {
            // Left page: the post (and what it answers), large, on its author's colors.
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ancestorViews(threadPost.parent, depth: 0)
                    rootCard(threadPost)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 12)
                .environment(\.nbColumnWidth, 900)   // feature-size reading type
            }
            .frame(width: split.0)
            .background {
                NBContentField(url: threadPost.post.author.avatar.flatMap { URL(string: $0) },
                               tone: colorScheme == .dark ? .deep : .pale)
                    .nbBlendsIntoPaper(edge: .trailing)   // one spread, not two slabs
                    .ignoresSafeArea()
            }
            Color.clear.frame(width: split.1)
            // Right page: the replies.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    // Magazine header (§13): kicker, then the count that matters.
                    VStack(alignment: .leading, spacing: 8) {
                        NBKicker(text: "What people are saying")
                        HStack(spacing: 28) {
                            NBStat(value: threadPost.post.replyCount ?? 0, label: "replies")
                            NBStat(value: threadPost.post.repostCount ?? 0, label: "reposts")
                            NBStat(value: threadPost.post.likeCount ?? 0, label: "likes")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    if replies.isEmpty {
                        Text("No replies yet. You could be the first.")
                            .nbReadingFont(17)
                            .foregroundStyle(Color.nbTextSecondary)
                            .padding(16)
                    }
                    ForEach(Array(replies.enumerated()), id: \.offset) { _, reply in
                        replyView(reply, depth: 1)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .environment(\.nbColumnWidth, width - split.0 - split.1)   // sized to its own page

        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) { replyBox }
        .animation(.easeInOut(duration: 0.2), value: replyingToURI)
    }

    private func rootCard(_ threadPost: ThreadPost) -> some View {
        PostCardView(
            post: threadPost.post,
            showParentPreview: false,
            suppressNavigation: true,
            onReply: onReply
        )
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.nbAccent).frame(width: 4)
        }
    }

    @ViewBuilder
    private var replyBox: some View {
        if let post = replyingToPost {
            InlineReplyView(replyTo: post) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    replyingToURI = nil
                    replyingToPost = nil
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func singleColumn(_ threadPost: ThreadPost) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    Color.clear.frame(height: 0).id("thread-top")

                    // Ancestors shown above root (oldest first)
                    ancestorViews(threadPost.parent, depth: 0)

                    // Root post (accent left border) — don't show parent preview here,
                    // ancestors are already rendered above via ancestorViews
                    PostCardView(
                        post: threadPost.post,
                        showParentPreview: false,
                        suppressNavigation: true,  // already viewing this post
                        onReply: { post in
                            let isOpening = replyingToURI != post.uri
                            withAnimation(.easeInOut(duration: 0.2)) {
                                replyingToURI = isOpening ? post.uri : nil
                                replyingToPost = isOpening ? post : nil
                            }
                        }
                    )
                    // Bar on the card's own edge (it floated in the padding gutter, detached).
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.nbAccent)
                            .frame(width: 4)
                    }
                    .padding(.horizontal, 8)

                    // Replies
                    if let replies = threadPost.replies {
                        ForEach(Array(replies.enumerated()), id: \.offset) { _, reply in
                            replyView(reply, depth: 1)
                        }
                    }
                }
                .nbReadableWidth()
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            // Floating reply box above keyboard — mirrors FeedView's safeAreaInset pattern
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let post = replyingToPost {
                    InlineReplyView(replyTo: post) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            replyingToURI = nil
                            replyingToPost = nil
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: replyingToURI)
            .refreshable { await loadThread() }
        }
    }

    private func onReply(_ post: PostView) {
        let isOpening = replyingToURI != post.uri
        withAnimation(.easeInOut(duration: 0.2)) {
            replyingToURI = isOpening ? post.uri : nil
            replyingToPost = isOpening ? post : nil
        }
    }

    private func ancestorViews(_ parent: ThreadViewPost?, depth: Int) -> AnyView {
        guard let parent, depth < 4, let threadPost = parent.post else {
            return AnyView(EmptyView())
        }
        return AnyView(Group {
            ancestorViews(threadPost.parent, depth: depth + 1)
            PostCardView(
                post: threadPost.post,
                showParentPreview: false,
                suppressNavigation: threadPost.post.uri == uri,  // suppress if it's the current thread
                onReply: onReply
            )
            .padding(.horizontal, 8)
        })
    }

    private func replyView(_ reply: ThreadViewPost, depth: Int) -> AnyView {
        guard let replyPost = reply.post else { return AnyView(EmptyView()) }
        let post = replyPost.post
        let hasMoreReplies = !(replyPost.replies?.isEmpty ?? true)
        return AnyView(VStack(spacing: 4) {
            PostCardView(
                post: post,
                depth: min(depth, 7),
                showParentPreview: false,
                onReply: onReply
            )
            .padding(.horizontal, 8)

            if depth < 4 {
                if let nestedReplies = replyPost.replies {
                    ForEach(Array(nestedReplies.prefix(3).enumerated()), id: \.offset) { _, nested in
                        replyView(nested, depth: depth + 1)
                    }
                }
            } else if hasMoreReplies {
                // Only show "Continue" when there actually are deeper replies
                NavigationLink(value: PostDestination(uri: post.uri, post: post)) {
                    HStack {
                        Text("Continue this conversation →")
                            .font(.inter(13, weight: .semibold))
                            .foregroundStyle(Color.nbLinkColor)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
        })
    }

    private func loadThread() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            thread = try await ATProtocolClient.shared.getPostThread(uri: uri, depth: 6).thread
        } catch {
            Haptics.error()
            errorMessage = error.localizedDescription
        }
    }
}
