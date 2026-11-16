import SwiftUI
import Combine
import SwiftData

// MARK: - Stream (iOS-DESIGN §10.5)
//
// A screen saver you can step into. Two modes on one surface:
// - WATCHING: one post at a time as a pull quote — the largest type that fits, lines
//   revealed one by one, a slow color field drawn from the post itself, then a
//   "conversation beat" with what people are saying. A clock and a hairline of progress;
//   nothing else.
// - INTERACTING (tap): the post eases back, its actions appear, a filmstrip of recent and
//   upcoming posts lets you go back to the one you just missed, and the transport shows.
//   Double-tap likes, hold keeps a post up, swipe up opens its conversation beside it.
// Exploring never loses your place: anything open holds the clock, Resume continues the
// same post.

// MARK: - Data Models

private enum StreamSource: Hashable {
    case discover, following, saved, search(String), author(did: String, handle: String)
    var label: String {
        switch self {
        case .discover: "Discover"
        case .following: "Following"
        case .saved: "Saved"
        case .search(let q): q.isEmpty ? "Search" : q
        case .author(_, let handle): "@\(handle)"
        }
    }
    var icon: String {
        switch self {
        case .discover: "sparkles"
        case .following: "person.2"
        case .saved: "bookmark"
        case .search: "magnifyingglass"
        case .author: "person.crop.circle"
        }
    }
    /// Seen posts are skipped only in the endless feeds — a topic, a person or your saved
    /// posts are things you asked for.
    var skipsSeen: Bool { self == .discover || self == .following }
}

private enum StreamTheme: String, CaseIterable, Identifiable {
    case ambient, bold, paper
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ambient: "Ambient"
        case .bold: "Bold"
        case .paper: "Paper"
        }
    }
    var icon: String {
        switch self {
        case .ambient: "moon.stars"
        case .bold: "paintpalette"
        case .paper: "doc.richtext"
        }
    }
    var blurb: String {
        switch self {
        case .ambient: "Dark, and tinted by each post"
        case .bold: "The loud Bsky Dreams colors"
        case .paper: "Light, like a printed page"
        }
    }
}

private struct StreamLinkPresentation: Identifiable {
    let id = UUID()
    let card: ExternalCard
    let post: PostView?
}

/// What the explore panel beside the post shows.
private enum StreamExplore: Identifiable {
    case post(PostView)
    case profile(String)
    var id: String {
        switch self {
        case .post(let p): "post:\(p.uri)"
        case .profile(let a): "profile:\(a)"
        }
    }
}

/// One post, one scene. Images are steps inside the scene, followed (when it has
/// replies) by the conversation beat.
private struct StreamScene: Identifiable {
    let post: PostView
    let ordinal: Int
    let text: String
    let images: [EmbedImage]
    let link: ExternalCard?
    let video: VideoCard?
    let quote: PostView?

    var id: String { post.uri }
    var hasWords: Bool { !text.isEmpty || link != nil }
    var hasMedia: Bool { !images.isEmpty || video?.thumbnail != nil || link?.thumb != nil }
    var wordCount: Int {
        let parts: [String] = [text, link?.title ?? "", quote?.record.text ?? ""]
        return parts.reduce(0) { $0 + $1.split(whereSeparator: { $0.isWhitespace }).count }
    }
    var authorName: String {
        if let n = post.author.displayName, !n.isEmpty { return n }
        return post.author.handle
    }

    /// Width ÷ height of the media at `index` (nil if unknown).
    func aspect(_ index: Int) -> CGFloat? {
        if !images.isEmpty {
            let img = images[min(index, images.count - 1)]
            if let r = img.aspectRatio, r.width > 0, r.height > 0 { return CGFloat(r.width) / CGFloat(r.height) }
            return nil
        }
        if let r = video?.aspectRatio, r.width > 0, r.height > 0 { return CGFloat(r.width) / CGFloat(r.height) }
        if link?.thumb != nil { return 1.91 }
        return nil
    }

    /// A small still of the media (filmstrip, color, backdrop).
    var thumbURL: URL? {
        if let first = images.first { return URL(string: first.thumb) }
        if let t = video?.thumbnail { return URL(string: t) }
        if let t = link?.thumb { return URL(string: t) }
        return nil
    }

    /// Hashtags in the post, for "stream this topic".
    var hashtags: [String] {
        var tags: [String] = post.record.tags ?? []
        let ns = post.record.text as NSString
        if let regex = try? NSRegularExpression(pattern: "(?<![\\w#])#([\\p{L}\\p{N}_]{2,40})") {
            for m in regex.matches(in: post.record.text, range: NSRange(location: 0, length: ns.length)) {
                tags.append(ns.substring(with: m.range(at: 1)))
            }
        }
        var seen = Set<String>()
        return tags.filter { seen.insert($0.lowercased()).inserted }.prefix(3).map { $0 }
    }

    var shareURL: URL? {
        URL(string: "https://bsky.app/profile/\(post.author.handle)/post/\(post.rkey)")
    }
}

/// Elapsed time on the current step. Its own observable so only the progress line
/// re-renders ten times a second — not the scene.
@Observable @MainActor
private final class StreamClock {
    var elapsed: Double = 0
    var dwell: Double = 8
    var progress: Double { dwell > 0 ? min(1, elapsed / dwell) : 0 }
}

/// Likes, reposts and saves, shared by the scene, the double-tap and the filmstrip.
/// Optimistic with rollback, as everywhere else.
@Observable @MainActor
private final class StreamEngagement {
    struct State {
        var liked: Bool
        var likeURI: String?
        var likes: Int
        var reposted: Bool
        var repostURI: String?
        var reposts: Int
    }
    private(set) var states: [String: State] = [:]
    /// Saves are app-wide (`SavedPosts`): a post saved here shows in Saved and every menu.
    var saved: [String] { SavedPosts.shared.uris }

    func state(_ post: PostView) -> State {
        states[post.uri] ?? State(liked: post.viewer?.like != nil, likeURI: post.viewer?.like,
                                  likes: post.likeCount ?? 0, reposted: post.viewer?.repost != nil,
                                  repostURI: post.viewer?.repost, reposts: post.repostCount ?? 0)
    }

    func isSaved(_ uri: String) -> Bool { SavedPosts.shared.contains(uri) }

    func toggleSaved(_ uri: String) { SavedPosts.shared.toggle(uri) }

    func setLiked(_ on: Bool, post: PostView, did: String, onError: @escaping (String) -> Void) {
        let prev = state(post)
        guard prev.liked != on else { return }
        var next = prev
        next.liked = on
        next.likes += on ? 1 : -1
        states[post.uri] = next
        Task {
            do {
                let uri = try await ATProtocolClient.shared.setLiked(on, post: post, recordURI: prev.likeURI, did: did)
                states[post.uri]?.likeURI = uri
            } catch {
                states[post.uri] = prev
                onError(on ? "That like didn't go through." : "Couldn't undo that like.")
            }
        }
    }

    func setReposted(_ on: Bool, post: PostView, did: String, onError: @escaping (String) -> Void) {
        let prev = state(post)
        guard prev.reposted != on else { return }
        var next = prev
        next.reposted = on
        next.reposts += on ? 1 : -1
        states[post.uri] = next
        Task {
            do {
                let uri = try await ATProtocolClient.shared.setReposted(on, post: post, recordURI: prev.repostURI, did: did)
                states[post.uri]?.repostURI = uri
            } catch {
                states[post.uri] = prev
                onError(on ? "That repost didn't go through." : "Couldn't undo that repost.")
            }
        }
    }
}

/// The stream itself: what's playing, where you are in it, and whether the player is up.
/// It outlives any one view, because the views come and go: closing the iPhone Duo swaps
/// the sidebar shell for the tab bar, which rebuilds the Stream screen inside More. When
/// the player belonged to that screen, closing the Duo dropped you back on setup
/// (owner, device, 2026-11-16). The player is presented from the app's root instead
/// (MainAppView), so it plays straight through the fold.
@Observable @MainActor
final class StreamSession {
    static let shared = StreamSession()

    /// The full-screen player is up.
    var presented = false
    var streamingRequested = false
    /// Started on the open Duo (no rotate-to-landscape step); rotation never ends it.
    var startedWithoutRotation = false

    fileprivate var scenes: [StreamScene] = []
    fileprivate var currentIndex = 0
    fileprivate var step = 0
    fileprivate var isLoadingMore = false
    fileprivate var feedCursor: String? = nil
    fileprivate var source: StreamSource = .discover
    fileprivate var replies: [String: [PostView]] = [:]
    fileprivate var repliesRequested: Set<String> = []
    fileprivate var palettes: [String: [UIColor]] = [:]
    fileprivate var palettesRequested: Set<String> = []
    fileprivate var seenURISet: Set<String> = []
    fileprivate var errorMessage: String? = nil
    fileprivate let clock = StreamClock()
    fileprivate let engagement = StreamEngagement()
    fileprivate var userPaused = false
    fileprivate var explore: StreamExplore? = nil

    /// Something to stream, from anywhere in the app.
    enum Request { case author(did: String, handle: String), search(String), saved }

    /// Stream a person, a topic or your saved posts, starting now (profile, hashtag,
    /// search and Saved all offer this).
    func play(_ request: Request) {
        switch request {
        case .author(let did, let handle): source = .author(did: did, handle: handle)
        case .search(let q): source = .search(q)
        case .saved: source = .saved
        }
        scenes = []
        feedCursor = nil
        currentIndex = 0
        step = 0
        clock.elapsed = 0
        errorMessage = nil
        explore = nil
        userPaused = false
        begin()
    }

    /// Put the player up. Turning the phone is allowed (not required) while it plays.
    func begin() {
        streamingRequested = true
        startedWithoutRotation = true
        AppDelegate.streamingActive = true
        streamRefreshSupportedOrientations()
        presented = true
    }

    /// The player went away (closed, or the system dismissed it): undo what playing set up.
    func playerDismissed() {
        explore = nil
        UIApplication.shared.isIdleTimerDisabled = false
        AppDelegate.streamingActive = false
        streamingRequested = false
        startedWithoutRotation = false
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        streamRefreshSupportedOrientations()
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)) { _ in }
        }
    }
}

