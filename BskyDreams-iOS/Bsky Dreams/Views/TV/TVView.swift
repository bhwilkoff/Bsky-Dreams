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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.nbReadingSerif) private var readingSerif
    /// TV's measured size — picks the companion split's axis (§10.13).
    @State private var tvSize: CGSize = .zero
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

    /// Full screen, the video runs under the Duo's vertical bar — keep the toggle clear of it.
    private var windowTrailingInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.right ?? 0
    }

    var body: some View {
        Group {
            if showSelector {
                topicSelectorView
            } else if showsCompanion {
                companionSplit
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
        .onGeometryChange(for: CGSize.self) { $0.size } action: { tvSize = $0 }
        #if DEBUG
        // Device-test door: skip the topic picker (see DebugLaunchDoors, AppStore.swift).
        .task {
            if ProcessInfo.processInfo.environment["BSKY_TV_AUTOSTART"] != nil, showSelector {
                await startTV()
            }
        }
        #endif
        // No color scheme override — topicSelectorView uses adaptive tokens;
        // videoFeedView is always on black so it works in both modes.
    }

    // MARK: - Open iPhone Duo: the video and its conversation (iOS-DESIGN §10.13)

    /// TV has the whole inner display (no second column): pair the video with its
    /// conversation, so watching leads into the discussion rather than the next clip.
    private var showsCompanion: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
            && !store.secondaryColumnVisible && !videos.isEmpty && !store.tvFullScreen
    }

    /// Wider than tall (book pose) → side by side; taller than wide (upright, tabletop) →
    /// video on top, conversation below. The same layout in every pose; only the axis
    /// follows the shape. The system puts the divider on the fold.
    @ViewBuilder
    private var companionSplit: some View {
        let stacked = tvSize.height > tvSize.width
        let video = videoFeedView
        if #available(iOS 27.1, *) {
            ArrangementView {
                video.splitArrangementLayoutRatio(minHorizontal: 0.4, idealHorizontal: 0.5,
                                                  minVertical: 0.4, idealVertical: 0.5)
            } secondary: {
                videoConversation
            }
            .arrangementViewStyle(.split.axes(stacked ? .vertical : .horizontal))
            // TV's bar stays hidden (the video has TOPICS); also keeps the conversation's
            // title from surfacing in it.
            .toolbarVisibility(.hidden, for: .navigationBar)
        } else if stacked {
            VStack(spacing: 0) { video; Divider(); videoConversation }
        } else {
            HStack(spacing: 0) { video; Divider(); videoConversation }
        }
    }

    /// No NavigationStack of its own: TV already sits in its tab's stack, and a stack
    /// nested in a stack is ignored (its title leaked into TV's bar on device). Opening a
    /// reply or profile from here pushes onto TV's stack — full width, the video pauses,
    /// Back returns to the video and its conversation.
    @ViewBuilder
    private var videoConversation: some View {
        if currentIndex < videos.count {
            let post = videos[currentIndex]
            ThreadView(uri: post.uri, initialPost: post)
                .id(post.uri)   // follows the video on screen
                .environment(\.playingPostURI, post.uri)   // the clip is already playing
                .environment(\.nbIsPushed, true)            // TV owns "back to topics"; no Close
        } else {
            Color.nbBackground
        }
    }

    // MARK: - Topic Selector

    private var topicSelectorView: some View {
        ZStack {
            Color.nbBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // A hero in the post-colors language (§11).
                        ZStack(alignment: .bottomLeading) {
                            NBContentField(url: nil, tone: .deep)
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Video from the folks on Bluesky, one clip at a time. Swipe up for the next one.")
                                    .font(nbReadingFace(21, weight: .semibold, serif: readingSerif))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                Label("BSKY TV", systemImage: "play.tv.fill")
                                    .font(.syne(12, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            .padding(20)
                        }
                        .frame(maxWidth: .infinity, minHeight: 116, alignment: .bottomLeading)
                        .clipped()
                        .nbBorder()
                        .nbShadow(size: 4)
                        .padding(.top, 16)

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
                                            .foregroundStyle(selectedTopic == topic ? Color.nbLabel(on: .nbAccent) : Color.nbBlack)
                                            .padding(.vertical, 9)
                                            .frame(maxWidth: .infinity)
                                            .background(selectedTopic == topic ? Color.nbAccent : Color.nbWhite)
                                            .nbBorder()
                                            .nbShadow(size: 2)
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
                            .background(Color.nbWhite)
                            .nbBorder(customSearch.isEmpty ? Color.nbBlack : Color.nbAccent)
                            .nbShadow()
                        }

                        // Adult content toggle
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("HIDE ADULT CONTENT")
                                    .font(.syne(12, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundStyle(Color.nbBlack)
                                Text("Hides posts labeled explicit or adult")
                                    .font(.inter(11))
                                    .foregroundStyle(Color.nbTextTertiary)
                            }
                            Spacer()
                            // Empty-label Toggle stretches and squeezed the title onto 2 lines.
                            Toggle("Hide adult content", isOn: $hideAdult)
                                .labelsHidden()
                                .fixedSize()
                                .tint(Color.nbAccent)
                        }
                        .padding(12)
                        .background(Color.nbWhite)
                        .nbBorder()
                        .nbShadow()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                if let err = errorMessage {
                    NBErrorBanner(message: err, onDismiss: { errorMessage = nil })
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
                    .nbBorder()
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
                    Text("Try a different topic or word")
                        .font(.inter(14))
                        .foregroundStyle(.white.opacity(0.5))
                    Button("← Back to Topics") { goToSelector() }
                        .font(.syne(13, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.nbAccentLegible)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.nbAccent, lineWidth: 2))
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
                                isMuted: $isMuted,
                                // Beside its conversation the video doesn't reach the bar.
                                trailingInset: showsCompanion ? 0 : windowTrailingInset
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
                .onChange(of: scrollPositionID) { old, id in
                    let idx = id ?? 0
                    // Haptic when advancing to a new video (swipe or auto-advance)
                    // Only for a visible TV: a hidden tab lays out at zero size, where the
                    // paging position can churn without any swipe.
                    if let oldID = old, oldID != id, tvSize.height > 1 { Haptics.selection() }
                    playVideo(at: idx)
                    if idx < videos.count {
                        markVideoSeen(videos[idx])
                    }
                }
            }

            // Back to topics, and full screen ⇄ conversation: glass over the video (§11).
            HStack {
                NBGlassCapsule(title: "Topics", systemImage: "chevron.left", height: 44) { goToSelector() }
                    .accessibilityLabel("Back to topics")
                    .padding(.leading, 16)
                    .padding(.top, backButtonTopPadding)
                Spacer()
                // Open Duo: full screen ⇄ with the conversation (§10.13). Remembered.
                if horizontalSizeClass == .regular && verticalSizeClass == .regular {
                    NBGlassCapsule(title: store.tvFullScreen ? "Conversation" : "Full Screen",
                                   systemImage: store.tvFullScreen ? "rectangle.split.2x1"
                                                                   : "arrow.up.left.and.arrow.down.right",
                                   height: 44) {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            store.tvFullScreen.toggle()
                        }
                    }
                    .accessibilityLabel(store.tvFullScreen ? "Show the conversation beside the video"
                                                           : "Watch full screen")
                    .padding(.trailing, store.tvFullScreen ? windowTrailingInset + 16 : 16)
                    .padding(.top, backButtonTopPadding)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { playVideo(at: currentIndex) }
        .onDisappear {
            player.pause()
            // Hand audio back: otherwise music/podcasts the TV interrupted stay paused.
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        // Only OUR item finishing advances TV — inline feed videos post the same notification.
        .onReceive(NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification)) { note in
            guard let item = note.object as? AVPlayerItem, item === player.currentItem else { return }
            // Auto-advance to the next video when the current one finishes
            let next = currentIndex + 1
            if next < videos.count {
                // Haptic is emitted by the scrollPositionID onChange handler below
                if reduceMotion {
                    scrollPositionID = next
                } else {
                    withAnimation { scrollPositionID = next }
                }
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
                    ? "No videos in your timeline right now."
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
    /// The window's trailing inset when the video reaches that edge (the Duo's vertical
    /// bar) — keeps the overlay's buttons clear of it.
    var trailingInset: CGFloat = 0

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
                    CachedImage(url: url, maxPixelSize: 900) { phase in
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
                    .padding(.trailing, trailingInset)
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
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.4), lineWidth: 1))
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
            if pressing && !is2xSpeed { Haptics.light() }  // engage 2x hold
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
    @State private var likeURI: String? = nil
    @State private var likeCount = 0
    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(\.navColumn) private var navColumn

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: 16) {
                // Who and what (left)
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()
                    Button {
                        store.push(ProfileDestination(actor: post.author.did), column: navColumn)
                    } label: {
                        HStack(spacing: 10) {
                            AvatarView(url: post.author.avatar, size: 40)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(post.author.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("@\(post.author.handle)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if !post.record.text.isEmpty {
                        Text(post.record.text)
                            .nbReadingFont(16)
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .onTapGesture { store.openPost(uri: post.uri, post: post, column: navColumn) }
                    }
                }

                Spacer(minLength: 0)

                // Actions (right): Liquid Glass over the video (§11).
                NBGlassGroup(spacing: 14) {
                    VStack(spacing: 14) {
                        Spacer()
                        NBGlassButton(label: "Open conversation", systemImage: "text.bubble", size: 50) {
                            store.openPost(uri: post.uri, post: post, column: navColumn)
                        }
                        NBGlassButton(label: isMuted ? "Unmute" : "Mute",
                                      systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                      size: 50) {
                            isMuted.toggle()
                            if isActive { player.isMuted = isMuted }
                        }
                        NBGlassButton(label: SavedPosts.shared.contains(post.uri) ? "Remove from Saved" : "Save for Later",
                                      systemImage: SavedPosts.shared.contains(post.uri) ? "bookmark.fill" : "bookmark",
                                      size: 50) {
                            Haptics.light()
                            SavedPosts.shared.toggle(post.uri)
                        }
                        VStack(spacing: 4) {
                            NBGlassButton(label: isLiked ? "Unlike, \(likeCount)" : "Like, \(likeCount)",
                                          systemImage: isLiked ? "heart.fill" : "heart", size: 50,
                                          tint: isLiked ? Color(hex: "#FF2D55") : .white,
                                          action: toggleLike)
                            Text(nbCompactCount(likeCount))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 48)
        }
        .onAppear {
            isLiked = post.viewer?.like != nil
            likeURI = post.viewer?.like
            likeCount = post.likeCount ?? 0
        }
    }

    /// A real like (it used to only change the heart on screen).
    private func toggleLike() {
        guard let did = auth.session?.did else { return }
        let wasLiked = isLiked
        let prevCount = likeCount
        Haptics.medium()
        withAnimation { isLiked.toggle() }
        likeCount += isLiked ? 1 : -1
        Task {
            do {
                likeURI = try await ATProtocolClient.shared.setLiked(!wasLiked, post: post, recordURI: likeURI, did: did)
            } catch {
                isLiked = wasLiked
                likeCount = prevCount
                Haptics.error()
                store.showActionError(wasLiked ? "Couldn't undo that like." : "That like didn't go through.")
            }
        }
    }
}
