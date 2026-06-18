import SwiftUI
import SwiftData
import WebKit
import NaturalLanguage

// MARK: - Article language detection
//
// The Reader displays the linked ARTICLE, whose language is independent of the post's
// `langs` tag (which is often absent entirely — and `PostView.isEnglish` treats absent
// as English, so non-English articles leaked through). Detect the article's own language
// from its card text using Apple's on-device NLLanguageRecognizer (free, no network).

/// True unless `text` is confidently a non-English language. Empty/short/ambiguous → true
/// (we don't over-filter when we genuinely can't tell).
private func textLooksEnglish(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= 16 else { return true }
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(trimmed)
    guard let dominant = recognizer.dominantLanguage else { return true }
    if dominant == .english { return true }
    // Non-English is the best guess — only reject if English isn't a close runner-up
    // (handles bilingual / English-with-loanwords cards).
    let englishProbability = recognizer.languageHypotheses(withMaximum: 3)[.english] ?? 0
    return englishProbability >= 0.45
}

/// Decide whether a Reader article is English. Prefers the article's OWN text (card
/// title + description); falls back to explicit post `langs`, then the post text.
func articleIsEnglish(post: PostView, card: ExternalCard) -> Bool {
    let articleText = (card.title + ". " + card.description).trimmingCharacters(in: .whitespacesAndNewlines)
    if articleText.count >= 16 { return textLooksEnglish(articleText) }
    // Too little article text — honor an explicit language tag if present.
    if let langs = post.record.langs, !langs.isEmpty {
        return langs.contains { $0.hasPrefix("en") }
    }
    // Last resort: judge from the post body, else allow.
    return textLooksEnglish(post.record.text)
}

struct ReaderView: View {
    private let discoverURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"
    private let newsFeedURI = "at://did:plc:kkf4naxqmweop7dv4l2iqqf5/app.bsky.feed.generator/verified-news"

    @Environment(\.modelContext) private var modelContext
    @Environment(NetworkMonitor.self) private var network
    @State private var articles: [PostView] = []
    @State private var timelineCursor: String?
    @State private var discoverCursor: String?
    @State private var newsCursor: String?
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var selectedArticle: PostView? = nil
    @State private var readURLs: Set<String> = []
    // In-memory seen-URI cache — avoids @Query cascade re-renders on every
    // mark-seen insert (same pattern as FeedView).
    @State private var seenURISet: Set<String> = []
    @State private var autoFetchCount = 0

    /// Pre-filtered: only articles that actually have an external card.
    /// Prevents empty/invisible rows in the LazyVStack.
    private var articlesWithCards: [(post: PostView, card: ExternalCard)] {
        articles.compactMap { post in
            guard let card = post.embed?.external else { return nil }
            return (post: post, card: card)
        }
    }

    var body: some View {
        Group {
            if (isLoading || !hasLoaded) && articles.isEmpty {
                loadingState
            } else if let err = errorMessage, articles.isEmpty, !network.isOffline {
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
            } else {
                articleList
            }
        }
        .nbNavBar(title: "READER", leading: { NBHamburger() })
        .task {
            // Load seen URIs from SwiftData once, then manage in memory
            if seenURISet.isEmpty {
                let descriptor = FetchDescriptor<SeenPost>()
                seenURISet = Set((try? modelContext.fetch(descriptor))?.map { $0.uri } ?? [])
            }
            await load()
        }
    }

    private var articleList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if network.isOffline {
                    NBOfflineBanner()
                        .padding(.horizontal, 8)
                        .padding(.top, 10)
                }

                if let err = errorMessage, !articlesWithCards.isEmpty {
                    NBErrorBanner(message: err) {
                        Task { await load() }
                    }
                    .padding(.top, 10)
                }

                HintBanner(id: "reader.welcome", text: "Tap an article to read it distraction-free in Readable mode.")
                    .padding(.top, 10)

