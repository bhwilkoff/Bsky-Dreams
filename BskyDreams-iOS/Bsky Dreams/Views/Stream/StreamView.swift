import SwiftUI
import Combine
import SwiftData

// MARK: - Stream Data Models

private enum StreamSource: Equatable {
    case discover, following, search(String)
    var label: String {
        switch self {
        case .discover: "Discover"
        case .following: "Following"
        case .search(let q): q.isEmpty ? "Search" : q
        }
    }
    var shortLabel: String {
        switch self {
        case .discover: "DISCOVER"
        case .following: "FOLLOWING"
        case .search(let q): String(q.prefix(14)).uppercased()
        }
    }
}

private struct StreamLinkPresentation: Identifiable {
    let id = UUID()
    let card: ExternalCard
    let post: PostView?
}

private struct IndexedSlide: Identifiable {
    let slide: StreamSlide
    let postIndex: Int
    var id: String { slide.id }
}

private enum StreamSlide {
    case text(PostView)
    case image(PostView, EmbedImage, Int)
    case link(PostView, ExternalCard)
    case combined(PostView, EmbedImage)   // text + image on one slide

    var id: String {
        switch self {
        case .text(let p): "txt-\(p.uri)"
        case .image(let p, _, let i): "img-\(p.uri)-\(i)"
        case .link(let p, _): "lnk-\(p.uri)"
        case .combined(let p, let img): "cmb-\(p.uri)-\(img.id)"
        }
    }
    var post: PostView {
        switch self { case .text(let p): p; case .image(let p,_,_): p; case .link(let p,_): p; case .combined(let p,_): p }
    }
}

// MARK: - Color Palette

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

// MARK: - Orientation Helpers

private func requestPortrait() {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
    scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)) { _ in }
}

// MARK: - Text / URL Helpers (file-level so all slide structs can access them)

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

// MARK: - StreamView

