import SwiftUI
import SwiftData
import AVFoundation
import AVKit
import UIKit

// MARK: - TV View

struct TVView: View {
    private let discoverURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"
    private let videoFeedURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/thevids"

    private let topics = [
        "News", "Sports", "Music", "Art", "Gaming",
        "Science", "Tech", "Politics", "Nature", "Food",
        "Travel", "Comedy"
    ]

    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(\.toggleSidebar) private var toggleSidebar
    @Environment(\.modelContext) private var modelContext
    @Query private var seenPosts: [SeenPost]

    private var seenURIs: Set<String> { Set(seenPosts.map { $0.uri }) }
    private let seenMaxAge: TimeInterval = 7 * 24 * 3600

    // Selector
    @State private var showSelector = true
    @State private var selectedTopic: String? = nil
    @State private var customSearch = ""
    @State private var hideAdult = true

    // Feed
    @State private var videos: [PostView] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var timelineCursor: String?
    @State private var discoverCursor: String?

    // Single shared player — physically impossible for more than one audio stream to play
    @State private var player = AVPlayer()
    @State private var isMuted = false
    // scrollPosition(id:) gives the settled page index; nil until first page settles
    @State private var scrollPositionID: Int? = nil

    private var currentIndex: Int { scrollPositionID ?? 0 }

    /// Safe area top + 8pt margin for the back-to-topics button in videoFeedView.
    /// videoFeedView's ZStack uses .ignoresSafeArea() so we must account for the
    /// Dynamic Island / notch manually.
    private var backButtonTopPadding: CGFloat {
        let safeTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 0
        return max(safeTop + 8, 16)
    }

    var body: some View {
        Group {
            if showSelector {
                topicSelectorView
            } else {
                videoFeedView
                    .toolbarVisibility(.hidden, for: .navigationBar)
                    .gesture(
                        DragGesture(minimumDistance: 40, coordinateSpace: .global)
                            .onEnded { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                // Strong horizontal right swipe → back to topic selector
                                if dx > 80 && abs(dx) > abs(dy) * 2 {
                                    goToSelector()
                                }
                            }
                    )
            }
        }
        // No color scheme override — topicSelectorView uses adaptive tokens;
        // videoFeedView is always on black so it works in both modes.
    }

    // MARK: - Topic Selector

