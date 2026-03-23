import SwiftUI
import SwiftData

struct GalleryView: View {
    private let discoverURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"

    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @State private var seenURISet: Set<String> = []

    @State private var posts: [FeedItem] = []
    @State private var timelineCursor: String?
    @State private var discoverCursor: String?
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var scrollToTopTrigger = 0

    var body: some View {
        Group {
            if (isLoading || !hasLoaded) && posts.isEmpty {
                ProgressView("Loading gallery...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage, posts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.nbAccent)
                    Text(err)
                        .font(.inter(14))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") { Task { await load() } }
                        .nbButton()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if posts.isEmpty {
                ContentUnavailableView(
                    "No Image Posts",
                    systemImage: "photo.stack",
                    description: Text("Pull to refresh or check back later.")
                )
            } else {
                cardFeed
            }
        }
        .nbNavBar(title: "GALLERY", leading: { NBHamburger() })
        .task {
            if seenURISet.isEmpty {
                let descriptor = FetchDescriptor<SeenPost>()
                seenURISet = Set((try? modelContext.fetch(descriptor))?.map { $0.uri } ?? [])
            }
            if !hasLoaded { await load() }
        }
    }

    // MARK: - Card Feed

    private var cardFeed: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 0).id("gallery-top")
                ForEach(posts) { item in
                    GalleryCardView(post: item.post, seenURIs: seenURISet)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .onAppear {
                            if item.id == posts.last?.id {
                                Task { await load(loadMore: true) }
                            }
                        }
                }
                if isLoading && !posts.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            posts = []
            timelineCursor = nil
            discoverCursor = nil
            await load()
        }
        .onChange(of: scrollToTopTrigger) { _, _ in
            withAnimation { proxy.scrollTo("gallery-top", anchor: .top) }
        }
        }
    }

    // MARK: - Helpers

    private func firstImage(_ post: PostView) -> EmbedImage? {
        if case .images(let imgs) = post.embed { return imgs.images.first }
        if case .recordWithMedia(let rwm) = post.embed,
           case .images(let imgs) = rwm.media { return imgs.images.first }
        return nil
    }

    private func hasImages(_ post: PostView) -> Bool { firstImage(post) != nil }

    // MARK: - Data Loading

    private func load(loadMore: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let home = try await ATProtocolClient.shared.getTimeline(
                limit: 50, cursor: loadMore ? timelineCursor : nil
            )
            timelineCursor = home.cursor

            let discover = try? await ATProtocolClient.shared.getFeed(
                uri: discoverURI, limit: 50, cursor: loadMore ? discoverCursor : nil
            )
            if let discover { discoverCursor = discover.cursor }

            let all = (home.feed + (discover?.feed ?? [])).filter { hasImages($0.post) }

            if loadMore {
                let existingUris = Set(posts.map { $0.post.uri })
                posts.append(contentsOf: all.filter { !existingUris.contains($0.post.uri) })
            } else {
                var seen = Set<String>()
                posts = all.filter { seen.insert($0.post.uri).inserted }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Gallery Card

struct GalleryCardView: View {
    let post: PostView
    let seenURIs: Set<String>

    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var isReposted: Bool = false
    @State private var repostCount: Int = 0
    @State private var showRepostSheet = false
    @State private var lightboxPresentation: LightboxPresentation? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full-width image(s) — tap opens lightbox
            imageSection

            // Metadata — tap navigates to conversation
            VStack(alignment: .leading, spacing: 8) {
                // Author strip
                HStack(spacing: 8) {
                    AvatarView(url: post.author.avatar, size: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.author.name)
                            .font(.inter(13, weight: .semibold))
                            .foregroundStyle(Color.nbBlack)
                            .lineLimit(1)
                        Text("@\(post.author.handle)")
                            .font(.inter(11))
                            .foregroundStyle(Color.nbBlack.opacity(0.5))
                    }
                    Spacer()
                    Text(post.relativeTime)
                        .font(.inter(11))
                        .foregroundStyle(Color.nbBlack.opacity(0.4))
                }

                // Action row
                HStack(spacing: 20) {
                    // Reply count (no action — tap card to open conversation)
                    Label("\(post.replyCount ?? 0)", systemImage: "bubble.left")
                        .font(.inter(12))
                        .foregroundStyle(Color.nbBlack.opacity(0.5))

                    // Repost
                    Button { showRepostSheet = true } label: {
                        Label("\(repostCount)", systemImage: "arrow.2.squarepath")
                            .font(.inter(12))
                            .foregroundStyle(isReposted ? Color.nbLime : Color.nbBlack.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: isReposted)

                    // Like
                    Button { toggleLike() } label: {
                        Label("\(likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                            .font(.inter(12))
                            .foregroundStyle(isLiked ? Color.nbAccent : Color.nbBlack.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .medium), trigger: isLiked)

                    Spacer()
                }
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture {
                store.navigationPath.append(PostDestination(uri: post.uri, post: post))
            }
        }
        .background(Color.nbWhite)
        .nbBorder()
        .nbShadow()
        .onAppear {
            syncState()
            markSeen()
        }
        .confirmationDialog("Repost Options", isPresented: $showRepostSheet) {
            Button(isReposted ? "Undo Repost" : "Repost") { toggleRepost() }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(item: $lightboxPresentation) { pres in
            LightboxView(images: pres.images, startIndex: pres.startIndex)
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        if case .images(let imgs) = post.embed {
            imageGrid(imgs.images)
        } else if case .recordWithMedia(let rwm) = post.embed,
                  case .images(let imgs) = rwm.media {
            imageGrid(imgs.images)
        }
    }

    private func imageGrid(_ images: [EmbedImage]) -> some View {
        Group {
            if images.count == 1 {
                singleImage(images[0], allImages: images)
            } else {
                LazyVGrid(columns: [.init(.flexible(), spacing: 2), .init(.flexible(), spacing: 2)], spacing: 2) {
                    ForEach(Array(images.prefix(4).enumerated()), id: \.element.id) { index, img in
                        AsyncImage(url: URL(string: img.fullsize)) { phase in
                            switch phase {
                            case .success(let i): i.resizable().scaledToFill()
                            default: Color.nbBorder.opacity(0.3)
                            }
                        }
                        // Both width and height must be constrained before .clipped()
                        // otherwise scaledToFill expands past the column boundary
                        .frame(maxWidth: .infinity, minHeight: 140, maxHeight: 140)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            lightboxPresentation = LightboxPresentation(images: Array(images), startIndex: index)
                        }
                    }
                }
                .clipped() // belt-and-suspenders: clip the grid itself too
            }
        }
    }

    private func singleImage(_ img: EmbedImage, allImages: [EmbedImage]) -> some View {
        AsyncImage(url: URL(string: img.fullsize)) { phase in
            switch phase {
            case .success(let i):
                i.resizable().scaledToFit()
            default:
                Color.nbBorder.opacity(0.3)
                    .frame(height: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottomLeading) {
            if !img.alt.isEmpty {
                Text(img.alt)
                    .font(.inter(11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .padding(8)
                    .lineLimit(2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            lightboxPresentation = LightboxPresentation(images: allImages, startIndex: 0)
        }
    }

    private func markSeen() {
        guard !seenURIs.contains(post.uri) else { return }
        modelContext.insert(SeenPost(uri: post.uri, likeCount: post.likeCount ?? 0, repostCount: post.repostCount ?? 0))
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

// MARK: - Lightbox presentation carrier
// Using fullScreenCover(item:) guarantees the images array is captured
// in the item itself, avoiding the stale-closure issue of isPresented + separate @State.
struct LightboxPresentation: Identifiable {
    let id = UUID()
    let images: [EmbedImage]
    let startIndex: Int
}
