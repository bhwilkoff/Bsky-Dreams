import SwiftUI
import SwiftData

struct SearchView: View {
    var initialQuery: String = ""

    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedSearch.createdAt) private var savedSearches: [SavedSearch]

    @State private var query: String = ""
    @State private var mode: AppStore.SearchMode = .posts
    @State private var posts: [PostView] = []
    @State private var actors: [ActorProfile] = []
    @State private var cursor: String?
    @State private var isLoading = false
    @State private var sort: String = "latest"
    @State private var showFilters = false
    @State private var showSaveChannelAlert = false
    @State private var newChannelName = ""

    @State private var scrollToTopTrigger = 0

    // Advanced filters
    @State private var filterAuthor = ""
    @State private var filterSince = ""
    @State private var filterUntil = ""
    @State private var filterLang = ""
    @State private var hideAdult = true

    var body: some View {
        resultsList
        .nbNavBar(title: "SEARCH", leading: { NBHamburger() })
        .toolbar {
            // Keyboard dismiss button — shown above keyboard when TextField is focused
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .font(.inter(15, weight: .semibold))
                .foregroundStyle(Color.nbBlack)
            }
        }
        .onAppear {
            if !initialQuery.isEmpty {
                query = initialQuery
                performSearch()
            } else if let q = store.pendingChannelQuery {
                query = q
                performSearch()
                store.pendingChannelQuery = nil
            }
        }
        .onChange(of: store.pendingChannelQuery) { _, newQuery in
            if let q = newQuery {
                query = q
                performSearch()
                store.pendingChannelQuery = nil
            }
        }
        .alert("Save Channel", isPresented: $showSaveChannelAlert) {
            TextField("Channel name", text: $newChannelName)
            Button("Save") { saveChannel() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save \"\(query)\" as a channel")
        }
    }

    private var savedChannelsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(savedSearches) { channel in
                    Button {
                        query = channel.query
                        performSearch()
                    } label: {
                        HStack(spacing: 4) {
                            Text("#")
                                .font(.syne(11, weight: .bold))
                                .foregroundStyle(Color.nbBlue)
                            Text(channel.name)
                                .font(.inter(13, weight: .semibold))
                                .foregroundStyle(Color.nbBlack)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(query == channel.query ? Color.nbLime : Color.nbWhite)
                        .nbBorder()
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete Channel", role: .destructive) {
                            modelContext.delete(channel)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .overlay(alignment: .bottom) { Divider().background(Color.nbBorder) }
    }

    private func saveChannel() {
        guard !newChannelName.isEmpty else { return }
        // Avoid duplicates
        guard !savedSearches.contains(where: { $0.query.lowercased() == query.lowercased() }) else { return }
        let channel = SavedSearch(name: newChannelName, query: query)
        modelContext.insert(channel)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.nbTextTertiary)
                TextField("Search Bluesky", text: $query)
                    .font(.inter(15))
                    .submitLabel(.search)
                    .onSubmit { performSearch() }
                if !query.isEmpty {
                    Button { query = ""; posts = []; actors = [] } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.nbTextTertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.nbWhite)
            .nbBorder()

            Button(action: performSearch) {
                Text("GO")
                    .font(.syne(12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(Color.nbAccent)
                    .nbBorder()
            }
            .buttonStyle(.plain)

            if !query.isEmpty {
                Button {
                    newChannelName = query
                    showSaveChannelAlert = true
                } label: {
                    Image(systemName: "bookmark")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color.nbWhite)
                        .nbBorder()
                }
            }

            Button { showFilters.toggle() } label: {
                Image(systemName: "slider.horizontal.3")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(showFilters ? Color.nbAccent : Color.nbWhite)
                    .nbBorder()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.nbWhite)
        .overlay(alignment: .bottom) {
            Divider().background(Color.nbBorder)
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 0).id("search-top")

                // Search bar scrolls with results
                searchBar

                // Filters panel (when expanded)
                if showFilters { filtersPanel }

                // Neubrutalist mode toggle (Posts / People)
                HStack(spacing: 0) {
                    ForEach(AppStore.SearchMode.allCases, id: \.self) { m in
                        Button {
                            if mode != m { mode = m; performSearch() }
                        } label: {
                            Text(m.rawValue.uppercased())
                                .font(.syne(13, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(mode == m ? Color.white : Color.nbBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(mode == m ? Color.nbAccent : Color.nbWhite)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                .background(Color.nbBlack.offset(x: 3, y: 3))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // Sort toggle (Latest / Top) — posts mode only
                if mode == .posts {
                    HStack(spacing: 0) {
                        Button {
                            if sort != "latest" { sort = "latest"; performSearch() }
                        } label: {
                            Text("LATEST")
                                .font(.syne(12, weight: .bold))
                                .tracking(0.5)
                                // nbWhite for selected text: white on dark bg in light mode,
                                // dark navy on light bg in dark mode — always readable
                                .foregroundStyle(sort == "latest" ? Color.nbWhite : Color.nbBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(sort == "latest" ? Color.nbBlack : Color.nbWhite)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if sort != "top" { sort = "top"; performSearch() }
                        } label: {
                            Text("TOP")
                                .font(.syne(12, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(sort == "top" ? Color.nbWhite : Color.nbBlack)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(sort == "top" ? Color.nbBlack : Color.nbWhite)
                        }
                        .buttonStyle(.plain)
                    }
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }

                // Loading state (initial)
                if isLoading && posts.isEmpty && actors.isEmpty {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    // Results
                    if mode == .posts {
                        ForEach(posts) { post in
                            PostCardView(post: post)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .onAppear {
                                    if post.uri == posts.last?.uri {
                                        Task { await searchMore() }
                                    }
                                }
                        }
                    } else {
                        ForEach(actors) { actor in
                            Button {
                                store.navigationPath.append(ProfileDestination(actor: actor.did))
                            } label: {
                                ActorRowView(actor: actor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.horizontal, 12)
                        }
                    }
                    if isLoading && (!posts.isEmpty || !actors.isEmpty) {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { performSearch() }
        .onChange(of: scrollToTopTrigger) { _, _ in
            withAnimation { proxy.scrollTo("search-top", anchor: .top) }
        }
        }
    }

    private var filtersPanel: some View {
        VStack(spacing: 8) {
            Text("ADVANCED FILTERS")
                .font(.syne(10, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.nbTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            NBTextField(placeholder: "handle.bsky.social", text: $filterAuthor, label: "Author")
                .textInputAutocapitalization(.never)
            HStack {
                NBTextField(placeholder: "YYYY-MM-DD", text: $filterSince, label: "Since")
                NBTextField(placeholder: "YYYY-MM-DD", text: $filterUntil, label: "Until")
            }
            NBTextField(placeholder: "en", text: $filterLang, label: "Language")

            // Hide adult content toggle
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HIDE ADULT CONTENT")
                        .font(.syne(11, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.nbBlack)
                    Text("Filters posts labeled explicit or adult")
                        .font(.inter(11))
                        .foregroundStyle(Color.nbTextSecondary)
                }
                Spacer()
                Toggle("", isOn: $hideAdult)
                    .tint(Color.nbAccent)
                    .labelsHidden()
            }
            .padding(10)
            .background(Color.nbWhite)
            .nbBorder()
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

    private func searchMore() async { await doSearch(loadMore: true) }

    private func doSearch(loadMore: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let cleanQuery = query.hasPrefix("@") ? String(query.dropFirst()) : query
        let cleanAuthor = filterAuthor.hasPrefix("@") ? String(filterAuthor.dropFirst()) : filterAuthor
        do {
            let fetchCursor = loadMore ? cursor : nil
            if mode == .posts {
                let result = try await ATProtocolClient.shared.searchPosts(
                    q: cleanQuery, sort: sort, cursor: fetchCursor,
                    author: cleanAuthor.isEmpty ? nil : cleanAuthor,
                    since: filterSince.isEmpty ? nil : filterSince,
                    until: filterUntil.isEmpty ? nil : filterUntil,
                    lang: filterLang.isEmpty ? nil : filterLang.lowercased()
                )
                if loadMore {
                    let existingUris = Set(posts.map { $0.uri })
                    posts.append(contentsOf: result.posts.filter { !existingUris.contains($0.uri) })
                } else {
                    var seen = Set<String>()
                    posts = result.posts.filter { seen.insert($0.uri).inserted }
                }
                cursor = result.cursor
            } else {
                let result = try await ATProtocolClient.shared.searchActors(q: cleanQuery)
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
                    .font(.system(size: 15, weight: .semibold))
                Text("@\(actor.handle)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nbTextSecondary)
                if let desc = actor.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.nbTextSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
