import SwiftUI

struct SearchView: View {
    var initialQuery: String = ""

    @Environment(AppStore.self) private var store
    @State private var query: String = ""
    @State private var mode: AppStore.SearchMode = .posts
    @State private var posts: [PostView] = []
    @State private var actors: [ActorProfile] = []
    @State private var cursor: String?
    @State private var isLoading = false
    @State private var sort: String = "latest"
    @State private var showFilters = false

    // Advanced filters
    @State private var filterAuthor = ""
    @State private var filterSince = ""
    @State private var filterUntil = ""
    @State private var filterLang = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.nbBlack.opacity(0.4))
                        TextField("Search Bluesky", text: $query)
                            .font(.inter(15))
                            .submitLabel(.search)
                            .onSubmit { performSearch() }
                        if !query.isEmpty {
                            Button { query = ""; posts = []; actors = [] } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.nbBlack.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.nbWhite)
                    .nbBorder()

                    Button {
                        showFilters.toggle()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .padding(10)
                            .background(showFilters ? Color.nbAccent : Color.nbWhite)
                            .nbBorder()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.nbWhite)
                .nbBorder(width: 0)
                .overlay(alignment: .bottom) {
                    Divider().background(Color.nbBorder)
                }

                // Filters panel
                if showFilters {
                    filtersPanel
                }

                // Mode selector
                Picker("Mode", selection: $mode) {
                    ForEach(AppStore.SearchMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .onChange(of: mode) { _, _ in performSearch() }

                if mode == .posts {
                    Picker("Sort", selection: $sort) {
                        Text("Latest").tag("latest")
                        Text("Top").tag("top")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                    .onChange(of: sort) { _, _ in performSearch() }
                }

                // Results
                if isLoading && posts.isEmpty && actors.isEmpty {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
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
        .onAppear {
            if !initialQuery.isEmpty {
                query = initialQuery
                performSearch()
            }
        }
    }

    private var resultsList: some View {
        List {
            if mode == .posts {
                ForEach(posts) { post in
                    PostCardView(post: post)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .onAppear {
                            if post.uri == posts.last?.uri {
                                Task { await searchMore() }
                            }
                        }
                }
            } else {
                ForEach(actors) { actor in
                    NavigationLink(value: ProfileDestination(actor: actor.did)) {
                        ActorRowView(actor: actor)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            if isLoading && (!posts.isEmpty || !actors.isEmpty) {
                ProgressView().frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
    }

    private var filtersPanel: some View {
        VStack(spacing: 8) {
            NBTextField(placeholder: "handle.bsky.social", text: $filterAuthor, label: "Author")
                .textInputAutocapitalization(.never)
            HStack {
                NBTextField(placeholder: "YYYY-MM-DD", text: $filterSince, label: "Since")
                NBTextField(placeholder: "YYYY-MM-DD", text: $filterUntil, label: "Until")
            }
            NBTextField(placeholder: "en", text: $filterLang, label: "Language")
        }
        .padding(12)
        .background(Color.nbBorder.opacity(0.2))
    }

    private func performSearch() {
        guard !query.isEmpty else { return }
        posts = []
        actors = []
        cursor = nil
        Task { await doSearch() }
    }

    private func searchMore() async {
        await doSearch(loadMore: true)
    }

    private func doSearch(loadMore: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchCursor = loadMore ? cursor : nil
            if mode == .posts {
                let result = try await ATProtocolClient.shared.searchPosts(
                    q: query,
                    sort: sort,
                    cursor: fetchCursor,
                    author: filterAuthor.isEmpty ? nil : filterAuthor,
                    since: filterSince.isEmpty ? nil : filterSince,
                    until: filterUntil.isEmpty ? nil : filterUntil,
                    lang: filterLang.isEmpty ? nil : filterLang
                )
                if loadMore {
                    posts.append(contentsOf: result.posts)
                } else {
                    posts = result.posts
                }
                cursor = result.cursor
            } else {
                let result = try await ATProtocolClient.shared.searchActors(q: query)
                actors = result.actors
            }
        } catch {}
    }
}

// MARK: - Actor Row

struct ActorRowView: View {
    let actor: ActorProfile

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: actor.avatar, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(actor.name)
                    .font(.inter(15, weight: .semibold))
                Text("@\(actor.handle)")
                    .font(.inter(13))
                    .foregroundStyle(Color.nbBlack.opacity(0.6))
                if let desc = actor.description, !desc.isEmpty {
                    Text(desc)
                        .font(.inter(12))
                        .foregroundStyle(Color.nbBlack.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