                if articlesWithCards.isEmpty && !isLoading && errorMessage == nil {
                    NBEmptyState(
                        icon: "doc.text",
                        title: "You're all caught up",
                        message: "No new articles right now",
                        actionTitle: "Refresh",
                        action: {
                            Task {
                                let descriptor = FetchDescriptor<SeenPost>()
                                seenURISet = Set((try? modelContext.fetch(descriptor))?.map { $0.uri } ?? [])
                                articles = []
                                timelineCursor = nil
                                discoverCursor = nil
                                newsCursor = nil
                                await load()
                            }
                        }
                    )
                    .padding(.top, 40)
                }

                ForEach(articlesWithCards, id: \.post.uri) { item in
                    ArticleCardView(
                        post: item.post,
                        card: item.card,
                        isRead: readURLs.contains(item.card.uri)
                    ) {
                        readURLs.insert(item.card.uri)
                        selectedArticle = item.post
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .opacity(readURLs.contains(item.card.uri) ? 0.5 : 1.0)
                    .onAppear {
                        markSeenPost(item.post)
                        // Trigger next page within last 5 articles
                        let count = articlesWithCards.count
                        if let idx = articlesWithCards.firstIndex(where: { $0.post.uri == item.post.uri }),
                           idx >= count - 5 {
                            Task { await load(loadMore: true) }
                        }
                    }
                }
                if isLoading && !articles.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            // Re-sync seen set from SwiftData so cloud-merged posts are respected
            let descriptor = FetchDescriptor<SeenPost>()
            seenURISet = Set((try? modelContext.fetch(descriptor))?.map { $0.uri } ?? [])
            articles = []
            timelineCursor = nil
            discoverCursor = nil
            newsCursor = nil
            await load()
        }
        .sheet(item: $selectedArticle) { post in
            if let card = post.embed?.external {
                ArticleReaderSheet(card: card, post: post)
            }
        }
    }

    private var loadingState: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if network.isOffline {
                    NBOfflineBanner()
                        .padding(.horizontal, 8)
                        .padding(.top, 10)
                }
                ForEach(0..<5, id: \.self) { _ in
                    NBSkeletonPostRow()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load(loadMore: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            // Fetch home timeline, discover, AND verified news feed in parallel
            async let homeResult = ATProtocolClient.shared.getTimeline(
                limit: 50, cursor: loadMore ? timelineCursor : nil
            )
            async let discoverResult = try? ATProtocolClient.shared.getFeed(
                uri: discoverURI, limit: 30, cursor: loadMore ? discoverCursor : nil
            )
            async let newsResult = try? ATProtocolClient.shared.getFeed(
                uri: newsFeedURI, limit: 30, cursor: loadMore ? newsCursor : nil
            )

            let home = try await homeResult
            let discover = await discoverResult
            let news = await newsResult

            timelineCursor = home.cursor
            if let discover { discoverCursor = discover.cursor }
            if let news { newsCursor = news.cursor }

            let allItems = home.feed + (discover?.feed ?? []) + (news?.feed ?? [])
            let filtered = allItems.compactMap { item -> PostView? in
                guard !item.post.isAdultContent else { return nil }
                guard let ext = item.post.embed?.external else { return nil }
                guard isReadableArticle(ext) else { return nil }
                // Filter on the ARTICLE's language (card text), not the post's lang tag.
                guard articleIsEnglish(post: item.post, card: ext) else { return nil }
                guard !seenURISet.contains(item.post.uri) else { return nil }
                return item.post
            }

            if loadMore {
                let existingUris = Set(articles.map { $0.uri })
                let newArticles = filtered.filter { !existingUris.contains($0.uri) }
                articles.append(contentsOf: newArticles)
                let urlsToWarm = newArticles.flatMap { feedItemImageURLs(for: $0) }
                Task.detached(priority: .background) { prefetchImageURLs(urlsToWarm) }

                let hasMore = timelineCursor != nil || discoverCursor != nil || newsCursor != nil
                if newArticles.isEmpty && hasMore && autoFetchCount < 5 {
                    autoFetchCount += 1
                    isLoading = false
                    await load(loadMore: true)
                    return
                }
                autoFetchCount = 0
            } else {
                var dedup = Set<String>()
                articles = filtered.filter { dedup.insert($0.uri).inserted }
                let urlsToWarm = articles.flatMap { feedItemImageURLs(for: $0) }
                Task.detached(priority: .background) { prefetchImageURLs(urlsToWarm) }

                let hasMore = timelineCursor != nil || discoverCursor != nil || newsCursor != nil
                if articles.count < 5 && hasMore && autoFetchCount < 5 {
                    autoFetchCount += 1
                    isLoading = false
                    await load(loadMore: true)
                    return
                }
                autoFetchCount = 0
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markSeenPost(_ post: PostView) {
        guard seenURISet.insert(post.uri).inserted else { return }
        modelContext.insert(SeenPost(uri: post.uri, likeCount: post.likeCount ?? 0, repostCount: post.repostCount ?? 0))
    }

    private func isReadableArticle(_ card: ExternalCard) -> Bool {
        let uri = card.uri.lowercased()
        let excludedExtensions = [".gif", ".jpg", ".jpeg", ".png", ".mp4", ".mov", ".webp", ".webm", ".svg", ".bmp", ".avi", ".mkv"]
        for ext in excludedExtensions {
            if uri.hasSuffix(ext) { return false }
        }
        guard let host = URL(string: card.uri)?.host?.lowercased() else { return false }
        let excludedHosts = [
            // GIF/media providers
            "tenor.com", "giphy.com", "klipy.com", "media.tenor.com", "media.giphy.com",
            "imgur.com",
            // Social media
            "twitter.com", "x.com", "t.co",
            "instagram.com", "tiktok.com", "vm.tiktok.com",
            "facebook.com", "fb.com", "fb.watch",
            "threads.net", "reddit.com", "bsky.app",
            "linkedin.com", "pinterest.com",
            // Video
            "youtube.com", "youtu.be", "vimeo.com", "twitch.tv", "kick.com",
            "dailymotion.com",
            // Music / Podcasts
            "open.spotify.com", "spotify.com", "soundcloud.com", "music.apple.com",
            "podcasts.apple.com",
            // App stores / commerce
            "amazon.com", "amzn.to", "apps.apple.com", "play.google.com",
            // Link shorteners / generic
            "bit.ly", "goo.gl", "tinyurl.com", "linktr.ee"
        ]
        if excludedHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return false }
        if card.title.count < 12 { return false }
        // Must look like an article: description or substantial title
        return true
    }
}

// MARK: - Article Card

struct ArticleCardView: View {
    let post: PostView
    let card: ExternalCard
    let isRead: Bool
    let onTap: () -> Void

    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store

    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var isReposted: Bool = false
    @State private var repostCount: Int = 0
    @State private var showRepostSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tappable article area
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 0) {
                    if let thumb = card.thumb, let url = URL(string: thumb) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            default: Color.nbBorder.opacity(0.3)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180)
                        .clipped()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        if let host = URL(string: card.uri)?.host {
                            Text(host.uppercased())
                                .font(.syne(10))
                                .foregroundStyle(Color.nbAccent)
                                .tracking(1)
                        }

                        Text(card.title)
                            .font(.syne(16, weight: .bold))
                            .foregroundStyle(Color.nbBlack)

                        if !card.description.isEmpty {
                            Text(card.description)
                                .font(.inter(13))
                                .foregroundStyle(Color.nbTextSecondary)
                                .lineLimit(2)
                        }

                        HStack(spacing: 8) {
                            AvatarView(url: post.author.avatar, size: 20)
                            Text("@\(post.author.handle)")
                                .font(.inter(12))
                                .foregroundStyle(Color.nbTextSecondary)
                            Spacer()
                        }
                    }
                    .padding(12)
                }
            }
            .buttonStyle(.plain)

            // Action bar — same layout as GalleryCardView
            HStack(spacing: 20) {
                Button {
                    store.navigationPath.append(PostDestination(uri: post.uri, post: post))
                } label: {
                    Label("\(post.replyCount ?? 0)", systemImage: "bubble.left")
                        .font(.inter(12))
                        .foregroundStyle(Color.nbTextSecondary)
                }
                .buttonStyle(.plain)

                Button { showRepostSheet = true } label: {
                    Label("\(repostCount)", systemImage: "arrow.2.squarepath")
                        .font(.inter(12))
                        .foregroundStyle(isReposted ? Color.nbLime : Color.nbTextSecondary)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: isReposted)

                Button { toggleLike() } label: {
                    Label("\(likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                        .font(.inter(12))
                        .foregroundStyle(isLiked ? Color.nbAccent : Color.nbTextSecondary)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: isLiked)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color.nbWhite)
        .nbBorder()
        .nbShadow()
        .onAppear {
            isLiked = post.viewer?.like != nil
            likeCount = post.likeCount ?? 0
            isReposted = post.viewer?.repost != nil
            repostCount = post.repostCount ?? 0
        }
        .confirmationDialog("Repost Options", isPresented: $showRepostSheet) {
            Button(isReposted ? "Undo Repost" : "Repost") { toggleRepost() }
            Button("Quote Post") {
                store.composeQuote = post
                store.showComposeSheet = true
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func toggleLike() {
        guard let did = auth.session?.did else { return }
        let wasLiked = isLiked; let prevCount = likeCount
        isLiked.toggle(); likeCount += isLiked ? 1 : -1
        Task {
            do {
                if wasLiked, let likeUri = post.viewer?.like {
                    try await ATProtocolClient.shared.unlikePost(likeUri: likeUri, did: did)
                } else {
                    _ = try await ATProtocolClient.shared.likePost(uri: post.uri, cid: post.cid, did: did)
                }
            } catch { isLiked = wasLiked; likeCount = prevCount }
        }
    }

    private func toggleRepost() {
        guard let did = auth.session?.did else { return }
        let wasReposted = isReposted; let prevCount = repostCount
        isReposted.toggle(); repostCount += isReposted ? 1 : -1
        Task {
            do {
                if wasReposted, let repostUri = post.viewer?.repost {
                    try await ATProtocolClient.shared.unrepost(repostUri: repostUri, did: did)
                } else {
                    _ = try await ATProtocolClient.shared.repost(uri: post.uri, cid: post.cid, did: did)
                }
            } catch { isReposted = wasReposted; repostCount = prevCount }
        }
    }
}

// MARK: - Article Reader Sheet

struct ArticleReaderSheet: View {
    let card: ExternalCard
    var post: PostView? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var mode: ReadMode = .reader
    @State private var readableProgress: String? = nil

    enum ReadMode: String, CaseIterable {
        case direct = "Direct"
        case reader = "Readable"
        case archive = "Archive"
    }

    var archiveURL: URL? {
        URL(string: "https://archive.ph/?url=\(card.uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Neubrutalist mode toggle
                HStack(spacing: 0) {
                    ForEach(ReadMode.allCases, id: \.self) { m in
                        Button {
                            mode = m
                            readableProgress = nil
                        } label: {
                            Text(m.rawValue.uppercased())
                                .font(.syne(11, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(mode == m ? Color.white : Color.nbBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(mode == m ? Color.nbAccent : Color.nbWhite)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                .padding(8)
                .background(Color.nbWhite)

                // Progress bar for Readable mode
                if mode == .reader, let progress = readableProgress {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(Color.nbAccent)
                        Text(progress)
                            .font(.inter(12))
                            .foregroundStyle(Color.nbTextSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.nbAccent.opacity(0.08))
                    .overlay(alignment: .bottom) { Divider() }
                } else {
                    Divider()
                }

                // WebView
                if let directURL = URL(string: card.uri) {
                    switch mode {
                    case .direct:
                        ArticleWebView(url: directURL, mode: .direct, onProgress: nil)
                    case .reader:
                        ArticleWebView(url: directURL, mode: .reader) { status in
                            readableProgress = status
                        }
                    case .archive:
                        if let url = archiveURL {
                            ArticleWebView(url: url, mode: .direct, onProgress: nil)
                        }
                    }
                }
            }
            .nbNavBar(
                title: URL(string: card.uri)?.host?.uppercased() ?? "ARTICLE",
                leading: { NBBackButton() },
                trailing: {
                    Button {
                        guard let url = URL(string: card.uri) else { return }
                        // Present UIActivityViewController via UIKit so it gets the full
                        // system share sheet (including "Open in Safari" action).
                        // SwiftUI's ShareLink and .sheet-wrapped UIActivityViewController
                        // both omit Safari when presented inside an existing sheet.
                        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let root = scene.keyWindow?.rootViewController else { return }
                        var top = root
                        while let presented = top.presentedViewController { top = presented }
                        let avc = UIActivityViewController(activityItems: [url], applicationActivities: [OpenInSafariActivity()])
                        avc.popoverPresentationController?.sourceView = top.view
                        avc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: 40, width: 0, height: 0)
                        top.present(avc, animated: true)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.nbBlack)
                            .frame(width: 36, height: 36)
                            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            )
        }
    }
}

// MARK: - Open in Safari custom activity
// The system's built-in "Open in Safari" action is suppressed when the share sheet
// is presented from within a WKWebView context. A custom UIActivity guarantees the
// option is always visible in the share sheet's app/actions row.

private final class OpenInSafariActivity: UIActivity {
    private var url: URL?

    override var activityTitle: String? { "Open in Safari" }
    override var activityImage: UIImage? { UIImage(systemName: "safari") }
    override var activityType: UIActivity.ActivityType? { .init("com.bskydreams.openInSafari") }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        activityItems.contains { $0 is URL }
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        url = activityItems.first { $0 is URL } as? URL
    }

    override func perform() {
        if let url { UIApplication.shared.open(url) }
        activityDidFinish(true)
    }
}

// MARK: - ArticleWebView with Readable mode support

struct ArticleWebView: UIViewRepresentable {
    let url: URL
    let mode: ArticleReaderSheet.ReadMode
    let onProgress: ((String?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, isReaderMode: mode == .reader, onProgress: onProgress)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.mainWebView = webView
        context.coordinator.startLoad()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        let url: URL
        let isReaderMode: Bool
        let onProgress: ((String?) -> Void)?
        weak var mainWebView: WKWebView?
        // Keep extractor alive until JS finishes
        private var extractorWebView: WKWebView?

        init(url: URL, isReaderMode: Bool, onProgress: ((String?) -> Void)?) {
            self.url = url
            self.isReaderMode = isReaderMode
            self.onProgress = onProgress
        }

        func startLoad() {
            if isReaderMode {
                fetchAndExtract()
            } else {
                mainWebView?.load(URLRequest(url: url))
            }
        }

        // MARK: Readable fetch: native URLSession (no CORS on iOS)

        private func fetchAndExtract() {
            Task {
                await MainActor.run { onProgress?("Fetching article…") }
                do {
                    var req = URLRequest(url: url, timeoutInterval: 20)
                    req.setValue(
                        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                        forHTTPHeaderField: "User-Agent"
                    )
                    let (data, _) = try await URLSession.shared.data(for: req)
                    let html = String(data: data, encoding: .utf8)
                               ?? String(data: data, encoding: .isoLatin1)
                               ?? ""
                    await MainActor.run { onProgress?("Extracting content…") }
                    // Strip external resources on a background thread — running 16 regex passes
                    // on large HTML (often 100–500 KB) on the main thread causes UI freezes.
                    let stripped = await Task.detached(priority: .userInitiated) { [self] in
                        self.stripExternalResources(html)
                    }.value
                    await MainActor.run { [self] in self.loadExtractor(stripped) }
                } catch {
                    // Fallback: load directly
                    await MainActor.run { [self] in
                        self.onProgress?(nil)
                        self.mainWebView?.load(URLRequest(url: self.url))
                    }
                }
            }
        }

        // Create the off-screen extractor WKWebView and load the pre-stripped HTML.
        // Must run on MainActor because WKWebView requires the main thread.
        @MainActor
        private func loadExtractor(_ strippedHTML: String) {
            let extractor = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            extractor.navigationDelegate = self
            extractorWebView = extractor
            extractor.loadHTMLString(strippedHTML, baseURL: url)
        }

        /// Removes all tags that would trigger network requests from the HTML string.
        /// Keeps the document structure intact so CSS selectors and JS still work.
        /// `nonisolated` so it can be called from Task.detached without a MainActor hop.
        nonisolated private func stripExternalResources(_ html: String) -> String {
            let patterns: [(String, String)] = [
                ("<script[^>]*>[\\s\\S]*?</script>", ""),   // script blocks
                ("<script[^>]*/?>", ""),                     // self-closing scripts
                ("<link[^>]*/?>", ""),                       // <link> (stylesheets, preload, prefetch)
                ("<link[^>]*>", ""),
                ("<img[^>]*/?>", ""),                        // img tags
                ("<img[^>]*>", ""),
                ("<source[^>]*/?>", ""),                     // source (picture, audio, video)
                ("<source[^>]*>", ""),
                ("<picture[^>]*>[\\s\\S]*?</picture>", ""), // picture elements
                ("<iframe[^>]*>[\\s\\S]*?</iframe>", ""),   // iframes
                ("<iframe[^>]*/?>", ""),
                ("<video[^>]*>[\\s\\S]*?</video>", ""),     // video
                ("<video[^>]*/?>", ""),
                ("<audio[^>]*>[\\s\\S]*?</audio>", ""),     // audio
                ("<audio[^>]*/?>", ""),
                ("<style[^>]*>[\\s\\S]*?</style>", ""),     // inline style blocks
            ]
            var result = html
            for (pattern, replacement) in patterns {
                guard let regex = try? NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive, .dotMatchesLineSeparators]
                ) else { continue }
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: replacement)
            }
            return result
        }

        // After extractor finishes loading, run JS to pull out article content
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard webView === extractorWebView else { return }

            let js = """
            (function() {
                var title = document.title || '';
                var content = '';
                var candidates = [
                    'article',
                    '[role="main"]',
                    'main',
                    '.post-content',
                    '.entry-content',
                    '.article-content',
                    '.article-body',
                    '.story-body',
                    '.post-body',
                    '.td-post-content',
                    '.articleBody',
                    '#article-body',
                    '#article-content',
                    '#main-content',
                    '.main-content',
                    '#content'
                ];
                for (var i = 0; i < candidates.length; i++) {
                    var el = document.querySelector(candidates[i]);
                    if (el && el.innerText.trim().length > 200) {
                        var clone = el.cloneNode(true);
                        var junk = clone.querySelectorAll(
                            'nav, header, footer, aside, .ad, .ads, .advertisement, .advert, ' +
                            '.social-share, .social-sharing, .share-bar, .share-buttons, ' +
                            '.sharing-buttons, .share-links, .share-tools, .share-box, ' +
                            '[class*="share-"], [class*="-share"], [class*="social-icon"], ' +
                            '[class*="follow-us"], [class*="follow-btn"], ' +
                            '.related-articles, .related-posts, .related-content, .sidebar, ' +
                            '#comments, .comments, .comment-section, .comment-form, ' +
                            '.newsletter, .newsletter-signup, .subscribe, .subscription-box, .paywall, ' +
                            '.author-bio, .author-box, .contributor-bio, ' +
                            '.cookie-banner, .gdpr, .consent-banner, ' +
                            'script, style, iframe, object, embed, ' +
                            'svg[class*="icon"], svg[aria-hidden="true"]'
                        );
                        junk.forEach(function(j) { j.remove(); });
                        content = clone.innerHTML;
                        break;
                    }
                }
                if (!content) {
                    var body = document.body ? document.body.cloneNode(true) : null;
                    if (body) {
                        var junk = body.querySelectorAll('nav, header, footer, aside, script, style, iframe, object, embed, .ad, .ads, .social-share, [class*="share-"], svg[aria-hidden="true"]');
                        junk.forEach(function(j) { j.remove(); });
                        content = body.innerHTML;
                    }
                }
                return JSON.stringify({ title: title, content: content });
            })();
            """

            webView.evaluateJavaScript(js) { [weak self] result, error in
                guard let self else { return }

                var extractedTitle = ""
                var extractedContent = ""

                if let jsonStr = result as? String,
                   let data = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    extractedTitle = json["title"] ?? ""
                    extractedContent = json["content"] ?? ""
                }

                let styledHTML = self.buildReaderHTML(title: extractedTitle, content: extractedContent)
                DispatchQueue.main.async { self.onProgress?("Rendering…") }
                self.mainWebView?.loadHTMLString(styledHTML, baseURL: self.url)
                self.extractorWebView = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.onProgress?(nil) }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if webView === extractorWebView {
                onProgress?(nil)
                mainWebView?.load(URLRequest(url: url))
                extractorWebView = nil
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if webView === extractorWebView {
                onProgress?(nil)
                mainWebView?.load(URLRequest(url: url))
                extractorWebView = nil
            }
        }

        // MARK: Reader HTML template (matches web app reader style)

        private func buildReaderHTML(title: String, content: String) -> String {
            """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta charset="UTF-8">
            <style>
            * { box-sizing: border-box; -webkit-text-size-adjust: 100%; }
            body {
                font-family: Georgia, 'Times New Roman', serif;
                font-size: 18px;
                line-height: 1.75;
                max-width: 680px;
                margin: 0 auto;
                padding: 20px 20px 80px;
                color: #0A0A0A;
                background: #FFFFFF;
            }
            @media (prefers-color-scheme: dark) {
                body { color: #EFEFEF; background: #1C1C1E; }
                h1.reader-title { border-bottom-color: #EFEFEF; }
                a { color: #6BA3FF; }
                blockquote { border-left-color: #EFEFEF; color: #CCCCCC; }
                code, pre { background: #2C2C2E; color: #EFEFEF; }
                hr { border-color: #3A3A3A; }
            }
            h1.reader-title {
                font-family: -apple-system, 'Helvetica Neue', sans-serif;
                font-size: 26px;
                font-weight: 800;
                line-height: 1.25;
                margin: 0 0 20px;
                padding-bottom: 14px;
                border-bottom: 3px solid #0A0A0A;
                letter-spacing: -0.5px;
            }
            h2, h3, h4 {
                font-family: -apple-system, 'Helvetica Neue', sans-serif;
                font-weight: 700;
                margin-top: 28px;
                margin-bottom: 8px;
                line-height: 1.3;
            }
            p { margin: 0 0 18px; }
            img {
                max-width: 100%;
                height: auto;
                display: block;
                margin: 20px 0;
                border: 2px solid #0A0A0A;
            }
            a { color: #0047FF; text-decoration: underline; }
            blockquote {
                border-left: 4px solid #0047FF;
                margin: 20px 0;
                padding: 10px 16px;
                background: #F5F5F5;
                font-style: italic;
                color: #333;
            }
            code { font-family: monospace; background: #F5F5F5; padding: 2px 6px; font-size: 0.9em; }
            pre { background: #F5F5F5; padding: 16px; overflow-x: auto; font-size: 0.85em; }
            ul, ol { padding-left: 24px; margin-bottom: 18px; }
            li { margin-bottom: 6px; }
            figure { margin: 20px 0; }
            figcaption { font-size: 14px; color: #666; margin-top: 6px; font-family: -apple-system, sans-serif; }
            table { border-collapse: collapse; width: 100%; margin: 20px 0; }
            th, td { border: 1px solid #E0E0E0; padding: 8px 12px; text-align: left; }
            th { background: #F5F5F5; font-weight: 700; }
            /* Hide noisy elements */
            nav, .nav, header, .header, footer, .footer,
            .ad, .ads, .advertisement, .promo,
            .social-share, .share-buttons,
            .related-articles, .recommended,
            .newsletter-signup, .subscribe,
            .cookie-notice, .popup,
            [class*="sidebar"], [id*="sidebar"],
            [class*="widget"], [id*="widget"] {
                display: none !important;
            }
            </style>
            </head>
            <body>
            \(title.isEmpty ? "" : "<h1 class=\"reader-title\">\(title)</h1>")
            \(content)
            </body>
            </html>
            """
        }
    }
}