private func streamRefreshSupportedOrientations() {
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootVC = scene.windows.first?.rootViewController {
        rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

// MARK: - Color

private let streamPalette: [(bg: Color, lightText: Bool)] = [
    (Color(hex: "#FF5C35"), true),
    (Color(hex: "#0047FF"), true),
    (Color(hex: "#B8E04A"), false),
    (Color(hex: "#AF52DE"), true),
    (Color(hex: "#FF2D55"), true),
    (Color(hex: "#FF9500"), false),
    (Color(hex: "#34C759"), false),
]
private let streamPaletteHex = ["#FF5C35","#0047FF","#B8E04A","#AF52DE","#FF2D55","#FF9500","#34C759"]
private let lightTextHex: Set<String> = ["#FF5C35","#0047FF","#AF52DE","#FF2D55"]
private let paperColor = Color(hex: "#F3EFE6")
private let inkColor = Color(hex: "#161616")

/// A sampled color calmed for a theme (iOS-DESIGN §11).
private func themed(_ c: UIColor, _ theme: StreamTheme) -> Color {
    nbToned(c, theme == .paper ? .pale : .deep)
}

// MARK: - Text / URL Helpers

private func strippedOfURLs(_ text: String) -> String {
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    guard let detector else { return text }
    let nsText = text as NSString
    let range = NSRange(location: 0, length: nsText.length)
    let stripped = detector.stringByReplacingMatches(in: text, range: range, withTemplate: "")
    return stripped
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
}

private func isVideoURL(_ urlString: String) -> Bool {
    guard let host = URL(string: urlString)?.host?.lowercased() else { return false }
    let videoHosts = ["youtube.com", "youtu.be", "vimeo.com", "twitch.tv",
                      "tiktok.com", "dailymotion.com", "rumble.com", "video.bsky.app"]
    return videoHosts.contains { host == $0 || host.hasSuffix("." + $0) }
}

/// Post text in the reading typeface (system fonts, so emoji render; iOS-DESIGN §4.1, §11).
private func streamFont(_ size: CGFloat, weight: Font.Weight = .regular, serif: Bool) -> Font {
    nbReadingFace(size, weight: weight, serif: serif)
}

// MARK: - StreamView

struct StreamView: View {
    /// `.setup` is the Stream screen in the app; `.player` is the full-screen stream,
    /// presented by MainAppView so it survives the shell changing around it.
    enum Role { case setup, player }
    var role: Role = .setup
    private var session: StreamSession { StreamSession.shared }

    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store
    @Environment(NetworkMonitor.self) private var network
    @Environment(\.modelContext) private var modelContext
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale

    // Persisted settings
    @AppStorage("stream_duration")       private var streamDuration: Double = 8.0
    @AppStorage("stream_filter")         private var streamFilter: String  = "all"
    @AppStorage("stream_theme")          private var themeRaw: String      = StreamTheme.ambient.rawValue
    @AppStorage("stream_typeface")       private var typeface: String      = "serif"
    @AppStorage("stream_bg_mode")        private var streamBgMode: String  = "random"
    @AppStorage("stream_show_alt_text")  private var showAltText: Bool     = true
    @AppStorage("stream_show_metrics")   private var showMetrics: Bool     = true
    @AppStorage("stream_show_replies")   private var showReplies: Bool     = true
    @AppStorage("stream_show_clock")     private var showClock: Bool       = true
    // A screen saver keeps the screen on by default.
    @AppStorage("stream_prevent_sleep")  private var preventSleep: Bool    = true

    private var theme: StreamTheme { StreamTheme(rawValue: themeRaw) ?? .ambient }
    private var serif: Bool { typeface == "serif" }

    // Presentation
    private var isLandscape: Bool {
        get { session.presented }
        nonmutating set { session.presented = newValue }
    }
    private var streamingRequested: Bool {
        get { session.streamingRequested }
        nonmutating set { session.streamingRequested = newValue }
    }
    /// Started on the open iPhone Duo, where the inner display ignores interface
    /// orientation, so there is no "rotate to landscape" step (iOS-DESIGN §10). Rotation
    /// signals must not dismiss a stream started this way.
    private var startedWithoutRotation: Bool {
        get { session.startedWithoutRotation }
        nonmutating set { session.startedWithoutRotation = newValue }
    }
    /// The open Duo's inner display: regular in both dimensions, in every orientation.
    private var isOpenDuo: Bool { horizontalSizeClass == .regular && verticalSizeClass == .regular }

    // Content
    private var scenes: [StreamScene] {
        get { session.scenes }
        nonmutating set { session.scenes = newValue }
    }
    private var currentIndex: Int {
        get { session.currentIndex }
        nonmutating set { session.currentIndex = newValue }
    }
    private var step: Int {
        get { session.step }
        nonmutating set { session.step = newValue }
    }
    private var isLoadingMore: Bool {
        get { session.isLoadingMore }
        nonmutating set { session.isLoadingMore = newValue }
    }
    private var feedCursor: String? {
        get { session.feedCursor }
        nonmutating set { session.feedCursor = newValue }
    }
    private var source: StreamSource {
        get { session.source }
        nonmutating set { session.source = newValue }
    }
    private var replies: [String: [PostView]] {
        get { session.replies }
        nonmutating set { session.replies = newValue }
    }
    private var repliesRequested: Set<String> {
        get { session.repliesRequested }
        nonmutating set { session.repliesRequested = newValue }
    }
    private var palettes: [String: [UIColor]] {
        get { session.palettes }
        nonmutating set { session.palettes = newValue }
    }
    private var palettesRequested: Set<String> {
        get { session.palettesRequested }
        nonmutating set { session.palettesRequested = newValue }
    }
    private var seenURISet: Set<String> {
        get { session.seenURISet }
        nonmutating set { session.seenURISet = newValue }
    }
    private var errorMessage: String? {
        get { session.errorMessage }
        nonmutating set { session.errorMessage = newValue }
    }

    // Playback + interaction
    private var clock: StreamClock { session.clock }
    private var engagement: StreamEngagement { session.engagement }
    private var userPaused: Bool {
        get { session.userPaused }
        nonmutating set { session.userPaused = newValue }
    }
    @State private var touching = false
    @State private var direction: Int = 1
    @State private var controlsVisible = false
    @State private var controlsHideTask: Task<Void, Never>? = nil
    @State private var heartToken = 0
    @State private var stageSize: CGSize = .zero
    @State private var playerFold = FoldGeometry()

    // Overlays
    @State private var searchInput = ""
    @State private var showTopicPrompt = false
    @State private var linkPresentation: StreamLinkPresentation? = nil
    @State private var lightbox: LightboxPresentation? = nil
    private var explore: StreamExplore? {
        get { session.explore }
        nonmutating set { session.explore = newValue }
    }

    private let seenMaxAge: TimeInterval = 7 * 24 * 3600
    private let discoverURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"

    // MARK: - Body

    var body: some View {
        switch role {
        case .player: streamPlayer
        case .setup: setupBody
        }
    }

    private var setupBody: some View {
        setupScreen
            .nbNavBar(title: "STREAM", leading: { NBHamburger() })
            .onChange(of: streamFilter) { _, _ in resetScenes() }
            .onChange(of: source) { _, _ in resetScenes() }
            .task { await debugAutostart() }
    }

    private func refreshSupportedOrientations() { streamRefreshSupportedOrientations() }

    private func requestPortrait() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)) { _ in }
    }

    /// DEBUG launch doors (device testing): BSKY_STREAM_AUTOSTART=1 starts the stream;
    /// BSKY_STREAM_FILTER=all|text|images, BSKY_STREAM_THEME=ambient|bold|paper pick the
    /// content and look; BSKY_STREAM_EXPLORE=1 opens the first post's conversation;
    /// BSKY_STREAM_CONTROLS=1 shows the interacting mode; BSKY_STREAM_STEP=last jumps to the
    /// conversation beat.
    private func debugAutostart() async {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        guard env["BSKY_STREAM_AUTOSTART"] == "1", !isLandscape else { return }
        if let f = env["BSKY_STREAM_FILTER"] { streamFilter = f }
        if let t = env["BSKY_STREAM_THEME"] { themeRaw = t }
        if let t = env["BSKY_STREAM_TYPEFACE"] { typeface = t }
        try? await Task.sleep(for: .seconds(1))
        start()
        try? await Task.sleep(for: .seconds(5))
        if env["BSKY_STREAM_STEP"] == "last", let scene = currentScene {
            userPaused = true
            step = steps(scene) - 1
            updateDwell()
        }
        if env["BSKY_STREAM_CONTROLS"] == "1" { userPaused = true; showControls(autoHide: false) }
        if env["BSKY_STREAM_EXPLORE"] == "1", let scene = currentScene { openExplore(.post(scene.post)) }
        #endif
    }

    private func resetScenes() {
        scenes = []
        feedCursor = nil
        currentIndex = 0
        step = 0
        clock.elapsed = 0
        errorMessage = nil
        explore = nil
        if isLandscape { Task { await loadMore() } }
    }

    /// Show the player. It loads what it needs when it appears. No "turn your phone"
    /// step any more: the player lays out for portrait too, and turning the phone just
    /// gives it more room (iOS-DESIGN §10.5).
    private func start() { session.begin() }

    /// The player's first load (also when Stream was started from a profile, a tag…).
    private func loadIfNeeded() async {
        await loadSeenURIs()
        if scenes.isEmpty && !isLoadingMore { await loadMore() }
        updateDwell()
        prefetch(after: currentIndex)
    }

    // MARK: - Setup Screen

    private var setupScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                previewHero
                startButtons
                sourceSection
                lookSection
                paceSection
                optionsSection
            }
            .padding(16)
            .padding(.bottom, 24)
            .nbReadableWidth(760)
        }
        .background(Color.nbBackground)
    }

    /// A live sample of the chosen look and typeface.
    private var previewHero: some View {
        let sampleText = "Let the conversation drift by. When something catches you, tap it. The stream will wait."
        let fg: Color = theme == .paper ? inkColor : .white
        return ZStack(alignment: .bottomLeading) {
            sampleBackground
            VStack(alignment: .leading, spacing: 14) {
                Text(sampleText)
                    .font(streamFont(26, weight: serif ? .medium : .semibold, serif: serif))
                    .foregroundStyle(fg)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text(isOpenDuo ? "STREAM · ACROSS THE WHOLE DISPLAY" : "STREAM · TURN IT SIDEWAYS FOR MORE ROOM")
                        .font(.syne(12, weight: .bold))
                        .tracking(1.5)
                }
                .foregroundStyle(fg.opacity(0.75))
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .bottomLeading)
        .clipped()
        .nbBorder()
        .nbShadow(size: 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var sampleBackground: some View {
        switch theme {
        case .ambient:
            NBAmbientField(colors: sampleColors.map { themed($0, .ambient) })
        case .paper:
            NBAmbientField(colors: sampleColors.map { themed($0, .paper) })
        case .bold:
            resolvedColor(ordinal: 0).bg
        }
    }

    private var sampleColors: [UIColor] {
        let a = UIColor(Color(hex: "#0047FF")), b = UIColor(Color(hex: "#AF52DE")),
            c = UIColor(Color(hex: "#FF5C35")), d = UIColor(Color(hex: "#34C759"))
        return [a, b, a, c, a, b, d, a, c]
    }

    /// Start — or, with a stream in progress, Resume (where you left off) / Start Over.
    @ViewBuilder
    private var startButtons: some View {
        if !scenes.isEmpty {
            HStack(spacing: 10) {
                primaryButton(title: "RESUME", icon: "play.fill") { start() }
                Button {
                    resetScenes()
                    start()
                } label: {
                    Label("START OVER", systemImage: "arrow.counterclockwise")
                        .font(.syne(14, weight: .bold))
                        .foregroundStyle(Color.nbBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.nbWhite)
                        .nbBorder()
                }
                .buttonStyle(.plain)
            }
        } else {
            primaryButton(title: "START STREAMING", icon: "play.fill") { start() }
        }
    }

    private func primaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.syne(16, weight: .bold))
                    .tracking(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.nbAccent)
            .nbBorder()
            .nbShadow(size: 4)
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.syne(11, weight: .bold))
            .tracking(2)
            .foregroundStyle(Color.nbTextTertiary)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("WATCH")
            HStack(spacing: 10) {
                sourceCard(.discover, detail: "What's catching on")
                sourceCard(.following, detail: "Folks you follow")
                sourceCard(.saved, detail: engagement.saved.isEmpty ? "Nothing saved yet" : "\(engagement.saved.count) worth another look")
            }
            HStack(alignment: .bottom, spacing: 8) {
                NBTextField(placeholder: "Or pick a topic, a name or a #hashtag", text: $searchInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { applySearch() }
                let canSet = !searchInput.trimmingCharacters(in: .whitespaces).isEmpty
                Button { applySearch() } label: {
                    Text("SET")
                        .font(.syne(12, weight: .bold))
                        .foregroundStyle(canSet ? .white : Color.nbTextTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(canSet ? Color.nbAccent : Color.nbWhite)
                        .nbBorder()
                }
                .buttonStyle(.plain)
                .disabled(!canSet)
            }
            switch source {
            case .search, .author:
                HStack(spacing: 6) {
                    Image(systemName: source.icon)
                        .font(.system(size: 12, weight: .semibold))
                    Text("Streaming \(source.label)")
                        .font(.inter(13, weight: .semibold))
                    Spacer()
                    Button { source = .discover; searchInput = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.nbTextTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop streaming \(source.label)")
                }
                .foregroundStyle(Color.nbAccentLegible)
            default:
                EmptyView()
            }
        }
    }

    private func sourceCard(_ src: StreamSource, detail: String) -> some View {
        let selected = source == src
        return Button {
            Haptics.selection()
            source = src
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: selected && src != .discover ? src.icon + ".fill" : src.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                Text(src.label.uppercased())
                    .font(.syne(14, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(.inter(12))
                    .opacity(0.8)
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? .white : Color.nbBlack)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.nbAccent : Color.nbWhite)
            .nbBorder()
            .nbShadow(size: selected ? 3 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func applySearch() {
        let q = searchInput.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        source = .search(q)
    }

    private var lookSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("LOOK")
            HStack(spacing: 10) {
                ForEach(StreamTheme.allCases) { t in themeCard(t) }
            }
            Picker("Typeface", selection: $typeface) {
                Text("Editorial").tag("serif")
                Text("Modern").tag("sans")
            }
            .pickerStyle(.segmented)
            if theme == .bold {
                VStack(spacing: 0) {
                    bgPill(label: "RANDOM COLORS", value: "random")
                        .frame(maxWidth: .infinity)
                        .nbBorder()
                    HStack(spacing: 0) {
                        ForEach(streamPaletteHex, id: \.self) { hex in colorBgPill(hex: hex) }
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.nbWhite)
                    .nbBorder()
                }
            }
        }
    }

    private func themeCard(_ t: StreamTheme) -> some View {
        let selected = theme == t
        let fg: Color = t == .paper ? inkColor : .white
        return Button {
            Haptics.selection()
            themeRaw = t.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    switch t {
                    case .ambient: NBAmbientField(colors: sampleColors.map { themed($0, .ambient) })
                    case .paper: NBAmbientField(colors: sampleColors.map { themed($0, .paper) })
                    case .bold: Color(hex: "#FF5C35")
                    }
                    Text("Aa")
                        .font(streamFont(28, weight: .semibold, serif: serif))
                        .foregroundStyle(fg)
                }
                .frame(height: 70)
                .clipped()
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.label.uppercased())
                        .font(.syne(12, weight: .bold))
                    Text(t.blurb)
                        .font(.inter(11))
                        .foregroundStyle(Color.nbTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Color.nbBlack)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.nbWhite)
            }
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(selected ? Color.nbAccent : Color.nbBlack, lineWidth: selected ? 4 : 2))
            .nbShadow(size: selected ? 3 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(t.label) look: \(t.blurb)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func typefacePill(_ label: String, value: String) -> some View {
        let selected = typeface == value
        return Button { typeface = value } label: {
            HStack(spacing: 8) {
                Text("Aa").font(.system(size: 18, weight: .semibold, design: value == "serif" ? .serif : .default))
                Text(label.uppercased()).font(.syne(12, weight: .bold))
            }
            .foregroundStyle(selected ? .white : Color.nbBlack)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? Color.nbAccent : Color.nbWhite)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) typeface")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var paceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("PACE & CONTENT")
            VStack(spacing: 0) {
                settingsRow(label: "Seconds Per Post") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Seconds Per Post", selection: $streamDuration) {
                            ForEach([5.0, 8.0, 12.0, 20.0, 30.0], id: \.self) { d in
                                Text("\(Int(d))s").tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("Long posts stay up long enough to actually read them. Extra pictures and the replies each get their own turn.")
                            .font(.inter(11))
                            .foregroundStyle(Color.nbTextTertiary)
                    }
                }
                nbDivider()
                settingsRow(label: "Content") {
                    Picker("Content", selection: $streamFilter) {
                        Text("All").tag("all")
                        Text("Text").tag("text")
                        Text("Images").tag("images")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .background(Color.nbWhite)
            .nbBorder()
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("OPTIONS")
            VStack(spacing: 0) {
                describedToggle("What People Are Saying", detail: "After each post, a few of its best replies. Because the conversation is the point.", value: $showReplies)
                nbDivider()
                describedToggle("Clock", detail: "The time, quietly, in the corner", value: $showClock)
                nbDivider()
                toggleRow(label: "Reply, Repost & Like Counts", value: $showMetrics)
                nbDivider()
                toggleRow(label: "Alt Text", value: $showAltText)
                nbDivider()
                describedToggle("Keep Screen Awake", detail: "So the screen doesn't lock in the middle of a good one", value: $preventSleep)
            }
            .background(Color.nbWhite)
            .nbBorder()
        }
    }

    private func describedToggle(_ label: String, detail: String, value: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            toggleRow(label: label, value: value)
            Text(detail)
                .font(.inter(11))
                .foregroundStyle(Color.nbTextTertiary)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
        }
    }

    // MARK: - Player (full-screen cover)

    private var currentScene: StreamScene? {
        guard !scenes.isEmpty else { return nil }
        return scenes[max(0, min(currentIndex, scenes.count - 1))]
    }

    private func hasRepliesBeat(_ scene: StreamScene) -> Bool {
        showReplies && !(replies[scene.id]?.isEmpty ?? true)
    }

    /// Images, then the conversation beat when the post has replies worth showing.
    private func steps(_ scene: StreamScene) -> Int {
        max(1, scene.images.count) + (hasRepliesBeat(scene) ? 1 : 0)
    }

    /// Anything that holds the clock: a manual pause, a finger on the screen, exploring,
    /// an open image/article/prompt, the controls being used, or the app in background.
    /// Releasing it continues the SAME post from where its timer stopped.
    private var isHeld: Bool {
        userPaused || touching || explore != nil || lightbox != nil || linkPresentation != nil
            || showTopicPrompt || scenes.isEmpty || scenePhase != .active
    }

    /// Interacting: the controls are up (or the explore panel is open).
    private var interacting: Bool { controlsVisible || explore != nil }
    /// The overview: controls up with no panel — the post eases back to make room.
    private var overview: Bool { controlsVisible && explore == nil }
    private var showsFilmstrip: Bool { overview && stageSize.height >= 540 && scenes.count > 1 }

    private var foreground: Color {
        guard let scene = currentScene else { return theme == .paper ? inkColor : .white }
        return foregroundColor(for: scene)
    }

    private func foregroundColor(for scene: StreamScene) -> Color {
        switch theme {
        case .paper: return inkColor
        case .ambient: return .white
        case .bold:
            if scene.hasMedia { return .white }
            return resolvedColor(ordinal: scene.ordinal).lightText ? .white : inkColor
        }
    }

    private var streamPlayer: some View {
        // Exploring splits the display like the Duo's columns: the post on one side, its
        // conversation (or author) on the other — on the fold when folded, stacked when
        // the display is taller than wide.
        FoldSplitLayout(stacked: playerFold.isTall,
                        fold: playerFold.isTall ? playerFold.foldY : playerFold.foldX) {
            stage
            if let explore {
                explorePanel(explore)
                    .transition(.move(edge: playerFold.isTall ? .bottom : .trailing))
            }
        }
        .background(theme == .paper ? paperColor : Color(hex: "#0A0A0A"))
        .onGeometryChange(for: FoldGeometry.self) { proxy in
            FoldGeometry(proxy: proxy)
        } action: { playerFold = $0 }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(theme == .paper ? nil : .dark)
        .task { await runClock() }
        .onDisappear { stopControlTimer() }
        .onAppear {
            if preventSleep { UIApplication.shared.isIdleTimerDisabled = true }
            // VoiceOver: start held so the post doesn't change under the reader.
            if UIAccessibility.isVoiceOverRunning { userPaused = true }
            updateDwell()
            Task { await loadIfNeeded() }
        }
        .onChange(of: currentIndex) { _, _ in
            markCurrentSceneAsSeen()
            prefetch(after: currentIndex)
            // The panel follows the stream: a new post brings its own conversation.
            if case .post = explore, let scene = currentScene {
                store.explorePath = NavigationPath()
                explore = .post(scene.post)
            }
        }
        .onChange(of: scenes.count) { _, _ in prefetch(after: currentIndex) }
        .onChange(of: streamDuration) { _, _ in updateDwell() }
        .onChange(of: showReplies) { _, _ in
            if let scene = currentScene, step >= steps(scene) { step = steps(scene) - 1 }
            updateDwell()
        }
        .alert("Stream a Topic", isPresented: $showTopicPrompt) {
            TextField("Keyword or #hashtag", text: $searchInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Stream") { applySearch() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pick a word, a name or a #hashtag. You'll get the newest posts about it.")
        }
        .fullScreenCover(item: $linkPresentation) { pres in
            ArticleReaderSheet(card: pres.card, post: pres.post)
        }
        .fullScreenCover(item: $lightbox) { pres in
            LightboxView(images: pres.images, startIndex: pres.startIndex)
        }
    }

    // MARK: Stage

    private var stage: some View {
        ZStack {
            backdrop
                .clipped()
                .ignoresSafeArea()

            sceneLayer
                .padding(.top, showClock || interacting ? 70 : 24)
                .padding(.bottom, 14)
                .modifier(OverviewInset(active: overview, height: stageSize.height,
                                        top: 0, bottom: showsFilmstrip ? 200 : 96))
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { likeCurrent() }
                .onTapGesture { toggleControls() }
                .simultaneousGesture(holdAndSwipe)
                .accessibilityAction(named: "Next Post") { goNext(manual: true) }
                .accessibilityAction(named: "Previous Post") { goPrevious() }
                .accessibilityAction(named: userPaused ? "Play" : "Pause") { userPaused.toggle() }
                .accessibilityAction(named: "Show Controls") { showControls(autoHide: false) }

            heartBurst

            if !interacting { watchingOverlay.transition(.opacity) }
            if interacting { controlsLayer.transition(.opacity) }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { stageSize = $0 }
    }

    /// Finger down holds the post; a horizontal swipe changes it; swiping up opens its
    /// conversation beside it.
    private var holdAndSwipe: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in if !touching { touching = true } }
            .onEnded { value in
                touching = false
                let dx = value.translation.width, dy = value.translation.height
                if abs(dx) > 60, abs(dx) > abs(dy) * 1.3 {
                    if dx < 0 { goNext(manual: true) } else { goPrevious() }
                } else if dy < -90, abs(dy) > abs(dx) * 1.3, let scene = currentScene {
                    openExplore(.post(scene.post))
                }
            }
    }

    // MARK: Backdrop

    private var backdrop: some View {
        ZStack {
            if let scene = currentScene {
                backdropView(for: scene)
                    .id(scene.id)
                    .transition(.opacity)
            } else {
                theme == .paper ? paperColor : Color(hex: "#0A0A0A")
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2), value: currentScene?.id)
    }

    @ViewBuilder
    private func backdropView(for scene: StreamScene) -> some View {
        switch theme {
        case .ambient, .paper:
            ZStack {
                NBAmbientField(colors: fieldColors(for: scene))
                if theme == .ambient {
                    // A soft vignette keeps white type legible on the brightest colors.
                    RadialGradient(colors: [.clear, .black.opacity(0.35)], center: .center,
                                   startRadius: 100, endRadius: max(stageSize.width, stageSize.height) * 0.75)
                }
            }
        case .bold:
            if scene.hasMedia, let url = scene.thumbURL {
                ZStack {
                    Color(hex: "#0A0A0A")
                    Color.clear
                        .overlay {
                            CachedImage(url: url, maxPixelSize: 200) { phase in
                                if case .success(let image) = phase { image.resizable().scaledToFill() }
                            }
                        }
                        .blur(radius: 50, opaque: true)
                        .clipped()
                    Color.black.opacity(0.45)
                }
            } else {
                resolvedColor(ordinal: scene.ordinal).bg
            }
        }
    }

    /// The post's own colors (its image, or the author's avatar), calmed for the theme;
    /// the brand palette until they've loaded.
    private func fieldColors(for scene: StreamScene) -> [Color] {
        if let sampled = palettes[scene.id], sampled.count == 9 {
            return sampled.map { themed($0, theme) }
        }
        let base = UIColor(streamPalette[abs(scene.ordinal) % streamPalette.count].bg)
        let a = themed(base, theme)
        let b = themed(base.withAlphaComponent(1), theme).opacity(theme == .paper ? 0.9 : 0.75)
        return [a, b, a, b, a, b, a, b, a]
    }

    // MARK: Scene

    private var sceneTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let dx = CGFloat(50 * direction)
        return .asymmetric(
            insertion: .modifier(active: NBBlurDissolve(amount: 1, dx: dx), identity: NBBlurDissolve(amount: 0, dx: dx)),
            removal: .modifier(active: NBBlurDissolve(amount: 1, dx: -dx), identity: NBBlurDissolve(amount: 0, dx: -dx)))
    }

    @ViewBuilder
    private var sceneLayer: some View {
        if let scene = currentScene {
            let total = steps(scene)
            let clampedStep = min(step, total - 1)
            let repliesStep = hasRepliesBeat(scene) && clampedStep == total - 1
            StreamSceneView(
                scene: scene,
                imageIndex: min(clampedStep, max(0, scene.images.count - 1)),
                isRepliesStep: repliesStep,
                replies: replies[scene.id] ?? [],
                theme: theme,
                serif: serif,
                textColor: foregroundColor(for: scene),
                showAltText: showAltText,
                showMetrics: showMetrics,
                interactive: interacting,
                engagement: engagement,
                actions: sceneActions(for: scene)
            )
            .id(scene.id)
            .transition(sceneTransition)
        } else if let errorMessage, !isLoadingMore {
            VStack(spacing: 12) {
                if network.isOffline { NBOfflineBanner() }
                NBErrorBanner(
                    message: errorMessage,
                    retry: network.isOffline ? nil : { self.errorMessage = nil; Task { await loadMore() } },
                    onDismiss: { self.errorMessage = nil }
                )
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(foreground)
                Text("Finding something worth reading…")
                    .font(streamFont(20, serif: serif))
                    .foregroundStyle(foreground.opacity(0.8))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sceneActions(for scene: StreamScene) -> StreamSceneActions {
        StreamSceneActions(
            explore: { openExplore(.post(scene.post)) },
            reply: {
                store.pendingReplyURI = scene.post.uri   // ThreadView opens its reply box
                openExplore(.post(scene.post))
            },
            profile: { openExplore(.profile(scene.post.author.did)) },
            streamAuthor: {
                Haptics.selection()
                source = .author(did: scene.post.author.did, handle: scene.post.author.handle)
            },
            streamTag: { tag in
                Haptics.selection()
                source = .search("#\(tag)")
            },
            image: { i in lightbox = LightboxPresentation(images: scene.images, startIndex: i) },
            link: {
                if let card = scene.link { linkPresentation = StreamLinkPresentation(card: card, post: scene.post) }
            },
            selectImage: { i in
                bumpControlTimer()
                setStep(i)
            },
            like: { toggleLike(scene.post) },
            repost: { toggleRepost(scene.post) },
            save: {
                Haptics.light()
                engagement.toggleSaved(scene.post.uri)
                bumpControlTimer()
            },
            doubleTapLike: { likeCurrent() }
        )
    }

    // MARK: Watching overlay (calm)

    private var watchingOverlay: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    if showClock { StreamClockView(color: foreground, serif: serif) }
                    Spacer()
                    if userPaused {
                        Label("Paused", systemImage: "pause.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(foreground)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .nbGlass(in: Capsule())
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 14)
                Spacer()
                StreamProgressLine(clock: clock, steps: currentScene.map { steps($0) } ?? 1,
                                   step: step, color: foreground)
                    .frame(height: 2)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 8)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(!showClock)
    }

    // MARK: Interacting overlay (controls)

    private var controlsLayer: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                sourceMenu
                Spacer(minLength: 8)
                NBGlassGroup(spacing: 10) {
                    HStack(spacing: 10) {
                        if explore != nil {
                            NBGlassCapsule(title: "Resume", systemImage: "play.fill", tint: foreground) {
                                closeExplore()
                            }
                            .accessibilityLabel("Resume Stream")
                        }
                        NBGlassButton(label: "Close Stream", systemImage: "xmark", size: 48, tint: foreground) {
                            isLandscape = false
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer(minLength: 0)

            if overview {
                VStack(spacing: 14) {
                    if showsFilmstrip {
                        StreamFilmstrip(scenes: scenes, current: currentIndex, serif: serif,
                                        engagement: engagement) { jump(to: $0) }
                    }
                    transport
                }
                .padding(.bottom, 16)
            }
        }
        .background(alignment: .top) {
            if overview {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                    Spacer()
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                        .frame(height: showsFilmstrip ? 260 : 140)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 18) {
            NBGlassGroup(spacing: 14) {
                HStack(spacing: 14) {
                    NBGlassButton(label: "Previous Post", systemImage: "backward.fill", size: 52) {
                        bumpControlTimer(); goPrevious()
                    }
                    NBGlassButton(label: userPaused ? "Play" : "Pause",
                                      systemImage: userPaused ? "play.fill" : "pause.fill", size: 64) {
                        bumpControlTimer()
                        Haptics.selection()
                        userPaused.toggle()
                    }
                    .overlay {
                        // The post's progress, around the play button.
                        StreamProgressRing(clock: clock)
                            .frame(width: 70, height: 70)
                            .allowsHitTesting(false)
                    }
                    NBGlassButton(label: "Next Post", systemImage: "forward.fill", size: 52) {
                        bumpControlTimer(); goNext(manual: true)
                    }
                }
            }
        }
    }

    /// Source, content, pace and look — a native menu, changeable mid-stream.
    private var sourceMenu: some View {
        Menu {
            Section("Watch") {
                Picker("Source", selection: Bindable(session).source) {
                    Label("Discover", systemImage: "sparkles").tag(StreamSource.discover)
                    Label("Following", systemImage: "person.2").tag(StreamSource.following)
                    if !engagement.saved.isEmpty {
                        Label("Saved (\(engagement.saved.count))", systemImage: "bookmark").tag(StreamSource.saved)
                    }
                    switch source {
                    case .search, .author:
                        Label(source.label, systemImage: source.icon).tag(source)
                    default:
                        EmptyView()
                    }
                }
                .pickerStyle(.inline)
                Button("Stream a Topic…", systemImage: "magnifyingglass") { showTopicPrompt = true }
            }
            Section {
                Picker(selection: $themeRaw) {
                    ForEach(StreamTheme.allCases) { t in
                        Label(t.label, systemImage: t.icon).tag(t.rawValue)
                    }
                } label: { Label("Look", systemImage: "paintbrush") }
                .pickerStyle(.menu)
                Picker(selection: $typeface) {
                    Text("Editorial (Serif)").tag("serif")
                    Text("Modern (Sans)").tag("sans")
                } label: { Label("Typeface", systemImage: "textformat") }
                .pickerStyle(.menu)
                Picker(selection: $streamDuration) {
                    ForEach([5.0, 8.0, 12.0, 20.0, 30.0], id: \.self) { d in
                        Text("\(Int(d)) seconds").tag(d)
                    }
                } label: { Label("Pace", systemImage: "timer") }
                .pickerStyle(.menu)
                Picker(selection: $streamFilter) {
                    Text("All Posts").tag("all")
                    Text("Text Only").tag("text")
                    Text("Images Only").tag("images")
                } label: { Label("Show", systemImage: "square.grid.2x2") }
                .pickerStyle(.menu)
            }
            Section {
                Toggle(isOn: $showReplies) { Label("What People Are Saying", systemImage: "text.bubble") }
                Toggle(isOn: $showClock) { Label("Clock", systemImage: "clock") }
            }
        } label: {
            Label(source.label, systemImage: source.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .contentShape(Capsule())
        }
        .nbGlass(in: Capsule())
        .simultaneousGesture(TapGesture().onEnded { bumpControlTimer(longer: true) })
        .accessibilityLabel("Stream source and options: \(source.label)")
    }

    /// A big heart where you double-tapped (well, the middle) — then gone.
    private var heartBurst: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 120, weight: .bold))
            .foregroundStyle(Color(hex: "#FF2D55"))
            .shadow(color: .black.opacity(0.35), radius: 16)
            .keyframeAnimator(initialValue: HeartFrame(), trigger: heartToken) { content, frame in
                content.scaleEffect(frame.scale).opacity(frame.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.12, duration: 0.28)
                    CubicKeyframe(0.96, duration: 0.14)
                    CubicKeyframe(1.0, duration: 0.18)
                    CubicKeyframe(1.3, duration: 0.3)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.08)
                    LinearKeyframe(1, duration: 0.55)
                    LinearKeyframe(0, duration: 0.27)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Explore panel

    private func explorePanel(_ item: StreamExplore) -> some View {
        NavigationStack(path: Bindable(store).explorePath) {
            Group {
                switch item {
                case .post(let post): ThreadView(uri: post.uri, initialPost: post)
                case .profile(let actor): ProfileView(actor: actor)
                }
            }
            .withAppDestinations(myDid: auth.session?.did ?? "")
            .environment(\.nbIsPushed, true)   // Resume (below) is this panel's Close
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Resume Stream", systemImage: "play.fill") { closeExplore() }
                }
            }
        }
        .environment(\.navColumn, .explore)
        .nbColumnWidthReader()
        .preferredColorScheme(nil)
        .id(item.id)
        .background(Color.nbBackground)
        .overlay(alignment: playerFold.isTall ? .top : .leading) {
            Rectangle().fill(Color(hex: "#0A0A0A"))
                .frame(width: playerFold.isTall ? nil : 2, height: playerFold.isTall ? 2 : nil)
        }
    }

    private func openExplore(_ item: StreamExplore) {
        Haptics.light()
        store.explorePath = NavigationPath()
        controlsHideTask?.cancel()
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.88)) {
            explore = item
            controlsVisible = false
        }
    }

    private func closeExplore() {
        Haptics.selection()
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.88)) {
            explore = nil
            controlsVisible = false
        }
        store.explorePath = NavigationPath()
    }

    // MARK: - Engagement

    private func likeCurrent() {
        guard let scene = currentScene else { return }
        heartToken += 1
        Haptics.medium()
        guard let did = auth.session?.did else { return }
        engagement.setLiked(true, post: scene.post, did: did, onError: reportActionError)
    }

    private func toggleLike(_ post: PostView) {
        guard let did = auth.session?.did else { return }
        let on = !engagement.state(post).liked
        if on { heartToken += 1 }
        Haptics.medium()
        bumpControlTimer()
        engagement.setLiked(on, post: post, did: did, onError: reportActionError)
    }

    private func toggleRepost(_ post: PostView) {
        guard let did = auth.session?.did else { return }
        Haptics.light()
        bumpControlTimer()
        engagement.setReposted(!engagement.state(post).reposted, post: post, did: did, onError: reportActionError)
    }

    private func reportActionError(_ message: String) {
        Haptics.error()
        store.showActionError(message)
    }

    // MARK: - Color State

    private func resolvedColor(ordinal: Int) -> (bg: Color, lightText: Bool) {
        if streamBgMode == "random" {
            return streamPalette[abs(ordinal) % streamPalette.count]
        }
        let isLight = lightTextHex.contains(streamBgMode.uppercased())
        return (Color(hex: streamBgMode), isLight)
    }

    // MARK: - Navigation

    private var sceneAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.9)
    }
    private var manualAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.9)
    }

    /// Seconds for a step: the chosen pace, stretched so long posts can be read
    /// (~200 words a minute); each further image gets a shorter turn; the conversation
    /// beat gets time to read its replies.
    private func dwell(for scene: StreamScene, step: Int) -> Double {
        let base = streamDuration
        let total = steps(scene)
        if hasRepliesBeat(scene) && step == total - 1 {
            let words = (replies[scene.id] ?? []).prefix(3)
                .reduce(0) { $0 + $1.record.text.split(whereSeparator: { $0.isWhitespace }).count }
            return min(max(max(6, base * 0.8), Double(words) / 3.3 + 2), 28)
        }
        if step > 0 { return max(4, base * 0.75) }
        let reading = Double(scene.wordCount) / 3.3 + (scene.hasMedia ? 2 : 1)
        return min(max(base, reading), max(base * 3, 24))
    }

    private func updateDwell() {
        guard let scene = currentScene else { return }
        clock.dwell = dwell(for: scene, step: min(step, steps(scene) - 1))
    }

    private func setStep(_ newStep: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.6)) { step = newStep }
        clock.elapsed = 0
        updateDwell()
    }

    private func autoAdvance() {
        guard let scene = currentScene else { return }
        if step < steps(scene) - 1 { setStep(step + 1) } else { goNext(manual: false) }
    }

    private func goNext(manual: Bool) {
        guard !scenes.isEmpty else { return }
        if currentIndex >= scenes.count - 1 {
            if feedCursor == nil && !isLoadingMore && !manual && scenes.count > 1 {
                // The feed ran out: a screen saver loops instead of stopping.
                move(to: 0, dir: 1, animation: sceneAnimation)
            } else {
                Task { await loadMore() }
            }
            return
        }
        if manual { Haptics.selection() }
        move(to: currentIndex + 1, dir: 1, animation: manual ? manualAnimation : sceneAnimation)
        if currentIndex >= scenes.count - 4 { Task { await loadMore() } }
    }

    private func goPrevious() {
        guard currentIndex > 0 else { return }
        Haptics.selection()
        move(to: currentIndex - 1, dir: -1, animation: manualAnimation)
    }

    private func jump(to index: Int) {
        guard index != currentIndex, scenes.indices.contains(index) else { return }
        Haptics.selection()
        bumpControlTimer()
        move(to: index, dir: index > currentIndex ? 1 : -1, animation: manualAnimation)
    }

    private func move(to index: Int, dir: Int, animation: Animation?) {
        direction = dir
        withAnimation(animation) {
            currentIndex = index
            step = 0
        }
        clock.elapsed = 0
        updateDwell()
    }

    // MARK: - Clock

    /// One loop for the whole stream: elapsed time accrues only while nothing holds it,
    /// so pausing, exploring or holding a finger down resumes exactly where it stopped.
    private func runClock() async {
        var last = ContinuousClock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            let now = ContinuousClock.now
            let dt = now - last
            last = now
            guard !isHeld else { continue }
            clock.elapsed += Double(dt.components.seconds) + Double(dt.components.attoseconds) / 1e18
            if clock.elapsed >= clock.dwell { autoAdvance() }
        }
    }

    // MARK: - Controls

    private func toggleControls() {
        if controlsVisible {
            hideControls()
        } else {
            showControls(autoHide: true)
        }
    }

    private func showControls(autoHide: Bool) {
        Haptics.selection()
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.9)) { controlsVisible = true }
        if autoHide { bumpControlTimer() } else { controlsHideTask?.cancel() }
    }

    private func hideControls() {
        controlsHideTask?.cancel()
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.9)) { controlsVisible = false }
    }

    /// Keep the controls up a while longer after any use.
    private func bumpControlTimer(longer: Bool = false) {
        guard controlsVisible else { return }
        controlsHideTask?.cancel()
        controlsHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(longer ? 12 : 6))
            guard !Task.isCancelled else { return }
            hideControls()
        }
    }

    private func stopControlTimer() {
        controlsHideTask?.cancel()
        controlsHideTask = nil
    }

    // MARK: - Seen Posts

    private func loadSeenURIs() async {
        let cutoff = Date().addingTimeInterval(-seenMaxAge)
        let descriptor = FetchDescriptor<SeenPost>(
            predicate: #Predicate<SeenPost> { $0.seenAt > cutoff }
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        seenURISet = Set(records.map { $0.uri })
    }

    private func markCurrentSceneAsSeen() {
        guard let scene = currentScene else { return }
        let uri = scene.post.uri
        guard !seenURISet.contains(uri) else { return }
        seenURISet.insert(uri)
        modelContext.insert(SeenPost(uri: uri))
    }

    // MARK: - Prefetch (images, colors, replies)

    /// Warm the next posts so each scene appears whole: media, its color field, and the
    /// replies for its conversation beat.
    private func prefetch(after index: Int) {
        let scale = displayScale
        for scene in scenes.dropFirst(index).prefix(3) {
            var urls: [(URL, CGFloat)] = scene.images.compactMap { img in
                URL(string: img.fullsize).map { ($0, streamMediaMaxPixel) }
            }
            if let t = scene.video?.thumbnail, let u = URL(string: t) { urls.append((u, streamMediaMaxPixel)) }
            if let t = scene.link?.thumb, let u = URL(string: t) { urls.append((u, streamMediaMaxPixel)) }
            for (url, px) in urls where NBImageLoader.cached(url) == nil {
                Task { _ = await NBImageLoader.load(url, maxPixel: px, scale: scale) }
            }
            loadPalette(scene, scale: scale)
            loadReplies(scene)
        }
    }

    private func loadPalette(_ scene: StreamScene, scale: CGFloat) {
        guard palettes[scene.id] == nil, palettesRequested.insert(scene.id).inserted else { return }
        // The media's still, or — for words alone — the author's avatar.
        let isThumb = scene.thumbURL != nil
        guard let url = scene.thumbURL ?? scene.post.author.avatar.flatMap({ URL(string: $0) }) else { return }
        Task {
            if let image = await NBImageLoader.load(url, maxPixel: isThumb ? 200 : 72, scale: scale),
               let colors = nbPaletteColors(from: image) {
                palettes[scene.id] = colors
            }
        }
    }

    private func loadReplies(_ scene: StreamScene) {
        guard showReplies, (scene.post.replyCount ?? 0) > 0,
              repliesRequested.insert(scene.id).inserted else { return }
        Task {
            guard let response = try? await ATProtocolClient.shared.getPostThread(uri: scene.post.uri, depth: 1),
                  let root = response.thread.post else { return }
            let top = (root.replies ?? [])
                .compactMap { $0.post?.post }
                .filter { reply in
                    !reply.isAdultContent && reply.author.viewer?.isHidden != true
                        && !strippedOfURLs(reply.record.text).isEmpty
                }
                .sorted { ($0.likeCount ?? 0) > ($1.likeCount ?? 0) }
            replies[scene.id] = Array(top.prefix(3))
            if scene.id == currentScene?.id { updateDwell() }
        }
    }

    // MARK: - Feed Loading

    private func loadMore(attempt: Int = 0) async {
        guard !isLoadingMore else { return }
        if source == .saved && feedCursor == "end" { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let nextOrdinal = (scenes.last?.ordinal ?? -1) + 1
        let requested = source
        do {
            var posts: [PostView] = []
            var nextCursor: String? = nil
            switch source {
            case .discover:
                let r = try await ATProtocolClient.shared.getFeed(uri: discoverURI, limit: 30, cursor: feedCursor)
                posts = r.feed.filter { !DiscoverEngine.shouldHide($0, prefs: store.moderationPrefs) }.map { $0.post }
                nextCursor = r.cursor
            case .following:
                let r = try await ATProtocolClient.shared.getTimeline(limit: 30, cursor: feedCursor)
                posts = r.feed.filter { !DiscoverEngine.shouldHide($0, prefs: store.moderationPrefs) }.map { $0.post }
                nextCursor = r.cursor
            case .saved:
                guard !engagement.saved.isEmpty else {
                    errorMessage = "Nothing saved yet. When a post is worth another look, tap the screen and hit Save. It will be waiting here."
                    return
                }
                posts = try await ATProtocolClient.shared.getPosts(uris: Array(engagement.saved.prefix(100)))
                nextCursor = nil
                feedCursor = "end"
            case .search(let q):
                let r = try await ATProtocolClient.shared.searchPosts(q: q, sort: "latest", limit: 30, cursor: feedCursor)
                posts = r.posts; nextCursor = r.cursor
            case .author(let did, _):
                let r = try await ATProtocolClient.shared.getAuthorFeed(actor: did, limit: 30, cursor: feedCursor)
                posts = r.feed.map { $0.post }
                nextCursor = r.cursor
            }
            guard requested == source else { return }   // source changed mid-request
            // A full-screen, unattended slideshow must never surface adult-labelled
            // posts or muted/blocked authors.
            posts = posts.filter { !$0.isAdultContent && $0.author.viewer?.isHidden != true }
            let known = Set(scenes.map(\.id))
            var seenInPage = Set<String>()
            let newScenes = posts
                .filter { !known.contains($0.uri) && seenInPage.insert($0.uri).inserted }
                .compactMap { buildScene($0, skipSeen: requested.skipsSeen) }
                .enumerated()
                .map { i, s in
                    StreamScene(post: s.post, ordinal: nextOrdinal + i, text: s.text, images: s.images,
                                link: s.link, video: s.video, quote: s.quote)
                }
            let wasEmpty = scenes.isEmpty
            scenes.append(contentsOf: newScenes)
            if requested != .saved { feedCursor = nextCursor }
            if wasEmpty && !scenes.isEmpty { updateDwell(); markCurrentSceneAsSeen() }
            // A page that is entirely seen/filtered isn't a failure — fetch the next one
            // (bounded) instead of stalling or claiming the connection failed.
            if newScenes.isEmpty, nextCursor != nil, attempt < 3 {
                isLoadingMore = false
                await loadMore(attempt: attempt + 1)
                return
            }
            if scenes.isEmpty {
                errorMessage = "You've already seen everything new here. Try another source, or come back in a bit."
            } else { errorMessage = nil }
        } catch {
            if scenes.isEmpty {
                Haptics.error()
                errorMessage = network.isOffline
                    ? "You're offline. The stream will start as soon as you're back."
                    : "The posts didn't load. Check your connection and try again."
            }
        }
    }

    /// One scene per post, or nil when the post doesn't fit the chosen content type.
    private func buildScene(_ post: PostView, skipSeen: Bool) -> StreamScene? {
        if skipSeen && seenURISet.contains(post.uri) { return nil }
        let text = strippedOfURLs(post.record.text).trimmingCharacters(in: .whitespacesAndNewlines)
        let images = post.embed?.images ?? []
        // Video-site links render as dead thumbnails — leave them out.
        let link: ExternalCard? = {
            guard let e = post.embed?.external, !isVideoURL(e.uri) else { return nil }
            return e
        }()
        let video = post.embed?.video
        let quote = post.embed?.quotedPost

        switch streamFilter {
        case "text":
            guard !text.isEmpty, images.isEmpty, video == nil else { return nil }
            return StreamScene(post: post, ordinal: 0, text: text, images: [], link: nil, video: nil, quote: quote)
        case "images":
            guard !images.isEmpty else { return nil }
            return StreamScene(post: post, ordinal: 0, text: text, images: images, link: nil, video: nil, quote: quote)
        default:
            let hasVideoThumb = video?.thumbnail != nil
            guard !text.isEmpty || !images.isEmpty || link != nil || hasVideoThumb else { return nil }
            return StreamScene(post: post, ordinal: 0, text: text, images: images, link: link,
                               video: hasVideoThumb ? video : nil, quote: quote)
        }
    }

    // MARK: - Settings Helpers (setup screen)

    // MARK: - Settings Helpers

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.syne(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.nbTextTertiary)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.nbWhite)
            .nbBorder()
        }
    }

    private func settingsRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.inter(13, weight: .semibold))
                .foregroundStyle(Color.nbBlack)
            content()
        }
        .padding(14)
    }

    private func nbDivider() -> some View {
        Divider().background(Color.nbBlack.opacity(0.12))
    }

    private func sourcePill(label: String, src: StreamSource) -> some View {
        let isSelected = source == src
        return Button {
            if source != src { source = src }
        } label: {
            Text(label.uppercased())
                .font(.syne(13, weight: .bold))
                .foregroundStyle(isSelected ? .white : Color.nbBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(isSelected ? Color.nbAccent : Color.nbWhite)
        }
        .buttonStyle(.plain)
    }

    private func durationPill(_ d: Double) -> some View {
        let isSelected = streamDuration == d
        return Button { streamDuration = d } label: {
            Text(d < 10 ? "\(Int(d))s" : "\(Int(d))s")
                .font(.syne(12, weight: .bold))
                .foregroundStyle(isSelected ? .white : Color.nbBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? Color.nbAccent : Color.nbWhite)
        }
        .buttonStyle(.plain)
    }

    private func filterPill(_ label: String, value: String) -> some View {
        let isSelected = streamFilter == value
        return Button { streamFilter = value } label: {
            Text(label)
                .font(.syne(12, weight: .bold))
                .foregroundStyle(isSelected ? .white : Color.nbBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? Color.nbAccent : Color.nbWhite)
        }
        .buttonStyle(.plain)
    }

    private func bgPill(label: String, value: String) -> some View {
        let isSelected = streamBgMode == value
        return Button { streamBgMode = value } label: {
            Text(label)
                .font(.syne(10, weight: .bold))
                .foregroundStyle(isSelected ? .white : Color.nbBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? Color.nbAccent : Color.nbWhite)
        }
        .buttonStyle(.plain)
    }

    private func colorBgPill(hex: String) -> some View {
        let isSelected = streamBgMode == hex
        return Button { streamBgMode = hex } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(
                    isSelected ? Color.nbBlack : Color.nbBlack.opacity(0.3),
                    lineWidth: isSelected ? 2.5 : 1
                ))
                .shadow(color: isSelected ? Color.nbBlack : .clear, radius: 0, x: 2, y: 2)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(label: String, value: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.inter(14))
                .foregroundStyle(Color.nbBlack)
            Spacer()
            Toggle("", isOn: value)
                .labelsHidden()
                .tint(Color.nbAccent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

}

/// Longest side, in points, that Stream decodes post media at.
private let streamMediaMaxPixel: CGFloat = 900

private struct HeartFrame {
    var scale: CGFloat = 0.4
    var opacity: Double = 0
}

/// Overview: the post eases back (scaled, nudged up) to make room for the filmstrip and
/// transport — a visual move, so the type isn't refitted every time the controls show.
private struct OverviewInset: ViewModifier {
    let active: Bool
    let height: CGFloat
    let top: CGFloat
    let bottom: CGFloat
    func body(content: Content) -> some View {
        let h = max(height, 1)
        let scale = active ? max(0.6, (h - top - bottom) / h) : 1
        content
            .scaleEffect(scale)
            .offset(y: active ? (top - bottom) / 2 : 0)
    }
}

/// Everything a scene can ask the stream to do.
private struct StreamSceneActions {
    let explore: () -> Void
    let reply: () -> Void
    let profile: () -> Void
    let streamAuthor: () -> Void
    let streamTag: (String) -> Void
    let image: (Int) -> Void
    let link: () -> Void
    let selectImage: (Int) -> Void
    let like: () -> Void
    let repost: () -> Void
    let save: () -> Void
    let doubleTapLike: () -> Void
}

// MARK: - Ambient chrome

/// A quiet clock for a screen left on.
private struct StreamClockView: View {
    let color: Color
    let serif: Bool
    var body: some View {
        TimelineView(.everyMinute) { ctx in
            VStack(alignment: .leading, spacing: 0) {
                Text(ctx.date, format: .dateTime.hour().minute())
                    .font(.system(size: 34, weight: .light, design: serif ? .serif : .rounded))
                    .monospacedDigit()
                Text(ctx.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.system(size: 14, weight: .medium))
                    .opacity(0.75)
            }
            .foregroundStyle(color.opacity(0.85))
        }
    }
}

/// Hairline at the bottom: one segment per step of the current post.
private struct StreamProgressLine: View {
    let clock: StreamClock
    let steps: Int
    let step: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(1, steps), id: \.self) { i in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.18))
                        Capsule().fill(color.opacity(0.7))
                            .frame(width: geo.size.width * fill(i))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func fill(_ i: Int) -> CGFloat {
        if i < step { return 1 }
        if i == step { return CGFloat(clock.progress) }
        return 0
    }
}

