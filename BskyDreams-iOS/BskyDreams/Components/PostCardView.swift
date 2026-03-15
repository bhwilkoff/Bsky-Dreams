import SwiftUI

// MARK: - Post Card — core reusable component

struct PostCardView: View {
    let post: PostView
    var depth: Int = 0
    var showParentPreview: Bool = true
    var onReply: ((PostView) -> Void)? = nil

    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store

    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var isReposted: Bool = false
    @State private var repostCount: Int = 0
    @State private var showRepostSheet = false
    @State private var showReportMenu = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationLink(value: PostDestination(uri: post.uri, post: post)) {
            VStack(alignment: .leading, spacing: 0) {
                // Parent preview for replies
                if showParentPreview, let parent = post.reply?.parent?.postView {
                    ParentPreviewView(post: parent)
                }

                // Main card
                VStack(alignment: .leading, spacing: 10) {
                    // Author header
                    authorHeader

                    // Post text
                    if !post.record.text.isEmpty {
                        RichTextView(text: post.record.text, facets: post.record.facets)
                            .font(.inter(15))
                    }

                    // Embed
                    if let embed = post.embed {
                        EmbedView(embed: embed)
                    }

                    // Action bar
                    actionBar
                }
                .padding(12)
                .background(Color.nbWhite)
                .nbBorder()
                .nbShadow()
                .padding(.horizontal, CGFloat(depth) * 12)
            }
        }
        .buttonStyle(.plain)
        .onAppear { syncState() }
        .confirmationDialog("Repost Options", isPresented: $showRepostSheet) {
            Button(isReposted ? "Undo Repost" : "Repost") { toggleRepost() }
            Button("Quote Post") {
                store.composeQuote = post
                store.selectedTab = .compose
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showShareSheet) {
            let url = "https://bsky.app/profile/\(post.author.handle)/post/\(post.rkey)"
            ShareSheet(activityItems: [URL(string: url) ?? url])
        }
    }

    private var authorHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            NavigationLink(value: ProfileDestination(actor: post.author.did)) {
                AvatarView(url: post.author.avatar, size: 40)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.author.name)
                        .font(.inter(14, weight: .semibold))
                        .foregroundStyle(Color.nbBlack)
                        .lineLimit(1)

                    Text("@\(post.author.handle)")
                        .font(.inter(13))
                        .foregroundStyle(Color.nbBlack.opacity(0.5))
                        .lineLimit(1)

                    Spacer()

                    Text(post.relativeTime)
                        .font(.inter(12))
                        .foregroundStyle(Color.nbBlack.opacity(0.5))
                }
            }

            Menu {
                Button("Share Post") { showShareSheet = true }
                Button("Report", role: .destructive) { showReportMenu = true }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color.nbBlack.opacity(0.4))
                    .padding(4)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 28) {
            // Reply
            Button {
                onReply?(post)
            } label: {
                Label("\(post.replyCount ?? 0)", systemImage: "bubble.left")
                    .font(.inter(13))
                    .foregroundStyle(Color.nbBlack.opacity(0.6))
            }
            .buttonStyle(NeubrutalistIconButtonStyle())

            // Repost
            Button { showRepostSheet = true } label: {
                Label("\(repostCount)", systemImage: "arrow.2.squarepath")
                    .font(.inter(13))
                    .foregroundStyle(isReposted ? Color.nbLime : Color.nbBlack.opacity(0.6))
            }
            .buttonStyle(NeubrutalistIconButtonStyle())
            .sensoryFeedback(.impact(weight: .light), trigger: isReposted)

            // Like
            Button { toggleLike() } label: {
                Label("\(likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                    .font(.inter(13))
                    .foregroundStyle(isLiked ? Color.nbAccent : Color.nbBlack.opacity(0.6))
            }
            .buttonStyle(NeubrutalistIconButtonStyle())
            .sensoryFeedback(.impact(weight: .medium), trigger: isLiked)

            Spacer()

            // Share
            Button { showShareSheet = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nbBlack.opacity(0.4))
            }
            .buttonStyle(NeubrutalistIconButtonStyle())
        }
    }

    private func syncState() {
        isLiked = post.viewer?.like != nil
        likeCount = post.likeCount ?? 0
        isReposted = post.viewer?.repost != nil
        repostCount = post.repostCount ?? 0
    }

    private func toggleLike() {
        guard let did = auth.session?.did else { return }
        let wasLiked = isLiked
        let prevCount = likeCount

        // Optimistic update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1

        Task {
            do {
                if wasLiked, let likeUri = post.viewer?.like {
                    try await ATProtocolClient.shared.unlikePost(likeUri: likeUri, did: did)
                } else {
                    _ = try await ATProtocolClient.shared.likePost(uri: post.uri, cid: post.cid, did: did)
                }
            } catch {
                // Rollback
                isLiked = wasLiked
                likeCount = prevCount
            }
        }
    }

    private func toggleRepost() {
        guard let did = auth.session?.did else { return }
        let wasReposted = isReposted
        let prevCount = repostCount

        isReposted.toggle()
        repostCount += isReposted ? 1 : -1

        Task {
            do {
                if wasReposted, let repostUri = post.viewer?.repost {
                    try await ATProtocolClient.shared.unrepost(repostUri: repostUri, did: did)
                } else {
                    _ = try await ATProtocolClient.shared.repost(uri: post.uri, cid: post.cid, did: did)
                }
            } catch {
                isReposted = wasReposted
                repostCount = prevCount
            }
        }
    }
}

// MARK: - Parent Preview

struct ParentPreviewView: View {
    let post: PostView

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(Color.nbBlue.opacity(0.3))
                .frame(width: 2)
                .padding(.leading, 19)

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(post.author.handle)")
                    .font(.inter(12, weight: .semibold))
                    .foregroundStyle(Color.nbBlue)
                Text(post.record.text)
                    .font(.inter(12))
                    .foregroundStyle(Color.nbBlack.opacity(0.6))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .padding(.trailing, 12)
    }
}

// MARK: - Embed View

struct EmbedView: View {
    let embed: Embed

    var body: some View {
        switch embed {
        case .images(let imgs):
            ImageGridView(images: imgs.images)
        case .video(let vid):
            VideoThumbnailView(video: vid)
        case .external(let ext):
            LinkCardView(card: ext.external)
        case .record(let rec):
            if case .post(let quoted) = rec.record {
                QuotedPostView(post: quoted)
            }
        case .recordWithMedia(let rwm):
            VStack(spacing: 8) {
                switch rwm.media {
                case .images(let imgs): ImageGridView(images: imgs.images)
                case .video(let vid): VideoThumbnailView(video: vid)
                case .external(let ext): LinkCardView(card: ext.external)
                case .unknown: EmptyView()
                }
                if case .post(let quoted) = rwm.record.record {
                    QuotedPostView(post: quoted)
                }
            }
        case .unknown:
            EmptyView()
        }
    }
}

// MARK: - Navigation Destinations

struct PostDestination: Hashable {
    let uri: String
    let post: PostView
}

struct ProfileDestination: Hashable {
    let actor: String
}

struct HashtagDestination: Hashable {
    let tag: String
}

// MARK: - Share Sheet Wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
