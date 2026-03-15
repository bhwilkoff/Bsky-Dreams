import SwiftUI

struct ThreadView: View {
    let uri: String
    var initialPost: PostView?

    @State private var thread: ThreadViewPost?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var composeTarget: PostView? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading thread...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let thread {
                threadContent(thread)
            } else if let error = errorMessage {
                ContentUnavailableView(error, systemImage: "bubble.left.and.exclamationmark.bubble.right")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Thread")
        .task { await loadThread() }
        .sheet(item: $composeTarget) { post in
            ComposeView(replyTo: post)
        }
    }

    @ViewBuilder
    private func threadContent(_ thread: ThreadViewPost) -> some View {
        if let threadPost = thread.post {
            ScrollView {
                LazyVStack(spacing: 4) {
                    // Ancestors (scroll up for parent context)
                    ancestorViews(threadPost.parent, depth: 0)

                    // Root post (highlighted)
                    PostCardView(post: threadPost.post, onReply: { composeTarget = $0 })
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
        }
    }

    @ViewBuilder
    private func ancestorViews(_ parent: ThreadViewPost?, depth: Int) -> some View {
        if let parent, depth < 4 {
            if let threadPost = parent.post {
                Group {
                    ancestorViews(threadPost.parent, depth: depth + 1)
                    PostCardView(
                        post: threadPost.post,
                        showParentPreview: false,
                        onReply: { composeTarget = $0 }
                    )
                    .padding(.horizontal, 8)
                    .opacity(0.8)
                }
            }
        }
    }

    @ViewBuilder
    private func replyView(_ reply: ThreadViewPost, depth: Int) -> some View {
        if let replyPost = reply.post {
            VStack(spacing: 4) {
                PostCardView(
                    post: replyPost.post,
                    depth: min(depth, 4),
                    showParentPreview: false,
                    onReply: { composeTarget = $0 }
                )
                .padding(.horizontal, 8)

                if depth < 4 {
                    if let nestedReplies = replyPost.replies {
                        ForEach(Array(nestedReplies.prefix(3).enumerated()), id: \.offset) { _, nested in
                            replyView(nested, depth: depth + 1)
                        }
                    }
                } else {
                    // Continue this thread button
                    NavigationLink(value: PostDestination(uri: replyPost.post.uri, post: replyPost.post)) {
                        HStack {
                            Text("Continue this thread →")
                                .font(.inter(13, weight: .semibold))
                                .foregroundStyle(Color.nbBlue)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
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
