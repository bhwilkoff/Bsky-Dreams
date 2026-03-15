import SwiftUI
import WebKit

struct ReaderView: View {
    @State private var articles: [PostView] = []
    @State private var cursor: String?
    @State private var isLoading = false
    @State private var selectedArticle: PostView? = nil
    @State private var readURLs: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && articles.isEmpty {
                    ProgressView("Loading articles...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if articles.isEmpty {
                    ContentUnavailableView("No Articles", systemImage: "doc.text", description: Text("Your feed will show readable articles here."))
                } else {
                    articleList
                }
            }
            .navigationTitle("Reader")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { if articles.isEmpty { await load() } }
    }

    private var articleList: some View {
        List {
            ForEach(articles) { post in
                if let card = post.embed?.external {
                    ArticleCardView(
                        post: post,
                        card: card,
                        isRead: readURLs.contains(card.uri)
                    ) {
                        readURLs.insert(card.uri)
                        selectedArticle = post
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .opacity(readURLs.contains(card.uri) ? 0.5 : 1.0)
                    .onAppear {
                        if post.uri == articles.last?.uri {
                            Task { await load(loadMore: true) }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .refreshable {
            articles = []
            cursor = nil
            await load()
        }
        .sheet(item: $selectedArticle) { post in
            if let card = post.embed?.external {
                ArticleReaderSheet(card: card, post: post)
            }
        }
    }

    private func load(loadMore: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await ATProtocolClient.shared.getTimeline(
                limit: 50,
                cursor: loadMore ? cursor : nil
            )
            let filtered = resp.feed.compactMap { item -> PostView? in
                guard let ext = item.post.embed?.external else { return nil }
                guard isReadableArticle(ext) else { return nil }
                return item.post
            }

            if loadMore {
                articles.append(contentsOf: filtered)
            } else {
                articles = filtered
            }
            cursor = resp.cursor
        } catch {}
    }

    private func isReadableArticle(_ card: ExternalCard) -> Bool {
        let uri = card.uri.lowercased()
        // Exclude GIFs and direct media
        let excludedExtensions = [".gif", ".jpg", ".jpeg", ".png", ".mp4", ".mov"]
        for ext in excludedExtensions {
            if uri.hasSuffix(ext) { return false }
        }
        // Exclude known non-article hosts
        let excludedHosts = ["tenor.com", "giphy.com", "klipy.com", "twitter.com", "instagram.com", "tiktok.com", "amazon.com"]
        guard let host = URL(string: card.uri)?.host else { return false }
        if excludedHosts.contains(where: { host.contains($0) }) { return false }
        // Require meaningful title
        if card.title.count < 12 { return false }
        return true
    }
}

// MARK: - Article Card

struct ArticleCardView: View {
    let post: PostView
    let card: ExternalCard
    let isRead: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                if let thumb = card.thumb, let url = URL(string: thumb) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Color.nbBorder.shimmering() }
                    .frame(maxWidth: .infinity, maxHeight: 180)
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
                            .foregroundStyle(Color.nbBlack.opacity(0.6))
                            .lineLimit(2)
                    }

                    HStack(spacing: 8) {
                        AvatarView(url: post.author.avatar, size: 20)
                        Text("@\(post.author.handle)")
                            .font(.inter(12))
                            .foregroundStyle(Color.nbBlack.opacity(0.5))
                        Spacer()
                        Label("\(post.likeCount ?? 0)", systemImage: "heart")
                            .font(.inter(12))
                            .foregroundStyle(Color.nbBlack.opacity(0.4))
                    }
                }
                .padding(12)
            }
            .background(Color.nbWhite)
            .nbBorder()
            .nbShadow()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Article Reader Sheet

struct ArticleReaderSheet: View {
    let card: ExternalCard
    let post: PostView
    @Environment(\.dismiss) private var dismiss
    @State private var mode: ReadMode = .reader
    @State private var isLoading = false

    enum ReadMode: String, CaseIterable {
        case direct = "Direct"
        case reader = "Readable"
        case archive = "Archive"
    }

    var displayURL: URL? {
        switch mode {
        case .direct, .reader:
            return URL(string: card.uri)
        case .archive:
            return URL(string: "https://archive.ph/?url=\(card.uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker
                Picker("Mode", selection: $mode) {
                    ForEach(ReadMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(8)

                Divider()

                // WebView
                if let url = displayURL {
                    WebView(url: url, isReaderMode: mode == .reader)
                }
            }
            .navigationTitle(URL(string: card.uri)?.host ?? "Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: URL(string: card.uri) ?? URL(string: "https://bsky.app")!) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - WebView (iOS 26 native WebView)

struct WebView: UIViewRepresentable {
    let url: URL
    var isReaderMode: Bool = false

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}
