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
                                    ? "You're offline — this conversation will load when you reconnect."
                                    : "Couldn't load this conversation.",
                                  retry: network.isOffline ? nil : { Task { await loadThread() } })
                    Spacer()
                }
                .padding(12)
            }
        }
        .nbNavBar(title: "CONVERSATION", leading: { NBBackButton() })
        .task { await loadThread() }
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
                title: "POST UNAVAILABLE",
                message: "This post may have been deleted, or you don't have access to it."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func threadScroll(_ threadPost: ThreadPost) -> some View {
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
