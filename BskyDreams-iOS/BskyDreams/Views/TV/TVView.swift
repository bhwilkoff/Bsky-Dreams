import SwiftUI
import AVFoundation
import AVKit

// TikTok-style video feed
struct TVView: View {
    @State private var videos: [PostView] = []
    @State private var currentIndex = 0
    @State private var isLoading = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if videos.isEmpty {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView().tint(.white)
                            Text("Loading videos...")
                                .font(.inter(14))
                                .foregroundStyle(.white)
                        }
                    } else {
                        ContentUnavailableView {
                            Label("No Videos", systemImage: "play.slash")
                        }
                        .preferredColorScheme(.dark)
                    }
                } else {
                    // Video player stack
                    TabView(selection: $currentIndex) {
                        ForEach(Array(videos.enumerated()), id: \.offset) { i, post in
                            TVVideoPlayer(post: post)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .tag(i)
                                .onAppear {
                                    if i >= videos.count - 3 {
                                        Task { await loadMore() }
                                    }
                                }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea()
                }
            }
        }
        .ignoresSafeArea()
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Seed from home timeline + discover
            async let home = ATProtocolClient.shared.getTimeline(limit: 50)
            async let discover = ATProtocolClient.shared.getFeed(
                uri: "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot",
                limit: 50
            )
            let (homeResp, discoverResp) = try await (home, discover)
            let allPosts = (homeResp.feed + discoverResp.feed).map { $0.post }
            videos = allPosts.filter { hasVideo($0) }.removingDuplicates()
        } catch {}
    }

    private func loadMore() async {
        // In a real app, maintain cursors and paginate
        await load()
    }

    private func hasVideo(_ post: PostView) -> Bool {
        if case .video = post.embed { return true }
        if case .recordWithMedia(let rwm) = post.embed,
           case .video = rwm.media { return true }
        return false
    }
}

// MARK: - Individual Video Player

struct TVVideoPlayer: View {
    let post: PostView
    @State private var player: AVPlayer?
    @State private var isMuted = false
    @State private var showOverlay = true

    var body: some View {
        ZStack {
            // Video or thumbnail
            if let playlist = videoURL, let url = URL(string: playlist) {
                VideoPlayer(player: player ?? AVPlayer())
                    .onAppear {
                        player = AVPlayer(url: url)
                        player?.play()
                        player?.isMuted = isMuted
                    }
                    .onDisappear {
                        player?.pause()
                        player = nil
                    }
            } else if let thumb = videoThumbnail {
                AsyncImage(url: URL(string: thumb)) { img in
                    img.resizable().scaledToFill()
                } placeholder: { Color.black }
            } else {
                Color.black
            }

            // Overlay
            if showOverlay {
                TVOverlayView(post: post, isMuted: $isMuted)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showOverlay.toggle()
            }
        }
    }

    private var videoURL: String? {
        if case .video(let v) = post.embed { return v.playlist }
        if case .recordWithMedia(let rwm) = post.embed,
           case .video(let v) = rwm.media { return v.playlist }
        return nil
    }

    private var videoThumbnail: String? {
        if case .video(let v) = post.embed { return v.thumbnail }
        if case .recordWithMedia(let rwm) = post.embed,
           case .video(let v) = rwm.media { return v.thumbnail }
        return nil
    }
}

// MARK: - TV Overlay

struct TVOverlayView: View {
    let post: PostView
    @Binding var isMuted: Bool
    @State private var isLiked = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Gradient
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Right action column
                HStack(alignment: .bottom) {
                    // Post info
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            AvatarView(url: post.author.avatar, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(post.author.name)
                                    .font(.inter(14, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("@\(post.author.handle)")
                                    .font(.inter(12))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }

                        if !post.record.text.isEmpty {
                            Text(post.record.text)
                                .font(.inter(13))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: 20) {
                        Button {
                            isMuted.toggle()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white)
                            }
                        }

                        Button {
                            withAnimation { isLiked.toggle() }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 28))
                                    .foregroundStyle(isLiked ? Color.nbAccent : .white)
                                Text("\(post.likeCount ?? 0)")
                                    .font(.inter(12))
                                    .foregroundStyle(.white)
                            }
                        }
                        .sensoryFeedback(.impact(weight: .medium), trigger: isLiked)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Dedup Helper

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension PostView: Hashable {}
