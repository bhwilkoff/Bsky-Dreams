import SwiftUI

// MARK: - Home Feed (Following + Discover tabs)

struct FeedView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth

    private let discoverFeedURI = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"

    @State private var items: [FeedItem] = []
    @State private var cursor: String?
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var composeTarget: PostView? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    loadingState
                } else if let err = errorMessage, items.isEmpty {
                    errorState(err)
                } else {
                    feedList
                }
            }
            .navigationTitle("BSKY DREAMS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .navigationDestination(for: PostDestination.self) { dest in
                ThreadView(uri: dest.uri, initialPost: dest.post)
            }
            .navigationDestination(for: ProfileDestination.self) { dest in
                ProfileView(actor: dest.actor)
            }
            .navigationDestination(for: HashtagDestination.self) { dest in
                SearchView(initialQuery: "#\(dest.tag)")
            }
        }
        .task { if items.isEmpty { await loadFeed() } }
        .sheet(item: $composeTarget) { post in
            ComposeView(replyTo: post)
        }
    }

    private var feedList: some View {
        List {
            // Tab selector
            Picker("Feed", selection: Bindable(store).feedMode) {
                ForEach(AppStore.FeedMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.vertical, 4)
            .onChange(of: store.feedMode) { _, _ in
                Task {
                    items = []
                    cursor = nil
                    await loadFeed()
                }
            }

            ForEach(items) { item in
                PostCardView(
                    post: item.post,
                    showParentPreview: item.reply != nil,
                    onReply: { post in composeTarget = post }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                .onAppear {
                    if item.id == items.last?.id {
                        Task { await loadFeed(loadMore: true) }
                    }
                }
            }

            if isLoading && !items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .refreshable {
            isRefreshing = true
            items = []
            cursor = nil
            await loadFeed()
            isRefreshing = false
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            CloudLogoView(size: 28)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { store.selectedTab = .compose }) {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(Color.nbAccent)
                    .fontWeight(.semibold)
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading feed...")
                .font(.inter(14))
                .foregroundStyle(Color.nbBlack.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.nbAccent)
            Text(message)
                .font(.inter(14))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") { Task { await loadFeed() } }
                .nbButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadFeed(loadMore: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: FeedResponse
            let fetchCursor = loadMore ? cursor : nil

            switch store.feedMode {
            case .following:
                response = try await ATProtocolClient.shared.getTimeline(limit: 50, cursor: fetchCursor)
            case .discover:
                response = try await ATProtocolClient.shared.getFeed(uri: discoverFeedURI, limit: 50, cursor: fetchCursor)
            }

            if loadMore {
                items.append(contentsOf: response.feed)
            } else {
                items = response.feed
            }
            cursor = response.cursor
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