struct StreamView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    // Persisted settings
    @AppStorage("stream_duration")       private var streamDuration: Double = 8.0
    @AppStorage("stream_filter")         private var streamFilter: String  = "all"
    @AppStorage("stream_bg_mode")        private var streamBgMode: String  = "random"
    @AppStorage("stream_show_alt_text")  private var showAltText: Bool     = true
    @AppStorage("stream_show_metrics")   private var showMetrics: Bool      = true
    @AppStorage("stream_combine_slides") private var combineSlides: Bool    = false
    @AppStorage("stream_prevent_sleep")  private var preventSleep: Bool     = false

    // Session state
    @State private var isLandscape = false
    @State private var streamingRequested = false
    @State private var slides: [IndexedSlide] = []
    @State private var currentIndex = 0
    @State private var isLoadingMore = false
    @State private var feedCursor: String? = nil
    @State private var source: StreamSource = .discover
    @State private var isPaused = false
    @State private var timerProgress: Double = 0
    @State private var slideDirection: Int = 1
    @State private var showSourcePicker = false
    @State private var searchInput = ""
    @State private var linkPresentation: StreamLinkPresentation? = nil
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var seenURISet: Set<String> = []
    @State private var controlsVisible = true
    @State private var controlsHideTask: Task<Void, Never>? = nil

    private let seenMaxAge: TimeInterval = 7 * 24 * 3600

    private let discoverURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"

    // MARK: - Body

    var body: some View {
        Group {
            if streamingRequested {
                turnPhoneScreen
                    .nbNavBar(title: "STREAM", leading: { NBHamburger() })
            } else {
                setupScreen
                    .nbNavBar(title: "STREAM", leading: { NBHamburger() })
            }
        }
        // streamPlayer opens as a true full-screen cover so the sidebar is completely hidden.
        // It only becomes isLandscape=true once the timer confirms the interface actually
        // rotated — we never force rotation programmatically.
        .fullScreenCover(isPresented: $isLandscape, onDismiss: {
            stopTimer()
            stopControlTimer()
            UIApplication.shared.isIdleTimerDisabled = false
            AppDelegate.streamingActive = false
            streamingRequested = false
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            requestPortrait()
        }) {
            streamPlayer
        }
        .onChange(of: verticalSizeClass) { _, new in
            let nowLandscape = streamingRequested && new == .compact
            if nowLandscape && !isLandscape {
                isLandscape = true
                Task {
                    await loadSeenURIs()
                    if slides.isEmpty && !isLoadingMore { await loadMore() }
                    if !isPaused { startTimer() }
                }
            } else if !nowLandscape && isLandscape {
                isLandscape = false
            }
        }
        .onDisappear {
            stopTimer()
            stopControlTimer()
            UIApplication.shared.isIdleTimerDisabled = false
            isLandscape = false
            AppDelegate.streamingActive = false
            streamingRequested = false
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
        .onChange(of: streamFilter) { _, _ in resetSlides() }
        .onChange(of: combineSlides) { _, _ in resetSlides() }
    }

    private func resetSlides() {
        slides = []
        feedCursor = nil
        currentIndex = 0
        if isLandscape { Task { await loadMore() } }
    }

    // MARK: - Setup Screen

    private var setupScreen: some View {
        ScrollView {
            VStack(spacing: 0) {
                setupHero
                VStack(spacing: 16) {
                    feedSourceSection
                    settingsSection
                    startButton
                }
                .padding(16)
            }
        }
    }

    private var setupHero: some View {
        ZStack {
            DiagonalStripeBackground()
            HStack(spacing: 14) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.nbAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("STREAM")
                        .font(.syne(22, weight: .bold))
                        .foregroundStyle(Color.nbBlack)
                    Text("One post at a time, full-screen in landscape")
                        .font(.inter(13))
                        .foregroundStyle(Color.nbTextSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .nbBorder()
        .padding(.bottom, 4)
    }

    private var feedSourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FEED SOURCE")
                .font(.syne(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.nbTextTertiary)

            // Segmented toggle — single outer border, no nested boxes
            HStack(spacing: 0) {
                sourcePill(label: "Discover", src: .discover)
                sourcePill(label: "Following", src: .following)
            }
            .nbBorder()

            // Search field beside SET button — two separate bordered elements (Analytics pattern)
            HStack(alignment: .bottom, spacing: 8) {
                NBTextField(placeholder: "Search a keyword or topic…", text: $searchInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                let canSet = !searchInput.trimmingCharacters(in: .whitespaces).isEmpty
                Text("SET")
                    .font(.syne(12, weight: .bold))
                    .foregroundStyle(canSet ? .white : Color.nbTextTertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(canSet ? Color.nbAccent : Color.nbWhite)
                    .overlay(Rectangle().strokeBorder(
                        Color.nbBlack.opacity(canSet ? 1 : 0.3), lineWidth: 2))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let q = searchInput.trimmingCharacters(in: .whitespaces)
                        guard !q.isEmpty else { return }
                        source = .search(q); slides = []; feedCursor = nil
                    }
            }

            // Active search chip
            if case .search(let q) = source {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.nbAccent)
                    Text("Streaming: \"\(q)\"")
                        .font(.inter(12))
                        .foregroundStyle(Color.nbAccent)
                    Spacer()
                    Button { source = .discover; searchInput = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.nbTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var settingsSection: some View {
        settingsCard(title: "STREAM SETTINGS") {
            VStack(spacing: 0) {
                // Duration
                settingsRow(label: "Seconds Per Post") {
                    HStack(spacing: 0) {
                        ForEach([3.0, 5.0, 8.0, 15.0, 30.0], id: \.self) { d in
                            durationPill(d)
                        }
                    }
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 1.5))
                }
                nbDivider()

                // Content filter
                settingsRow(label: "Content Type") {
                    HStack(spacing: 0) {
                        filterPill("ALL",    value: "all")
                        filterPill("TEXT",   value: "text")
                        filterPill("IMAGES", value: "images")
                    }
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 1.5))
                }
                nbDivider()

                // Background color
                settingsRow(label: "Background Color") {
                    VStack(spacing: 0) {
                        bgPill(label: "RANDOM", value: "random")
                            .frame(maxWidth: .infinity)
                            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 1.5))
                        HStack(spacing: 0) {
                            ForEach(streamPaletteHex, id: \.self) { hex in
                                colorBgPill(hex: hex)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 1.5))
                    }
                }
                nbDivider()

                // Toggles
                toggleRow(label: "Show Post Metrics", value: $showMetrics)
                nbDivider()
                toggleRow(label: "Show Alt Text", value: $showAltText)
                nbDivider()
                VStack(alignment: .leading, spacing: 2) {
                    toggleRow(label: "Combine Text + Image", value: $combineSlides)
                    Text("Show text and image together on one slide")
                        .font(.inter(11))
                        .foregroundStyle(Color.nbTextTertiary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                }
                nbDivider()
                VStack(alignment: .leading, spacing: 2) {
                    toggleRow(label: "Keep Screen Awake", value: $preventSleep)
                    Text("Prevent auto-lock while streaming")
                        .font(.inter(11))
                        .foregroundStyle(Color.nbTextTertiary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                }
            }
        }
    }

    private var startButton: some View {
        Button {
            streamingRequested = true
            // Start listening for physical device rotation. streamingActive is NOT set
            // here — it's only set once the device physically tilts to landscape, so iOS
            // never auto-rotates just from pressing START.
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("START STREAMING")
                    .font(.syne(16, weight: .bold))
                    .tracking(1)
            }
            // Always white — accent colors (blue, coral, purple) all need white text
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.nbAccent)
            .nbBorder()        // single crisp 2pt border
            .nbShadow(size: 4) // design-system block shadow, not SwiftUI .shadow()
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    // MARK: - Turn Phone Screen

    private var turnPhoneScreen: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.nbAccent)
                    .frame(width: 120, height: 120)
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 3))
                    .shadow(color: Color.nbBlack, radius: 0, x: 4, y: 4)
                Image(systemName: "rotate.right")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 10) {
                Text("Turn your phone\nto landscape")
                    .font(.syne(28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.nbBlack)
                Text("Rotate your device sideways to start the stream.")
                    .font(.inter(15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.nbTextSecondary)
                    .padding(.horizontal, 40)
            }
            Spacer()
            Button {
                streamingRequested = false
                AppDelegate.streamingActive = false
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = scene.windows.first?.rootViewController {
                    rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            } label: {
                Text("CANCEL")
                    .font(.syne(14, weight: .bold))
                    .foregroundStyle(Color.nbBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.nbWhite)
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        // Listen for PHYSICAL device rotation — unlock landscape only when the user
        // actually tilts their phone, never on button press.
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let deviceOri = UIDevice.current.orientation
            if deviceOri.isLandscape && streamingRequested && !AppDelegate.streamingActive {
                // Device physically tilted — now allow landscape
                AppDelegate.streamingActive = true
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = scene.windows.first?.rootViewController {
                    rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
                // The 1-second timer (below) detects when the interface actually rotates
            } else if deviceOri.isPortrait && isLandscape {
                // Physically rotated back — dismiss the stream cover
                isLandscape = false
            }
        }
        // Poll interface orientation as a fallback (verticalSizeClass doesn't always propagate)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            let landscape = scene.interfaceOrientation == .landscapeLeft
                         || scene.interfaceOrientation == .landscapeRight
            if landscape && streamingRequested && !isLandscape {
                isLandscape = true
                // Load seen URIs first so the first batch is already filtered
                Task {
                    await loadSeenURIs()
                    if slides.isEmpty && !isLoadingMore { await loadMore() }
                    if !isPaused { startTimer() }
                }
            }
        }
    }

    // MARK: - Stream Player (landscape, presented as fullScreenCover)

    private var streamPlayer: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top bar — fades out after 3s of inactivity ───────────────────────
                HStack(spacing: 8) {
                    Button { showSourcePicker = true; resetControlTimer() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 11, weight: .bold))
                            Text(source.shortLabel)
                                .font(.syne(11, weight: .bold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(controlFg)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(controlBg)
                        .overlay(Rectangle().strokeBorder(controlBorder, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Reply — navigate to conversation view for the current slide's post
                    if let post = currentSlide?.slide.post {
                        Button {
                            resetControlTimer()
                            stopTimer()
                            isLandscape = false
                            // Dispatch navigation after the fullscreen cover dismisses
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(400))
                                store.navigationPath.append(PostDestination(uri: post.uri, post: post))
                            }
                        } label: {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(controlFg)
                                .frame(width: 32, height: 32)
                                .background(controlBg)
                                .overlay(Rectangle().strokeBorder(controlBorder, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        isPaused.toggle()
                        isPaused ? stopTimer() : startTimer()
                        resetControlTimer()
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(controlFg)
                            .frame(width: 32, height: 32)
                            .background(controlBg)
                            .overlay(Rectangle().strokeBorder(controlBorder, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)

                    Button { isLandscape = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(controlFg)
                            .frame(width: 32, height: 32)
                            .background(controlBg)
                            .overlay(Rectangle().strokeBorder(controlBorder, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .opacity(controlsVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: controlsVisible)
                .offset(y: controlsVisible ? 0 : -8)

                // ── Progress bar — always visible ─────────────────────────────────────
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(textColor.opacity(0.25)).frame(height: 3)
                        Rectangle()
                            .fill(textColor)
                            .frame(width: max(0, geo.size.width * timerProgress), height: 3)
                            .animation(.linear(duration: 0.12), value: timerProgress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 14)
                .padding(.top, 5)
                .padding(.bottom, 6)

                // ── Slide content — tap anywhere to wake controls ──────────────────────
                ZStack {
                    if isLoadingMore && slides.isEmpty {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(controlFg)
                            .scaleEffect(1.5)
                    } else if let slide = currentSlide {
                        slideContent(slide)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id(slide.id)
                            .transition(.asymmetric(
                                insertion: slideDirection >= 0
                                    ? .move(edge: .trailing).combined(with: .opacity)
                                    : .move(edge: .leading).combined(with: .opacity),
                                removal: slideDirection >= 0
                                    ? .move(edge: .leading).combined(with: .opacity)
                                    : .move(edge: .trailing).combined(with: .opacity)
                            ))
                            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: currentIndex)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { resetControlTimer() }

                // ── Bottom — slide dots only; swipe to navigate ───────────────────────
                slideDots
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .opacity(controlsVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: controlsVisible)
                    .offset(y: controlsVisible ? 0 : 8)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 44)
                .onEnded { val in
                    resetControlTimer()
                    guard abs(val.translation.width) > abs(val.translation.height) else { return }
                    if val.translation.width < 0 { advance() } else { retreat() }
                }
        )
        .onAppear {
            if preventSleep { UIApplication.shared.isIdleTimerDisabled = true }
            resetControlTimer()
        }
        .onChange(of: currentIndex) { _, _ in markCurrentSlideAsSeen() }
        .sheet(isPresented: $showSourcePicker) { sourcePickerSheet }
        .fullScreenCover(item: $linkPresentation) { pres in
            ArticleReaderSheet(card: pres.card, post: pres.post)
                .onDisappear { if !isPaused { startTimer() } }
        }
    }

    @ViewBuilder
    private func slideContent(_ indexed: IndexedSlide) -> some View {
        switch indexed.slide {
        case .text(let post):
            LandscapeTextSlide(post: post, textColor: textColor, showMetrics: showMetrics)
        case .image(let post, let img, _):
            LandscapeImageSlide(
                post: post, image: img, textColor: textColor, bgColor: bgColor,
                showAltText: showAltText, showMetrics: showMetrics
            )
        case .combined(let post, let img):
            LandscapeCombinedSlide(
                post: post, image: img, textColor: textColor,
                showAltText: showAltText, showMetrics: showMetrics
            )
        case .link(let post, let card):
            LandscapeLinkSlide(post: post, card: card, textColor: textColor) {
                stopTimer()
                linkPresentation = StreamLinkPresentation(card: card, post: post)
            }
        }
    }

    @ViewBuilder
    private var slideDots: some View {
        if let slide = currentSlide {
            let postURI = slide.slide.post.uri
            let postSlides = slides.filter { $0.slide.post.uri == postURI }
            let activeIdx = postSlides.firstIndex(where: { $0.id == slide.id }) ?? 0
            HStack(spacing: 5) {
                ForEach(0..<postSlides.count, id: \.self) { i in
                    Circle()
                        .fill(i == activeIdx ? textColor : textColor.opacity(0.3))
                        .frame(width: i == activeIdx ? 8 : 5, height: i == activeIdx ? 8 : 5)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: activeIdx)
        }
    }

    // MARK: - Source Picker Sheet

    private var sourcePickerSheet: some View {
        VStack(spacing: 0) {
            // ── Custom Neubrutalist header — no NavigationStack ──────────────────
            HStack {
                Text("STREAM SOURCE")
                    .font(.syne(16, weight: .bold))
                    .foregroundStyle(Color.nbBlack)
                Spacer()
                Button {
                    showSourcePicker = false
                    if slides.isEmpty { Task { await loadMore() } }
                } label: {
                    Text("DONE")
                        .font(.syne(13, weight: .bold))
                        .foregroundStyle(Color.nbAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .overlay(Rectangle().strokeBorder(Color.nbAccent, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.nbWhite)

            Divider()

            // ── Content ───────────────────────────────────────────────────────────
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    sourcePill(label: "Discover", src: .discover)
                    sourcePill(label: "Following", src: .following)
                }
                .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))

                HStack(spacing: 0) {
                    NBTextField(placeholder: "Search a topic…", text: $searchInput)
                    Button {
                        let q = searchInput.trimmingCharacters(in: .whitespaces)
                        guard !q.isEmpty else { return }
                        source = .search(q); slides = []; feedCursor = nil
                        showSourcePicker = false
                        Task { await loadMore() }
                    } label: {
                        Text("GO")
                            .font(.syne(13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(Color.nbAccent)
                    }
                    .buttonStyle(.plain)
                }
                .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
            }
            .padding(16)
            .background(Color.nbBackground)

            Spacer()
        }
        .background(Color.nbBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

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
            if source != src { source = src; slides = []; feedCursor = nil }
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

    // MARK: - Computed Color State

    private func resolvedColor(postIndex: Int) -> (bg: Color, lightText: Bool) {
        if streamBgMode == "random" {
            return streamPalette[abs(postIndex) % streamPalette.count]
        }
        let isLight = lightTextHex.contains(streamBgMode.uppercased())
        return (Color(hex: streamBgMode), isLight)
    }

    private var currentSlide: IndexedSlide? {
        guard !slides.isEmpty else { return nil }
        return slides[max(0, min(currentIndex, slides.count - 1))]
    }

    private var bgColor: Color {
        guard let s = currentSlide else { return Color(hex: "#0047FF") }
        return resolvedColor(postIndex: s.postIndex).bg
    }

    private var isLightText: Bool {
        guard let s = currentSlide else { return true }
        return resolvedColor(postIndex: s.postIndex).lightText
    }

    private var textColor: Color  { isLightText ? .white : Color(hex: "#0A0A0A") }
    // Control colors use fixed hex so dark-mode system theming never makes them gray-on-gray.
    private var controlBg: Color  { isLightText ? Color(hex: "#FFFFFF") : Color(hex: "#0A0A0A") }
    private var controlFg: Color  { isLightText ? Color(hex: "#0A0A0A") : Color(hex: "#FFFFFF") }
    private var controlBorder: Color { isLightText ? Color(hex: "#0A0A0A") : Color(hex: "#FFFFFF").opacity(0.6) }

    // MARK: - Navigation

    private func advance() {
        guard !slides.isEmpty else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            slideDirection = 1
            if currentIndex < slides.count - 1 { currentIndex += 1 }
        }
        resetTimer()
        if currentIndex >= slides.count - 6 { Task { await loadMore() } }
    }

    private func retreat() {
        guard currentIndex > 0 else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            slideDirection = -1
            currentIndex -= 1
        }
        resetTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            let steps = 80
            let interval = streamDuration / Double(steps)
            for i in 1...steps {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                timerProgress = Double(i) / Double(steps)
            }
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private func stopTimer() { timerTask?.cancel(); timerTask = nil }
    private func resetTimer() { timerProgress = 0; if !isPaused { startTimer() } }

    // MARK: - Control Auto-Hide

    private func resetControlTimer() {
        controlsHideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) { controlsVisible = true }
        controlsHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { controlsVisible = false }
        }
    }

    private func stopControlTimer() {
        controlsHideTask?.cancel()
        controlsHideTask = nil
    }

    // MARK: - Feed Loading

    // MARK: - Seen Posts

    private func loadSeenURIs() async {
        let cutoff = Date().addingTimeInterval(-seenMaxAge)
        let descriptor = FetchDescriptor<SeenPost>(
            predicate: #Predicate<SeenPost> { $0.seenAt > cutoff }
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        seenURISet = Set(records.map { $0.uri })
    }

    private func markCurrentSlideAsSeen() {
        guard let slide = currentSlide else { return }
        let uri = slide.slide.post.uri
        guard !seenURISet.contains(uri) else { return }
        seenURISet.insert(uri)
        modelContext.insert(SeenPost(uri: uri))
    }

    // MARK: - Feed Loading

    private func loadMore() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let nextPostIdx = (slides.last?.postIndex ?? -1) + 1
        do {
            var posts: [PostView] = []
            var nextCursor: String? = nil
            switch source {
            case .discover:
                let r = try await ATProtocolClient.shared.getFeed(uri: discoverURI, limit: 20, cursor: feedCursor)
                posts = r.feed.map { $0.post }; nextCursor = r.cursor
            case .following:
                let r = try await ATProtocolClient.shared.getTimeline(limit: 20, cursor: feedCursor)
                posts = r.feed.map { $0.post }; nextCursor = r.cursor
            case .search(let q):
                let r = try await ATProtocolClient.shared.searchPosts(q: q, sort: "latest", limit: 20, cursor: feedCursor)
                posts = r.posts; nextCursor = r.cursor
            }
            let newSlides = posts.enumerated().flatMap { i, post in
                buildSlidesFromPost(post, postIndex: nextPostIdx + i)
            }
            slides.append(contentsOf: newSlides)
            feedCursor = nextCursor
        } catch { /* continue with loaded content */ }
    }

    private func buildSlidesFromPost(_ post: PostView, postIndex: Int) -> [IndexedSlide] {
        // Skip posts the user has already seen
        guard !seenURISet.contains(post.uri) else { return [] }

        let rawText = post.record.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !rawText.isEmpty
        let imgs = post.embed?.images ?? []
        // Filter out video links (YouTube, Vimeo, etc.) — they render as dead thumbnails
        let ext: ExternalCard? = {
            guard let e = post.embed?.external, !isVideoURL(e.uri) else { return nil }
            return e
        }()

        switch streamFilter {
        case "text":
            guard hasText && imgs.isEmpty && ext == nil else { return [] }
            return [IndexedSlide(slide: .text(post), postIndex: postIndex)]
        case "images":
            guard !imgs.isEmpty else { return [] }
            if combineSlides && hasText, let first = imgs.first {
                var result = [IndexedSlide(slide: .combined(post, first), postIndex: postIndex)]
                for (i, img) in imgs.dropFirst().enumerated() {
                    result.append(IndexedSlide(slide: .image(post, img, i + 1), postIndex: postIndex))
                }
                return result
            }
            return imgs.enumerated().map { i, img in IndexedSlide(slide: .image(post, img, i), postIndex: postIndex) }
        default: // "all"
            if combineSlides && hasText && !imgs.isEmpty, let first = imgs.first {
                var result = [IndexedSlide(slide: .combined(post, first), postIndex: postIndex)]
                for (i, img) in imgs.dropFirst().enumerated() {
                    result.append(IndexedSlide(slide: .image(post, img, i + 1), postIndex: postIndex))
                }
                if let ext { result.append(IndexedSlide(slide: .link(post, ext), postIndex: postIndex)) }
                return result
            }
            var slides: [StreamSlide] = []
            if hasText { slides.append(.text(post)) }
            for (i, img) in imgs.enumerated() { slides.append(.image(post, img, i)) }
            if let ext { slides.append(.link(post, ext)) }
            if slides.isEmpty { slides.append(.text(post)) }
            return slides.map { IndexedSlide(slide: $0, postIndex: postIndex) }
        }
    }
}

// MARK: - Landscape Text Slide

private struct LandscapeTextSlide: View {
    let post: PostView
    let textColor: Color
    let showMetrics: Bool

    private var displayText: String { strippedOfURLs(post.record.text) }

    private var fontSize: CGFloat {
        let len = displayText.count
        if len < 60  { return 42 }
        if len < 120 { return 32 }
        if len < 200 { return 24 }
        return 18
    }
    private var useSyne: Bool { displayText.count < 200 }

    var body: some View {
        VStack(spacing: 0) {
            // Author bar
            HStack(spacing: 10) {
                AvatarView(url: post.author.avatar, size: 28)
                    .overlay(Circle().strokeBorder(textColor.opacity(0.4), lineWidth: 1.5))
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.author.displayName ?? post.author.handle)
                        .font(.syne(14, weight: .bold))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                    Text("@\(post.author.handle)")
                        .font(.inter(11))
                        .foregroundStyle(textColor.opacity(0.65))
                }
                Spacer()
                Text(post.relativeTime)
                    .font(.inter(12))
                    .foregroundStyle(textColor.opacity(0.55))
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Main text — large, centered, filling the landscape area
            Spacer()
            Text(displayText)
                .font(useSyne ? .custom("Syne-Bold", size: fontSize) : .inter(fontSize))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .lineSpacing(useSyne ? 4 : 3)
                .padding(.horizontal, 48)
                .frame(maxWidth: .infinity)
                .minimumScaleFactor(0.6)
            Spacer()

            // Stats bar
            if showMetrics {
                HStack(spacing: 0) {
                    Spacer()
                    statChip(icon: "bubble.left", count: post.replyCount, color: textColor)
                    statChip(icon: "arrow.2.squarepath", count: post.repostCount, color: textColor)
                    statChip(icon: "heart", count: post.likeCount, color: textColor)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            } else {
                Color.clear.frame(height: 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statChip(icon: String, count: Int?, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11))
            Text("\(count ?? 0)").font(.inter(12))
        }
        .foregroundStyle(color.opacity(0.55))
        .padding(.horizontal, 12)
    }
}

// MARK: - Landscape Image Slide

private struct LandscapeImageSlide: View {
    let post: PostView
    let image: EmbedImage
    let textColor: Color
    let bgColor: Color
    let showAltText: Bool
    let showMetrics: Bool

    private var postText: String { strippedOfURLs(post.record.text) }
    private var hasText: Bool { !postText.isEmpty }

    var body: some View {
        if hasText {
            splitLayout
        } else {
            fullScreenLayout
        }
    }

    // Image left (38%), text right (62%)
    private var splitLayout: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
            // Left: image at 38% of width
            AsyncImage(url: URL(string: image.fullsize)) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                        .frame(width: geo.size.width * 0.38, height: geo.size.height)
                        .clipped()
                } else if phase.error != nil {
                    Rectangle().fill(textColor.opacity(0.1))
                        .frame(width: geo.size.width * 0.38)
                        .overlay(Image(systemName: "photo").foregroundStyle(textColor.opacity(0.4)))
                } else {
                    Rectangle().fill(textColor.opacity(0.08))
                        .frame(width: geo.size.width * 0.38)
                        .overlay(ProgressView().tint(textColor))
                }
            }
            .frame(width: geo.size.width * 0.38, height: geo.size.height)
            .clipped()

            // Vertical separator
            Rectangle()
                .fill(textColor.opacity(0.2))
                .frame(width: 2)

            // Right: author + text + stats at 62%
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    AvatarView(url: post.author.avatar, size: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.author.displayName ?? post.author.handle)
                            .font(.syne(12, weight: .bold))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                        Text("@\(post.author.handle)")
                            .font(.inter(10))
                            .foregroundStyle(textColor.opacity(0.6))
                    }
                    Spacer()
                    Text(post.relativeTime)
                        .font(.inter(10))
                        .foregroundStyle(textColor.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                Spacer()

                Text(postText)
                    .font(postText.count < 160 ? .custom("Syne-Bold", size: 22) : .inter(16))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .minimumScaleFactor(0.65)

                Spacer()

                if showAltText && !image.alt.isEmpty {
                    Text("ALT: \(image.alt)")
                        .font(.inter(10))
                        .foregroundStyle(textColor.opacity(0.5))
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                if showMetrics {
                    HStack(spacing: 12) {
                        metricChip(icon: "bubble.left", count: post.replyCount)
                        metricChip(icon: "arrow.2.squarepath", count: post.repostCount)
                        metricChip(icon: "heart", count: post.likeCount)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                } else {
                    Color.clear.frame(height: 12)
                }
            }
            .frame(width: geo.size.width * 0.62 - 2)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // Full-screen image with overlay
    private var fullScreenLayout: some View {
        ZStack {
            AsyncImage(url: URL(string: image.fullsize)) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if phase.error != nil {
                    Image(systemName: "photo").font(.system(size: 48)).foregroundStyle(textColor.opacity(0.4))
                } else {
                    ProgressView().tint(textColor)
                }
            }

            VStack {
                HStack(spacing: 8) {
                    AvatarView(url: post.author.avatar, size: 24)
                    Text("@\(post.author.handle)")
                        .font(.syne(12, weight: .bold))
                        .foregroundStyle(textColor)
                    Spacer()
                    Text(post.relativeTime)
                        .font(.inter(11))
                        .foregroundStyle(textColor.opacity(0.7))
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                Spacer()
                if showAltText && !image.alt.isEmpty {
                    Text(image.alt)
                        .font(.inter(12))
                        .foregroundStyle(textColor.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func metricChip(icon: String, count: Int?) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10))
            Text("\(count ?? 0)").font(.inter(11))
        }
        .foregroundStyle(textColor.opacity(0.55))
    }
}

// MARK: - Landscape Combined Slide (text + image side by side)

private struct LandscapeCombinedSlide: View {
    let post: PostView
    let image: EmbedImage
    let textColor: Color
    let showAltText: Bool
    let showMetrics: Bool

    private var postText: String { strippedOfURLs(post.record.text) }

    var body: some View {
        // Use GeometryReader to give text 62% and image 38% — prevents large
        // images from crowding out the post text.
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left: post text (62%)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        AvatarView(url: post.author.avatar, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(post.author.displayName ?? post.author.handle)
                                .font(.syne(13, weight: .bold))
                                .foregroundStyle(textColor)
                                .lineLimit(1)
                            Text("@\(post.author.handle)")
                                .font(.inter(10))
                                .foregroundStyle(textColor.opacity(0.6))
                        }
                        Spacer()
                        Text(post.relativeTime)
                            .font(.inter(10))
                            .foregroundStyle(textColor.opacity(0.5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    Spacer()

                    Text(postText)
                        .font(postText.count < 160 ? .custom("Syne-Bold", size: 24) : .inter(17))
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                        .minimumScaleFactor(0.6)

                    Spacer()

                    if showMetrics {
                        HStack(spacing: 14) {
                            metricChip(icon: "bubble.left", count: post.replyCount)
                            metricChip(icon: "arrow.2.squarepath", count: post.repostCount)
                            metricChip(icon: "heart", count: post.likeCount)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    } else {
                        Color.clear.frame(height: 12)
                    }
                }
                .frame(width: geo.size.width * 0.62, height: geo.size.height)

                // Separator
                Rectangle()
                    .fill(textColor.opacity(0.2))
                    .frame(width: 2)

                // Right: image (38%)
                ZStack(alignment: .bottom) {
                    AsyncImage(url: URL(string: image.fullsize)) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                                .frame(width: geo.size.width * 0.38 - 2, height: geo.size.height)
                                .clipped()
                        } else if phase.error != nil {
                            Rectangle().fill(textColor.opacity(0.1))
                                .overlay(Image(systemName: "photo").foregroundStyle(textColor.opacity(0.3)))
                        } else {
                            Rectangle().fill(textColor.opacity(0.08))
                                .overlay(ProgressView().tint(textColor))
                        }
                    }
                    .frame(width: geo.size.width * 0.38 - 2, height: geo.size.height)

                    if showAltText && !image.alt.isEmpty {
                        Text(image.alt)
                            .font(.inter(10))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .padding(8)
                    }
                }
                .frame(width: geo.size.width * 0.38 - 2, height: geo.size.height)
                .clipped()
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func metricChip(icon: String, count: Int?) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10))
            Text("\(count ?? 0)").font(.inter(11))
        }
        .foregroundStyle(textColor.opacity(0.55))
    }
}

// MARK: - Landscape Link Slide

private struct LandscapeLinkSlide: View {
    let post: PostView
    let card: ExternalCard
    let textColor: Color
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Left: thumbnail (42%)
            Button(action: onTap) {
                ZStack(alignment: .topLeading) {
                    if let thumbStr = card.thumb, let url = URL(string: thumbStr) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFill()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                            } else {
                                Rectangle().fill(textColor.opacity(0.1))
                                    .overlay(Image(systemName: "link").font(.system(size: 32)).foregroundStyle(textColor.opacity(0.3)))
                            }
                        }
                    } else {
                        Rectangle().fill(textColor.opacity(0.1))
                            .overlay(Image(systemName: "link").font(.system(size: 32)).foregroundStyle(textColor.opacity(0.3)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .buttonStyle(.plain)

            // Separator
            Rectangle()
                .fill(textColor.opacity(0.2))
                .frame(width: 2)

            // Right: author + card info (58%)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    AvatarView(url: post.author.avatar, size: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.author.displayName ?? post.author.handle)
                            .font(.syne(12, weight: .bold))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                        Text("@\(post.author.handle)")
                            .font(.inter(10))
                            .foregroundStyle(textColor.opacity(0.6))
                    }
                    Spacer()
                    Text(post.relativeTime)
                        .font(.inter(10))
                        .foregroundStyle(textColor.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                Spacer()

                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let host = URL(string: card.uri)?.host {
                            Text(host.uppercased())
                                .font(.syne(10, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(textColor.opacity(0.55))
                        }
                        Text(card.title)
                            .font(.syne(20, weight: .bold))
                            .foregroundStyle(textColor)
                            .lineLimit(3)
                        if !card.description.isEmpty {
                            Text(card.description)
                                .font(.inter(13))
                                .foregroundStyle(textColor.opacity(0.8))
                                .lineLimit(3)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack {
                    Label("Tap to read article", systemImage: "arrow.up.right.square")
                        .font(.inter(11))
                        .foregroundStyle(textColor.opacity(0.5))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
