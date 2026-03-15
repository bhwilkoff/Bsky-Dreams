import SwiftUI

struct ProfileView: View {
    let actor: String

    @Environment(AuthManager.self) private var auth
    @State private var profile: ActorProfile?
    @State private var posts: [FeedItem] = []
    @State private var cursor: String?
    @State private var isLoading = true
    @State private var postsLoading = false
    @State private var isFollowing = false
    @State private var followUri: String?
    @State private var showUnfollowConfirm = false

    var isOwnProfile: Bool { profile?.did == auth.session?.did }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading profile...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let profile {
                    profileContent(profile)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PostDestination.self) { dest in
                ThreadView(uri: dest.uri, initialPost: dest.post)
            }
        }
        .task { await loadProfile() }
    }

    @ViewBuilder
    private func profileContent(_ profile: ActorProfile) -> some View {
        List {
            // Profile header section
            Section {
                profileHeader(profile)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            // Posts
            ForEach(posts) { item in
                PostCardView(post: item.post)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                    .onAppear {
                        if item.id == posts.last?.id {
                            Task { await loadPosts(loadMore: true) }
                        }
                    }
            }

            if postsLoading && !posts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .refreshable { await loadProfile() }
    }

    @ViewBuilder
    private func profileHeader(_ profile: ActorProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner
            ZStack(alignment: .bottomLeading) {
                if let banner = profile.banner, let url = URL(string: banner) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { DiagonalStripeBackground() }
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .clipped()
                } else {
                    DiagonalStripeBackground()
                        .frame(maxWidth: .infinity, minHeight: 100)
                }

                AvatarView(url: profile.avatar, size: 72)
                    .offset(x: 16, y: 36)
            }
            .frame(maxWidth: .infinity)

            // Name + follow button
            HStack(alignment: .top) {
                Spacer().frame(height: 48)
                Spacer()
                if !isOwnProfile {
                    followButton
                }
            }
            .padding(.horizontal, 16)

            // Bio
            VStack(alignment: .leading, spacing: 6) {
                Text(profile.name)
                    .font(.syne(20, weight: .heavy))
                Text("@\(profile.handle)")
                    .font(.inter(14))
                    .foregroundStyle(Color.nbBlack.opacity(0.6))

                if let desc = profile.description, !desc.isEmpty {
                    Text(desc)
                        .font(.inter(14))
                        .padding(.top, 4)
                }

                // Stats
                HStack(spacing: 20) {
                    statView(count: profile.followersCount, label: "followers")
                    statView(count: profile.followsCount, label: "following")
                    statView(count: profile.postsCount, label: "posts")
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(Color.nbWhite)
            .nbBorder()
        }
    }

    private func statView(count: Int?, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count ?? 0)")
                .font(.syne(16, weight: .bold))
            Text(label)
                .font(.inter(12))
                .foregroundStyle(Color.nbBlack.opacity(0.5))
        }
    }

    private var followButton: some View {
        Button(action: toggleFollow) {
            Text(isFollowing ? "FOLLOWING" : "FOLLOW")
                .font(.syne(12, weight: .bold))
                .tracking(1)
                .foregroundStyle(isFollowing ? Color.nbBlack : Color.nbWhite)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isFollowing ? Color.nbWhite : Color.nbAccent)
                .nbBorder()
                .nbShadow(size: 3)
        }
        .offset(x: -2, y: -2)
        .confirmationDialog(
            "Unfollow @\(profile?.handle ?? "")?",
            isPresented: $showUnfollowConfirm,
            titleVisibility: .visible
        ) {
            Button("Unfollow", role: .destructive) { performUnfollow() }
        }
    }

    private func toggleFollow() {
        if isFollowing {
            showUnfollowConfirm = true
        } else {
            performFollow()
        }
    }

    private func performFollow() {
        guard let myDid = auth.session?.did, let profileDid = profile?.did else { return }
        Task {
            do {
                let result = try await ATProtocolClient.shared.follow(did: profileDid, myDid: myDid)
                isFollowing = true
                followUri = result.uri
            } catch {}
        }
    }

    private func performUnfollow() {
        guard let myDid = auth.session?.did, let fUri = followUri else { return }
        Task {
            do {
                try await ATProtocolClient.shared.unfollow(followUri: fUri, myDid: myDid)
                isFollowing = false
                followUri = nil
            } catch {}
        }
    }

    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let p = try await ATProtocolClient.shared.getProfile(actor: actor)
            profile = p
            isFollowing = p.viewer?.following != nil
            followUri = p.viewer?.following
            await loadPosts()
        } catch {}
    }

    private func loadPosts(loadMore: Bool = false) async {
        guard !postsLoading else { return }
        postsLoading = true
        defer { postsLoading = false }
        do {
            let fetchCursor = loadMore ? cursor : nil
            let response = try await ATProtocolClient.shared.getAuthorFeed(
                actor: actor, cursor: fetchCursor
            )
            if loadMore {
                posts.append(contentsOf: response.feed)
            } else {
                posts = response.feed
            }
            cursor = response.cursor
        } catch {}
    }
}