/// The current step's progress, as a ring around the play button.
private struct StreamProgressRing: View {
    let clock: StreamClock
    var body: some View {
        Circle()
            .trim(from: 0, to: CGFloat(clock.progress))
            .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true)
    }
}

/// Recent and upcoming posts — go back to the one you just missed.
private struct StreamFilmstrip: View {
    let scenes: [StreamScene]
    let current: Int
    let serif: Bool
    let engagement: StreamEngagement
    let onSelect: (Int) -> Void

    var body: some View {
        let lo = max(0, current - 12)
        let hi = max(lo, min(scenes.count - 1, current + 12))
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(lo...hi, id: \.self) { i in
                        Button { onSelect(i) } label: { card(i) }
                            .buttonStyle(.plain)
                            .id(i)
                            .accessibilityLabel(label(i))
                            .accessibilityAddTraits(i == current ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 24)
            }
            .onAppear { proxy.scrollTo(current, anchor: .center) }
            .onChange(of: current) { _, c in
                withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(c, anchor: .center) }
            }
        }
        .frame(height: 100)
    }

    private func label(_ i: Int) -> String {
        let s = scenes[i]
        let when = i == current ? "Now showing" : (i < current ? "Earlier" : "Coming up")
        return "\(when): \(s.authorName). \(s.text.prefix(80))"
    }

    private func card(_ i: Int) -> some View {
        let scene = scenes[i]
        let isCurrent = i == current
        return ZStack(alignment: .bottomLeading) {
            if let url = scene.thumbURL {
                CachedImage(url: url, maxPixelSize: 200) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Color.white.opacity(0.12)
                    }
                }
                .frame(width: 160, height: 100)
                .clipped()
            } else {
                Color.white.opacity(0.14)
                    .overlay(alignment: .topLeading) {
                        Text(scene.text)
                            .font(streamFont(14, weight: .medium, serif: serif))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .padding(9)
                    }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            HStack(spacing: 6) {
                AvatarView(url: scene.post.author.avatar, size: 20)
                Text(scene.authorName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(7)
        }
        .frame(width: 160, height: 100)
        .clipped()
        .overlay(alignment: .topTrailing) {
            if engagement.isSaved(scene.id) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(7)
            }
        }
        .overlay(alignment: .topLeading) {
            if isCurrent {
                Text("NOW")
                    .font(.syne(10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white)
                    .padding(7)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(isCurrent ? Color.white : Color.white.opacity(0.25),
                                          lineWidth: isCurrent ? 3 : 1))
        .opacity(i < current ? 0.7 : 1)
    }
}

// MARK: - Scene

/// One post laid out for the measured canvas.
/// - Words alone: a pull quote — the largest type that fits, then who said it. Folded
///   like a book, a two-page spread: who and when on the left, the words on the right.
/// - With media: media beside the words when wide (the split on the fold), above them
///   when tall (tabletop: the picture on the upright half). Media is always whole.
/// - Conversation beat: the post, small, beside what people are saying.
private struct StreamSceneView: View {
    let scene: StreamScene
    let imageIndex: Int
    let isRepliesStep: Bool
    let replies: [PostView]
    let theme: StreamTheme
    let serif: Bool
    let textColor: Color
    let showAltText: Bool
    let showMetrics: Bool
    let interactive: Bool
    let engagement: StreamEngagement
    let actions: StreamSceneActions

    @State private var size: CGSize = .zero
    @State private var fold = FoldGeometry()
    @ScaledMetric(relativeTo: .body) private var minReading: CGFloat = 19

    private var wide: Bool { size.width >= size.height * 1.05 }
    private var pad: CGFloat { min(max(min(size.width, size.height) * 0.045, 16), 44) }
    private var stripHeight: CGFloat { scene.images.count > 1 ? 68 : 0 }
    private var frameColor: Color { theme == .paper ? inkColor : Color(hex: "#0A0A0A") }

    /// Aspect used for the layout — the widest of the post's media, so the split doesn't
    /// jump as images change.
    private var layoutAspect: CGFloat {
        let count = max(1, scene.images.count)
        let all = (0..<count).compactMap { scene.aspect($0) }
        return min(max(all.max() ?? 1, 0.56), 2.2)
    }

    /// A fold near the middle of the axis we'd split along, if any.
    private var foldX: ClosedRange<CGFloat>? {
        guard let f = fold.foldX, f.lowerBound > size.width * 0.3, f.upperBound < size.width * 0.7 else { return nil }
        return f
    }
    private var foldY: ClosedRange<CGFloat>? {
        guard let f = fold.foldY, f.lowerBound > size.height * 0.3, f.upperBound < size.height * 0.7 else { return nil }
        return f
    }

    var body: some View {
        Group {
            if size == .zero {
                Color.clear
            } else if isRepliesStep {
                conversationBeat
                    .transition(.modifier(active: NBBlurDissolve(amount: 1, dx: 0), identity: NBBlurDissolve(amount: 0, dx: 0)))
            } else if !scene.hasMedia {
                textScene
            } else if !scene.hasWords {
                mediaScene
            } else if wide {
                wideSplit
            } else {
                tallSplit
            }
        }
        // minWidth/minHeight 0: the frame is exactly the space offered. A plain maxWidth
        // frame grows to oversized content and the measurement then confirms the stale
        // layout (device: opening the explore panel left the post full width).
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onGeometryChange(for: FoldGeometry.self) { proxy in
            FoldGeometry(proxy: proxy)
        } action: { fold = $0 }
    }

    // MARK: Layouts

    @ViewBuilder
    private var textScene: some View {
        if wide, let f = foldX {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    quoteMark
                    Spacer(minLength: 0)
                    attribution(avatar: 72)
                    if let quote = scene.quote { quoteBlock(quote) }
                    tagsRow
                    Spacer(minLength: 0)
                    bottomRow
                }
                .padding(pad)
                .frame(width: f.lowerBound)
                Color.clear.frame(width: f.upperBound - f.lowerBound)
                bodyText(maxSize: 84)
                    .padding(pad)
                    .frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: pad * 0.5) {
                quoteMark
                bodyText(maxSize: min(104, size.width / 7))
                if let quote = scene.quote { quoteBlock(quote) }
                tagsRow
                attribution(avatar: 52)
                bottomRow
            }
            .padding(.horizontal, max(pad, size.width * 0.07))
            .padding(.bottom, pad * 0.5)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
    }

    private var wideSplit: some View {
        let (mediaWidth, gap) = wideMediaWidth
        return HStack(spacing: 0) {
            mediaBlock
                .padding(pad)
                .frame(width: mediaWidth)
            Color.clear.frame(width: gap)
            textPanel(width: size.width - mediaWidth - gap - pad * 2)
                .padding(.vertical, pad * 0.5)
                .padding(.trailing, pad)
                .padding(.leading, gap > 0 ? pad : pad * 0.4)
                .frame(maxWidth: .infinity)
        }
    }

    private var wideMediaWidth: (CGFloat, CGFloat) {
        if let f = foldX { return (f.lowerBound, f.upperBound - f.lowerBound) }
        let ideal = (size.height - pad * 2 - stripHeight) * layoutAspect + pad * 2
        let maxFraction: CGFloat = scene.wordCount > 50 ? 0.52 : 0.62
        return (min(max(ideal, size.width * 0.4), size.width * maxFraction), 0)
    }

    private var tallSplit: some View {
        let (mediaHeight, gap) = tallMediaHeight
        return VStack(spacing: 0) {
            mediaBlock
                .padding(.horizontal, pad)
                .padding(.bottom, pad * 0.75)
                .frame(height: mediaHeight)
            Color.clear.frame(height: gap)
            textPanel(width: size.width - pad * 2)
                .padding(.horizontal, pad)
                .padding(.top, gap > 0 ? pad : 0)
                .frame(maxHeight: .infinity)
        }
    }

    private var tallMediaHeight: (CGFloat, CGFloat) {
        if let f = foldY { return (f.lowerBound, f.upperBound - f.lowerBound) }
        let ideal = (size.width - pad * 2) / layoutAspect + pad * 0.75 + stripHeight
        let maxFraction: CGFloat = scene.wordCount > 50 ? 0.5 : 0.6
        return (min(max(ideal, size.height * 0.36), size.height * maxFraction), 0)
    }

    /// Media only: as large as it goes, the author and actions beneath.
    private var mediaScene: some View {
        VStack(spacing: pad * 0.6) {
            mediaBlock
            VStack(alignment: .leading, spacing: 10) {
                altText
                tagsRow
                HStack(spacing: 16) {
                    attribution(avatar: 40)
                    Spacer(minLength: 0)
                }
                bottomRow
            }
            .frame(maxWidth: 1000)
        }
        .padding(.horizontal, pad)
    }

    /// Beside (or below) the media: the words, then who, then actions.
    private func textPanel(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let link = scene.link {
                linkBody(link)
            } else {
                bodyText(maxSize: min(68, max(width, 200) / 8))
            }
            if let quote = scene.quote { quoteBlock(quote) }
            altText
            tagsRow
            attribution(avatar: 44)
            bottomRow
        }
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Conversation beat

    @ViewBuilder
    private var conversationBeat: some View {
        if wide {
            let split: (CGFloat, CGFloat) = foldX.map { ($0.lowerBound, $0.upperBound - $0.lowerBound) }
                ?? (size.width * 0.42, 0)
            HStack(spacing: 0) {
                recap
                    .padding(pad)
                    .frame(width: split.0)
                Color.clear.frame(width: split.1)
                repliesColumn(maxReplies: size.height > 620 ? 3 : 2)
                    .padding(.vertical, pad * 0.5)
                    .padding(.horizontal, pad)
                    .frame(maxWidth: .infinity)
            }
        } else {
            let split: (CGFloat, CGFloat) = foldY.map { ($0.lowerBound, $0.upperBound - $0.lowerBound) }
                ?? (size.height * 0.36, 0)
            VStack(spacing: 0) {
                recap
                    .padding(.horizontal, pad)
                    .padding(.bottom, pad * 0.5)
                    .frame(height: split.0)
                Color.clear.frame(height: split.1)
                repliesColumn(maxReplies: (size.height - split.0) > 560 ? 3 : 2)
                    .padding(.horizontal, pad)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    /// The post, small: its picture or its words, and who said it.
    private var recap: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let url = scene.images.first.flatMap({ URL(string: $0.fullsize) }) ?? scene.thumbURL {
                StreamMediaImage(url: url, aspect: scene.aspect(0), frameColor: frameColor)
                    .onTapGesture(perform: actions.explore)
                if !scene.text.isEmpty {
                    Text(scene.text)
                        .font(streamFont(max(minReading - 1, 17), serif: serif))
                        .foregroundStyle(textColor.opacity(0.85))
                        .lineLimit(3)
                }
            } else {
                StreamFittedText(text: scene.text, color: textColor.opacity(0.9), maxSize: 44,
                                 minSize: max(minReading - 2, 17), serif: serif, reveal: false)
                    .onTapGesture(perform: actions.explore)
            }
            attribution(avatar: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func repliesColumn(maxReplies: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("WHAT PEOPLE ARE SAYING")
                    .font(.syne(13, weight: .bold))
                    .tracking(2)
                Spacer(minLength: 8)
                if let n = scene.post.replyCount, n > 0 {
                    Text(n == 1 ? "1 reply" : "\(nbCompactCount(n)) replies")
                        .font(.system(size: 14, weight: .medium))
                        .opacity(0.75)
                }
            }
            .foregroundStyle(textColor.opacity(0.8))
            ForEach(Array(replies.prefix(maxReplies).enumerated()), id: \.element.uri) { i, reply in
                StreamReplyCard(reply: reply, color: textColor, serif: serif, index: i)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: actions.explore)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Opens the conversation. The stream waits.")
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                NBGlassCapsule(title: "Join the Conversation", systemImage: "arrowshape.turn.up.left",
                                   tint: textColor, action: actions.reply)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: 720, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Pieces

    /// A large opening quote mark — the post as a pull quote.
    private var quoteMark: some View {
        Text("\u{201C}")
            .font(.system(size: 110, weight: .bold, design: .serif))
            .foregroundStyle(textColor.opacity(0.22))
            .frame(height: 46, alignment: .top)
            .offset(x: -4, y: -6)
            .accessibilityHidden(true)
    }

    private func bodyText(maxSize: CGFloat) -> some View {
        StreamFittedText(text: scene.text, color: textColor, maxSize: maxSize, minSize: minReading, serif: serif)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: actions.doubleTapLike)
            .onTapGesture(perform: actions.explore)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the conversation. The stream waits.")
    }

    private func linkBody(_ link: ExternalCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let host = URL(string: link.uri)?.host {
                Text(host.replacingOccurrences(of: "www.", with: "").uppercased())
                    .font(.syne(13, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(textColor.opacity(0.65))
            }
            StreamFittedText(text: link.title, color: textColor, maxSize: 56,
                             minSize: max(minReading, 22), serif: serif)
                .contentShape(Rectangle())
                .onTapGesture(perform: actions.link)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens the article")
            if !link.description.isEmpty {
                Text(link.description)
                    .font(streamFont(max(minReading - 2, 16), serif: serif))
                    .foregroundStyle(textColor.opacity(0.75))
                    .lineLimit(2)
            }
            if !scene.text.isEmpty {
                Text("\u{201C}\(scene.text)\u{201D}")
                    .font(streamFont(max(minReading - 1, 17), weight: .medium, serif: serif))
                    .italic(serif)
                    .foregroundStyle(textColor.opacity(0.9))
                    .lineLimit(3)
                    .onTapGesture(perform: actions.explore)
            }
            Button(action: actions.link) {
                Label("Read the Article", systemImage: "doc.text")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .nbGlass(in: Capsule())
        }
    }

    /// Who said it. Tap: their profile beside the post. Long-press: stream their posts.
    private func attribution(avatar: CGFloat) -> some View {
        let author = scene.post.author
        return Button(action: actions.profile) {
            HStack(spacing: 12) {
                AvatarView(url: author.avatar, size: avatar)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scene.authorName)
                        .font(.system(size: max(17, avatar * 0.36), weight: .bold))
                        .lineLimit(1)
                    Text("@\(author.handle) · \(scene.post.relativeTime)")
                        .font(.system(size: max(14, avatar * 0.27)))
                        .opacity(0.72)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(textColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Stream @\(author.handle)'s Posts", systemImage: "play.rectangle", action: actions.streamAuthor)
            Button("View Profile", systemImage: "person.crop.circle", action: actions.profile)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(scene.authorName), @\(author.handle), \(scene.post.relativeTime)")
        .accessibilityHint("Opens the profile. The stream waits.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Stream This Person's Posts", actions.streamAuthor)
    }

    @ViewBuilder
    private var tagsRow: some View {
        let tags = scene.hashtags
        if !tags.isEmpty {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button { actions.streamTag(tag) } label: {
                        Text("#\(tag)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(textColor.opacity(0.85))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .overlay(Capsule().strokeBorder(textColor.opacity(0.35), lineWidth: 1.5))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stream posts tagged \(tag)")
                }
            }
        }
    }

    private func quoteBlock(_ quote: PostView) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                AvatarView(url: quote.author.avatar, size: 24)
                Text(quote.author.displayName ?? quote.author.handle)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
            Text(strippedOfURLs(quote.record.text))
                .font(streamFont(max(minReading - 2, 16), serif: serif))
                .lineLimit(3)
        }
        .foregroundStyle(textColor)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(textColor.opacity(0.35), lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture(perform: actions.explore)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Quoting \(quote.author.displayName ?? quote.author.handle): \(quote.record.text)")
    }

    @ViewBuilder
    private var altText: some View {
        if showAltText, !scene.images.isEmpty {
            let img = scene.images[imageIndex]
            if !img.alt.isEmpty {
                (Text("ALT  ").font(.syne(12, weight: .bold)).foregroundStyle(textColor.opacity(0.6))
                 + Text(img.alt).font(.system(size: 15)).foregroundStyle(textColor.opacity(0.8)))
                    .lineLimit(2)
                    .accessibilityHidden(true)   // the image itself carries it
            }
        }
    }

    /// Watching: quiet counts. Interacting: the actions, in the same place.
    private var bottomRow: some View {
        let state = engagement.state(scene.post)
        let saved = engagement.isSaved(scene.id)
        return ZStack(alignment: .leading) {
            HStack(spacing: 18) {
                if showMetrics {
                    quietCount("bubble.left", scene.post.replyCount ?? 0)
                    quietCount("arrow.2.squarepath", state.reposts, on: state.reposted)
                    quietCount(state.liked ? "heart.fill" : "heart", state.likes, on: state.liked)
                }
                if saved {
                    Image(systemName: "bookmark.fill").font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(textColor.opacity(0.7))
            .opacity(interactive ? 0 : 1)
            .accessibilityHidden(interactive)

            StreamActionBar(post: scene.post, state: state, saved: saved, shareURL: scene.shareURL,
                            color: textColor, showCounts: showMetrics, actions: actions)
                .opacity(interactive ? 1 : 0)
                .allowsHitTesting(interactive)
                .accessibilityHidden(!interactive)
        }
        .frame(height: 50)
        .animation(.easeInOut(duration: 0.3), value: interactive)
    }

    private func quietCount(_ icon: String, _ n: Int, on: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 15, weight: on ? .bold : .regular))
            Text(nbCompactCount(n)).font(.system(size: 15, weight: on ? .bold : .regular)).monospacedDigit()
        }
    }

    // MARK: Media

    private var mediaBlock: some View {
        VStack(spacing: 12) {
            mainMedia
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if scene.images.count > 1 { thumbStrip }
        }
    }

    @ViewBuilder
    private var mainMedia: some View {
        if !scene.images.isEmpty {
            let img = scene.images[imageIndex]
            StreamMediaImage(url: URL(string: img.fullsize), aspect: scene.aspect(imageIndex), frameColor: frameColor)
                .id(img.fullsize)
                .transition(.modifier(active: NBBlurDissolve(amount: 1, dx: 0), identity: NBBlurDissolve(amount: 0, dx: 0)))
                .onTapGesture(count: 2, perform: actions.doubleTapLike)
                .onTapGesture { actions.image(imageIndex) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(img.alt.isEmpty ? "Image \(imageIndex + 1) of \(scene.images.count)" : img.alt)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens the image full screen")
        } else if let thumb = scene.video?.thumbnail {
            StreamMediaImage(url: URL(string: thumb), aspect: scene.aspect(0), frameColor: frameColor)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 76)
                        .nbGlass(in: Circle())
                }
                .onTapGesture(count: 2, perform: actions.doubleTapLike)
                .onTapGesture(perform: actions.explore)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Video")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Opens the conversation to watch it")
        } else if let link = scene.link, let thumb = link.thumb {
            StreamMediaImage(url: URL(string: thumb), aspect: 1.91, frameColor: frameColor)
                .onTapGesture(perform: actions.link)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Article: \(link.title)")
                .accessibilityAddTraits(.isButton)
        }
    }

    private var thumbStrip: some View {
        HStack(spacing: 10) {
            ForEach(Array(scene.images.enumerated()), id: \.offset) { i, img in
                Button { actions.selectImage(i) } label: {
                    CachedImage(url: URL(string: img.thumb), maxPixelSize: 200) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            textColor.opacity(0.1)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipped()
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(i == imageIndex ? textColor : textColor.opacity(0.3),
                                                      lineWidth: i == imageIndex ? 3 : 1))
                    .opacity(i == imageIndex ? 1 : 0.7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Image \(i + 1) of \(scene.images.count)")
                .accessibilityAddTraits(i == imageIndex ? .isSelected : [])
            }
        }
        .frame(height: 56)
    }
}

/// Post text at the largest size that fits its box, its lines revealed one by one.
private struct StreamFittedText: View {
    let text: String
    let color: Color
    let maxSize: CGFloat
    let minSize: CGFloat
    let serif: Bool
    var reveal = true
    @State private var box: CGSize = .zero
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let short = text.count <= 140
        let uiWeight: UIFont.Weight = short ? (serif ? .medium : .semibold) : .regular
        let weight: Font.Weight = short ? (serif ? .medium : .semibold) : .regular
        let size = nbFittedFontSize(text, box: box, weight: uiWeight, serif: serif,
                                  range: minSize...max(minSize + 1, maxSize), lineSpacing: 0.14)
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { box = $0 }
            .overlay(alignment: .leading) {
                Text(text)
                    .font(streamFont(size, weight: weight, serif: serif))
                    .lineSpacing(size * 0.14)
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textRenderer(NBLineReveal(progress: revealed ? 1 : 0))
            }
            .onAppear {
                if reveal && !reduceMotion {
                    withAnimation(.easeOut(duration: 1.6).delay(0.25)) { revealed = true }
                } else {
                    revealed = true
                }
            }
    }
}

/// A post's image, video still or link thumbnail: whole (fit), framed neubrutalist-style.
private struct StreamMediaImage: View {
    let url: URL?
    let aspect: CGFloat?
    var frameColor: Color = Color(hex: "#0A0A0A")

    var body: some View {
        CachedImage(url: url, maxPixelSize: streamMediaMaxPixel) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 28, y: 14)
            case .empty:
                placeholder.overlay(ProgressView())
            case .failure:
                placeholder.overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .aspectRatio(aspect ?? 1, contentMode: .fit)
    }
}

/// Interacting: reply / repost / like (with counts), save, share, and the conversation.
/// Fits narrow columns by dropping labels, then counts — never truncating.
private struct StreamActionBar: View {
    let post: PostView
    let state: StreamEngagement.State
    let saved: Bool
    let shareURL: URL?
    let color: Color
    let showCounts: Bool
    let actions: StreamSceneActions

    var body: some View {
        ViewThatFits(in: .horizontal) {
            bar(counts: showCounts, conversationTitle: true)
            bar(counts: showCounts, conversationTitle: false)
            bar(counts: false, conversationTitle: false)
        }
    }

    private func bar(counts: Bool, conversationTitle: Bool) -> some View {
        NBGlassGroup(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    countButton("Reply", icon: "bubble.left", n: post.replyCount ?? 0, on: false,
                                counts: counts, action: actions.reply)
                    countButton(state.reposted ? "Undo Repost" : "Repost", icon: "arrow.2.squarepath",
                                n: state.reposts, on: state.reposted, counts: counts, action: actions.repost)
                    countButton(state.liked ? "Unlike" : "Like", icon: state.liked ? "heart.fill" : "heart",
                                n: state.likes, on: state.liked, counts: counts, action: actions.like)
                }
                .padding(.horizontal, 6)
                .nbGlass(in: Capsule())

                NBGlassButton(label: saved ? "Remove from Saved" : "Save for Later",
                                  systemImage: saved ? "bookmark.fill" : "bookmark", size: 46, tint: color,
                                  action: actions.save)
                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(color)
                            .frame(width: 46, height: 46)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .nbGlass(in: Circle())
                    .accessibilityLabel("Share")
                }
                Spacer(minLength: 4)
                Button(action: actions.explore) {
                    Group {
                        if conversationTitle {
                            Label("Conversation", systemImage: "text.bubble")
                        } else {
                            Image(systemName: "text.bubble")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, conversationTitle ? 18 : 0)
                    .frame(minWidth: 46, minHeight: 46)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .nbGlass(in: Capsule())
                .accessibilityLabel("Conversation")
                .accessibilityHint("Opens the conversation beside the post. The stream waits.")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func countButton(_ label: String, icon: String, n: Int, on: Bool, counts: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: on ? .bold : .medium))
                if counts {
                    Text(nbCompactCount(n))
                        .font(.system(size: 15, weight: on ? .bold : .medium))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(color.opacity(on ? 1 : 0.9))
            .padding(.horizontal, 10)
            .frame(minWidth: 44, minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(counts ? "\(label), \(n)" : label)
    }
}

/// One reply in the conversation beat: who, how liked, what they said — easing in.
private struct StreamReplyCard: View {
    let reply: PostView
    let color: Color
    let serif: Bool
    let index: Int
    @ScaledMetric(relativeTo: .body) private var textSize: CGFloat = 20
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle()
                .fill(color.opacity(0.4))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    AvatarView(url: reply.author.avatar, size: 30)
                    Text(reply.author.displayName?.isEmpty == false ? reply.author.displayName! : reply.author.handle)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if let likes = reply.likeCount, likes > 0 {
                        Label(nbCompactCount(likes), systemImage: "heart")
                            .font(.system(size: 14, weight: .medium))
                            .opacity(0.7)
                    }
                }
                Text(strippedOfURLs(reply.record.text))
                    .font(streamFont(textSize, serif: serif))
                    .lineSpacing(3)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .blur(radius: appeared ? 0 : 8)
        .onAppear {
            if reduceMotion { appeared = true; return }
            withAnimation(.easeOut(duration: 0.7).delay(0.3 + Double(index) * 0.4)) { appeared = true }
        }
        .accessibilityElement(children: .combine)
    }
}
