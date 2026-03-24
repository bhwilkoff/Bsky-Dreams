import SwiftUI

struct ThreadView: View {
    let uri: String
    var initialPost: PostView?

    @State private var thread: ThreadViewPost?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var replyingToURI: String? = nil
    @State private var replyingToPost: PostView? = nil
    @State private var scrollToTopTrigger = 0

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading conversation...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let thread {
                threadContent(thread)
            } else if let error = errorMessage {
                ContentUnavailableView(error, systemImage: "bubble.left.and.exclamationmark.bubble.right")
            }
        }
        .nbNavBar(title: "CONVERSATION", leading: { NBBackButton() })
        .task { await loadThread() }
    }

    @ViewBuilder
    private func threadContent(_ thread: ThreadViewPost) -> some View {
        if let threadPost = thread.post {
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
                    .padding(.horizontal, 8)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.nbAccent)
                            .frame(width: 4)
                    }

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
            .onChange(of: scrollToTopTrigger) { _, _ in
                withAnimation { proxy.scrollTo("thread-top", anchor: .top) }
            }
            }
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
                            .foregroundStyle(Color.nbBlue)
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
            errorMessage = error.localizedDescription
        }
    }
}