    private var topicSelectorView: some View {
        ZStack {
            Color.nbBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.nbAccent)
                    Text("BSKY TV")
                        .font(.syne(28, weight: .bold))
                        .foregroundStyle(Color.nbBlack)
                        .tracking(4)
                    Text("Select a topic or start browsing your feed")
                        .font(.inter(13))
                        .foregroundStyle(Color.nbTextSecondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 28)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Topic chips
                        VStack(alignment: .leading, spacing: 12) {
                            Text("BROWSE BY TOPIC")
                                .font(.syne(10))
                                .tracking(2)
                                .foregroundStyle(Color.nbTextTertiary)

                            LazyVGrid(
                                columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())],
                                spacing: 8
                            ) {
                                ForEach(topics, id: \.self) { topic in
                                    Button {
                                        selectedTopic = selectedTopic == topic ? nil : topic
                                        customSearch = ""
                                    } label: {
                                        Text(topic.uppercased())
                                            .font(.syne(11, weight: .bold))
                                            .tracking(0.5)
                                            .foregroundStyle(Color.nbBlack)
                                            .padding(.vertical, 9)
                                            .frame(maxWidth: .infinity)
                                            .background(selectedTopic == topic ? Color.nbAccent : Color.nbBlack.opacity(0.06))
                                            .overlay(Rectangle().strokeBorder(
                                                selectedTopic == topic ? Color.clear : Color.nbBorder,
                                                lineWidth: 1
                                            ))
                                    }
                                }
                            }
                        }

                        // Custom search
                        VStack(alignment: .leading, spacing: 12) {
                            Text("OR SEARCH FOR A TOPIC")
                                .font(.syne(10))
                                .tracking(2)
                                .foregroundStyle(Color.nbTextTertiary)

                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Color.nbTextTertiary)
                                    .font(.system(size: 14))
                                TextField(
                                    "",
                                    text: $customSearch,
                                    prompt: Text("e.g. cats, skiing, jazz…").foregroundStyle(Color.nbTextTertiary)
                                )
                                .font(.inter(15))
                                .foregroundStyle(Color.nbBlack)
                                .tint(Color.nbAccent)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: customSearch) { _, val in
                                    if !val.isEmpty { selectedTopic = nil }
                                }
                                .submitLabel(.search)
                                .onSubmit { Task { await startTV() } }

                                if !customSearch.isEmpty {
                                    Button { customSearch = "" } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color.nbTextTertiary)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.nbBlack.opacity(0.05))
                            .overlay(Rectangle().strokeBorder(
                                customSearch.isEmpty ? Color.nbBorder : Color.nbAccent.opacity(0.7),
                                lineWidth: 1
                            ))
                        }

                        // Adult content toggle
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("HIDE ADULT CONTENT")
                                    .font(.syne(12, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundStyle(Color.nbBlack)
                                Text("Filters posts labeled as explicit or adult")
                                    .font(.inter(11))
                                    .foregroundStyle(Color.nbTextTertiary)
                            }
                            Spacer()
                            Toggle("", isOn: $hideAdult)
                                .tint(Color.nbAccent)
                        }
                        .padding(12)
                        .background(Color.nbBlack.opacity(0.05))
                        .overlay(Rectangle().strokeBorder(Color.nbBorder, lineWidth: 1))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.inter(12))
                        .foregroundStyle(.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                Button {
                    Task { await startTV() }
                } label: {
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.fill").font(.system(size: 13))
                        }
                        Text(isLoading ? "LOADING…" : "START TV")
                            .font(.syne(15, weight: .bold))
                            .tracking(2)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.nbAccent)
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                }
                .disabled(isLoading)
                .padding(.horizontal, 20)
                .padding(.bottom, 44)
            }

        }
        .nbNavBar(title: "BSKY TV", leading: { NBHamburger() })
    }

    // MARK: - Video Feed

    private var videoFeedView: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            if videos.isEmpty && isLoading {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text("Loading videos…")
                        .font(.inter(14))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if videos.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "play.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("No Videos Found")
                        .font(.syne(20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Try a different topic or search term")
                        .font(.inter(14))
                        .foregroundStyle(.white.opacity(0.5))
                    Button("← Back to Topics") { goToSelector() }
                        .font(.syne(13, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.nbAccent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .overlay(Rectangle().strokeBorder(Color.nbAccent, lineWidth: 2))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(videos.enumerated()), id: \.offset) { i, post in
                            TVVideoCell(
                                post: post,
                                index: i,
                                currentIndex: currentIndex,
                                player: player,
                                isMuted: $isMuted
                            )
                            .id(i)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .onAppear {
                                if i >= videos.count - 3 {
                                    Task { await loadMore() }
                                }
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollPositionID)
                .scrollIndicators(.hidden)
                .ignoresSafeArea()
                .onChange(of: scrollPositionID) { _, id in
                    let idx = id ?? 0
                    playVideo(at: idx)
                    if idx < videos.count {
                        markVideoSeen(videos[idx])
                    }
                }
            }

            // Back-to-topics button — top-left, clear safe area for Dynamic Island
            HStack {
                Button { goToSelector() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text("TOPICS")
                            .font(.syne(11, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundStyle(Color.nbBlack)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.nbWhite)
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                    .background(Color.nbBlack.offset(x: 2, y: 2))
                }
                .buttonStyle(.plain)
                .padding(.leading, 16)
                .padding(.top, backButtonTopPadding)
                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear { playVideo(at: currentIndex) }
        .onDisappear { player.pause() }
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { _ in
            // Auto-advance to the next video when the current one finishes
            let next = currentIndex + 1
            if next < videos.count {
                withAnimation { scrollPositionID = next }
            }
        }
    }

    // MARK: - Player management

    /// Loads the HLS item at `index` into the single shared player and starts playback.
    /// Mutes briefly on item swap to prevent audio stutter while buffering.
    private func playVideo(at index: Int) {
        guard index >= 0, index < videos.count else { return }
        guard let urlString = videoURLString(for: videos[index]),
              let url = URL(string: urlString) else { return }
        player.pause()
        // Mute momentarily during item swap to eliminate audio pop/stutter
        player.isMuted = true
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 5
        player.automaticallyWaitsToMinimizeStalling = true
        player.replaceCurrentItem(with: item)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        // Restore user's mute preference after buffer stabilises (~400ms)
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run { player.isMuted = isMuted }
        }
    }

    private func goToSelector() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        scrollPositionID = nil
        showSelector = true
    }

    private func videoURLString(for post: PostView) -> String? {
        if case .video(let v) = post.embed { return v.playlist }
        if case .recordWithMedia(let rwm) = post.embed,
           case .video(let v) = rwm.media { return v.playlist }
        return nil
    }

    // MARK: - Data loading

    private func startTV() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let query = customSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (selectedTopic ?? "")
            : customSearch.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            var allPosts: [PostView] = []
            if query.isEmpty {
                // Fetch home timeline, discover, AND the official trending video feed in parallel
                async let homeResult = ATProtocolClient.shared.getTimeline(limit: 50)
                async let discoverResult = try? ATProtocolClient.shared.getFeed(uri: discoverURI, limit: 50)
                async let videoResult = try? ATProtocolClient.shared.getFeed(uri: videoFeedURI, limit: 50)

                let home = try await homeResult
                let discover = await discoverResult
                let videoFeed = await videoResult
                timelineCursor = home.cursor
                if let discover { discoverCursor = discover.cursor }
                allPosts = (home.feed + (discover?.feed ?? []) + (videoFeed?.feed ?? [])).map { $0.post }
            } else {
                let tagResp = try? await ATProtocolClient.shared.searchPosts(q: "#\(query)", sort: "top", limit: 50)
                let plainResp = try? await ATProtocolClient.shared.searchPosts(q: query, sort: "top", limit: 50)
                allPosts = (tagResp?.posts ?? []) + (plainResp?.posts ?? [])
            }

            let filtered = applyFilters(allPosts)
            if filtered.isEmpty {
                errorMessage = query.isEmpty
                    ? "No videos found in your timeline right now."
                    : "No videos matched \"\(query)\". Try a different topic."
            } else {
                videos = filtered
                scrollPositionID = nil
                showSelector = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard !isLoading else { return }
        let query = customSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (selectedTopic ?? "")
            : customSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }
        let home = try? await ATProtocolClient.shared.getTimeline(limit: 50, cursor: timelineCursor)
        let discover = try? await ATProtocolClient.shared.getFeed(uri: discoverURI, limit: 50, cursor: discoverCursor)
        let videoFeed = try? await ATProtocolClient.shared.getFeed(uri: videoFeedURI, limit: 50)
        if let home { timelineCursor = home.cursor }
        if let discover { discoverCursor = discover.cursor }
        let newPosts = ((home?.feed ?? []) + (discover?.feed ?? []) + (videoFeed?.feed ?? [])).map { $0.post }
        let existing = Set(videos.map { $0.uri })
        videos.append(contentsOf: applyFilters(newPosts).filter { !existing.contains($0.uri) })
    }

    private func applyFilters(_ posts: [PostView]) -> [PostView] {
        var seen = Set<String>()
        return posts.filter { post in
            guard videoURLString(for: post) != nil else { return false }
            if hideAdult, let labels = post.labels {
                let adultVals = ["porn", "sexual", "nudity", "graphic-media", "adult"]
                if labels.contains(where: { adultVals.contains($0.val) }) { return false }
            }
            // Filter out already-seen videos unless the user has bypassed filtering
            if !store.feedSeenBypass && seenURIs.contains(post.uri) { return false }
            return seen.insert(post.uri).inserted
        }
    }

    /// Mark a video as seen in SwiftData (unified with feed/gallery seen tracking).
    private func markVideoSeen(_ post: PostView) {
        guard !seenURIs.contains(post.uri) else { return }
        modelContext.insert(SeenPost(uri: post.uri))
        // Prune entries older than 7 days
        let cutoff = Date().addingTimeInterval(-seenMaxAge)
        seenPosts.filter { $0.seenAt < cutoff }.forEach { modelContext.delete($0) }
        // Debounced cloud sync
        if let did = auth.session?.did {
            let recentURIs = seenPosts.map { $0.uri } + [post.uri]
            store.scheduleSeenSync(uris: recentURIs, did: did)
        }
    }
}

// MARK: - Video Cell
// Displays the shared player when active, or a static thumbnail when not.

struct TVVideoCell: View {
    let post: PostView
    let index: Int
    let currentIndex: Int
    let player: AVPlayer
    @Binding var isMuted: Bool

    @State private var showOverlay = true
    @State private var is2xSpeed = false

    private var isActive: Bool { index == currentIndex }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isActive {
                // Active cell renders the shared player (only one ever exists)
                AVPlayerFillView(player: player)
                    .ignoresSafeArea()
            } else {
                // Inactive cells show a static thumbnail — no player, no audio
                if let thumb = videoThumbnail, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFit()
                        default: Color.black
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            if showOverlay {
                TVOverlayView(post: post, isMuted: $isMuted, player: player, isActive: isActive)
            }

            // 2x speed indicator
            if is2xSpeed {
                VStack {
                    HStack {
                        Spacer()
                        Text("2×")
                            .font(.syne(16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.6))
                            .overlay(Rectangle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                            .padding(.trailing, 16)
                            .padding(.top, 60)
                    }
                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        // Tap toggles overlay — does NOT block the scroll gesture
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) { showOverlay.toggle() }
        }
        // Long press activates 2x speed for as long as the finger is held
        .onLongPressGesture(minimumDuration: 0.3, maximumDistance: 20, pressing: { pressing in
            guard isActive else { return }
            is2xSpeed = pressing
            player.rate = pressing ? 2.0 : 1.0
        }, perform: {})
    }

    private var videoThumbnail: String? {
        if case .video(let v) = post.embed { return v.thumbnail }
        if case .recordWithMedia(let rwm) = post.embed,
           case .video(let v) = rwm.media { return v.thumbnail }
        return nil
    }
}

// MARK: - AVPlayerLayer view (resizeAspect — correct aspect ratio with black bars)

struct AVPlayerFillView: UIViewRepresentable {
    let player: AVPlayer

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resizeAspect
            playerLayer.backgroundColor = UIColor.black.cgColor
        }
        required init?(coder: NSCoder) { fatalError() }
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }
}

// MARK: - TV Overlay

struct TVOverlayView: View {
    let post: PostView
    @Binding var isMuted: Bool
    let player: AVPlayer
    let isActive: Bool

    @State private var isLiked = false
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            HStack(alignment: .bottom) {
                // Post info (left)
                VStack(alignment: .leading, spacing: 6) {
                    Spacer()
                    Button {
                        store.navigationPath.append(ProfileDestination(actor: post.author.did))
                    } label: {
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
                    }
                    .buttonStyle(.plain)

                    if !post.record.text.isEmpty {
                        Text(post.record.text)
                            .font(.inter(13))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Action buttons (right)
                VStack(spacing: 20) {
                    Spacer()

                    // Pop-out: open post thread
                    Button {
                        store.navigationPath.append(PostDestination(uri: post.uri, post: post))
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }

                    // Mute — controls the shared player directly
                    Button {
                        isMuted.toggle()
                        if isActive { player.isMuted = isMuted }
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }

                    // Like
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
            .padding(.bottom, 48)
        }
    }
}
