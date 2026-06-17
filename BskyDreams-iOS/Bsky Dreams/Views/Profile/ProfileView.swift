import SwiftUI

struct ProfileView: View {
    let actor: String

    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var profile: ActorProfile?
    @State private var posts: [FeedItem] = []
    @State private var cursor: String?
    @State private var isLoading = true
    @State private var postsLoading = false
    @State private var isFollowing = false
    @State private var followUri: String?
    @State private var showUnfollowConfirm = false
    @State private var replyingToURI: String? = nil
    @State private var isMuted = false
    @State private var isBlocked = false
    @State private var showMuteConfirm = false
    @State private var showBlockConfirm = false
    @State private var showReportSheet = false
    @State private var errorMessage: String?

    @Environment(NetworkMonitor.self) private var network

    var isOwnProfile: Bool { profile?.did == auth.session?.did }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile {
                VStack(spacing: 0) {
                    if network.isOffline { NBOfflineBanner() }
                    if let errorMessage {
                        NBErrorBanner(message: errorMessage, retry: nil, onDismiss: { self.errorMessage = nil })
                    }
                    profileContent(profile)
                }
            } else {
                VStack(spacing: 0) {
                    if network.isOffline { NBOfflineBanner() }
                    NBEmptyState(
                        icon: "person.crop.circle.badge.exclamationmark",
                        title: "Profile Unavailable",
                        message: errorMessage ?? "This profile could not be loaded.",
                        actionTitle: "Retry",
                        action: { Task { await loadProfile() } }
                    )
                }
            }
        }
        .nbNavBar(title: profile.map { "@\($0.handle)" } ?? "", leading: { NBBackButton() }, trailing: {
            if !isOwnProfile, profile != nil {
                Menu {
                    Button(action: { showMuteConfirm = true }) {
                        Label(isMuted ? "Unmute" : "Mute", systemImage: isMuted ? "speaker.wave.2" : "speaker.slash")
                    }
                    Button(role: .destructive, action: { showBlockConfirm = true }) {
                        Label(isBlocked ? "Unblock" : "Block Account", systemImage: "hand.raised")
                    }
                    Button(role: .destructive, action: { showReportSheet = true }) {
                        Label("Report Account", systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.nbBlack)
                        .frame(width: 36, height: 36)
                        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                }
                .accessibilityLabel("More options")
            }
        })
        .confirmationDialog(
            isMuted ? "Unmute @\(profile?.handle ?? "")?" : "Mute @\(profile?.handle ?? "")?",
            isPresented: $showMuteConfirm,
            titleVisibility: .visible
        ) {
            Button(isMuted ? "Unmute" : "Mute", role: isMuted ? .none : .destructive) { toggleMute() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Block @\(profile?.handle ?? "")?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("Block", role: .destructive) { performBlock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to interact with you.")
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(title: "Report Account") { reason in
                guard let did = profile?.did else { return }
                Task {
                    do {
                        try await ATProtocolClient.shared.reportAccount(did: did, reason: reason)
                        Haptics.success()
                    } catch {
                        Haptics.error()
                        errorMessage = "Couldn't submit report. \(error.localizedDescription)"
                    }
                }
            }
        }
        .task { await loadProfile() }
    }

    @ViewBuilder
    private func profileContent(_ profile: ActorProfile) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                profileHeader(profile)

                ForEach(posts) { item in
                    PostCardView(
                        post: item.post,
                        onReply: { post in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                replyingToURI = replyingToURI == post.uri ? nil : post.uri
                            }
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .onAppear {
                        if item.id == posts.last?.id {
                            Task { await loadPosts(loadMore: true) }
                        }
                    }

                    if replyingToURI == item.post.uri {
                        InlineReplyView(replyTo: item.post) {
                            withAnimation(.easeInOut(duration: 0.2)) { replyingToURI = nil }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                if posts.isEmpty && !postsLoading {
                    NBEmptyState(
                        icon: "square.stack.3d.up.slash",
                        title: "No Posts Yet",
                        message: "This account hasn't posted anything."
                    )
                    .padding(.top, 40)
                }

                if postsLoading && !posts.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await loadProfile() }
    }

    @ViewBuilder
    private func profileHeader(_ profile: ActorProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Banner
            if let banner = profile.banner, let url = URL(string: banner) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: { DiagonalStripeBackground() }
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                .clipped()
            } else {
                DiagonalStripeBackground()
                    .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
            }

            // Avatar row — negative top padding overlaps the banner
            HStack(alignment: .top, spacing: 0) {
                AvatarView(url: profile.avatar, size: 80)
                    .padding(.top, -40)
                    .padding(.leading, 16)

                Spacer()

                if !isOwnProfile {
                    followButton
                        .padding(.top, 12)
                        .padding(.trailing, 16)
                }
            }

            // Name / handle / bio / stats
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.system(size: 20, weight: .heavy))
                    .padding(.top, 4)

                Text("@\(profile.handle)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.nbTextSecondary)

                if let desc = profile.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 14))
                        .lineSpacing(3)
                        .padding(.top, 6)
                }

                // Stats — horizontal inline
                HStack(spacing: 0) {
                    statView(count: profile.followersCount, label: "followers")
                    Text("·")
                        .font(.inter(13))
                        .foregroundStyle(Color.nbTextTertiary)
                        .padding(.horizontal, 8)
                    statView(count: profile.followsCount, label: "following")
                    Text("·")
                        .font(.inter(13))
                        .foregroundStyle(Color.nbTextTertiary)
                        .padding(.horizontal, 8)
                    statView(count: profile.postsCount, label: "posts")
                }
                .padding(.top, 10)

                // Tool buttons row — icon-only squares, evenly distributed
                HStack(spacing: 8) {
                    Spacer()

                    Button {
                        // Clear the full navigation stack first (removes profile, thread, etc.)
                        // then push the analytics destination so the back button goes to root.
                        store.navigationPath = NavigationPath()
                        store.navigationPath.append(AnalyticsDestination(actor: profile.handle))
                    } label: {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.nbBlack)
                            .frame(width: 44, height: 44)
                            .background(Color.nbWhite)
                            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                            .background(Color.nbBlack.offset(x: 2, y: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View analytics")

                    Spacer()

                    Button {
                        store.navigationPath = NavigationPath()
                        store.navigationPath.append(ConstellationDestination(actor: profile.handle))
                    } label: {
                        Image(systemName: "network")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.nbBlack)
                            .frame(width: 44, height: 44)
                            .background(Color.nbWhite)
                            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                            .background(Color.nbBlack.offset(x: 2, y: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View network constellation")

                    Spacer()

                    Button {
                        store.selectedTab = .timeline
                        store.pendingTimelineQuery = "@\(profile.handle)"
                    } label: {
                        Image(systemName: "calendar.day.timeline.leading")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.nbBlack)
                            .frame(width: 44, height: 44)
                            .background(Color.nbWhite)
                            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                            .background(Color.nbBlack.offset(x: 2, y: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View timeline")

                    Spacer()
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.nbWhite)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.nbBlack)
                .frame(height: 2)
        }
    }

    private func statView(count: Int?, label: String) -> some View {
        HStack(spacing: 4) {
            Text(formatCount(count ?? 0))
                .font(.syne(14, weight: .bold))
            Text(label)
                .font(.inter(13))
                .foregroundStyle(Color.nbTextSecondary)
        }
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
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
        Haptics.light()
        if isFollowing {
            showUnfollowConfirm = true
        } else {
            performFollow()
        }
    }

    private func performFollow() {
        guard let myDid = auth.session?.did, let profileDid = profile?.did else { return }
        // Optimistic update
        let prevFollowing = isFollowing
        let prevFollowUri = followUri
        isFollowing = true
        Task {
            do {
                let result = try await ATProtocolClient.shared.follow(did: profileDid, myDid: myDid)
                followUri = result.uri
            } catch {
                // Roll back
                isFollowing = prevFollowing
                followUri = prevFollowUri
                Haptics.error()
                errorMessage = "Couldn't follow this account. \(error.localizedDescription)"
            }
        }
    }

    private func performUnfollow() {
        guard let myDid = auth.session?.did, let fUri = followUri else { return }
        // Optimistic update
        let prevFollowing = isFollowing
        let prevFollowUri = followUri
        isFollowing = false
        followUri = nil
        Task {
            do {
                try await ATProtocolClient.shared.unfollow(followUri: fUri, myDid: myDid)
            } catch {
                // Roll back
                isFollowing = prevFollowing
                followUri = prevFollowUri
                Haptics.error()
                errorMessage = "Couldn't unfollow this account. \(error.localizedDescription)"
            }
        }
    }

    private func toggleMute() {
        let wasMuted = isMuted
        isMuted.toggle()
        guard let did = profile?.did else { return }
        Task {
            do {
                if wasMuted {
                    try await ATProtocolClient.shared.unmuteActor(actor: did)
                } else {
                    try await ATProtocolClient.shared.muteActor(actor: did)
                }
                Haptics.success()
            } catch {
                isMuted = wasMuted
                Haptics.error()
                errorMessage = wasMuted ? "Couldn't unmute this account. \(error.localizedDescription)" : "Couldn't mute this account. \(error.localizedDescription)"
            }
        }
    }

    private func performBlock() {
        guard let myDid = auth.session?.did, let did = profile?.did else { return }
        Task {
            do {
                _ = try await ATProtocolClient.shared.blockActor(did: did, myDid: myDid)
                isBlocked = true
                Haptics.success()
            } catch {
                Haptics.error()
                errorMessage = "Couldn't block this account. \(error.localizedDescription)"
            }
        }
    }

    private func loadProfile() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let p = try await ATProtocolClient.shared.getProfile(actor: actor)
            profile = p
            isFollowing = p.viewer?.following != nil
            followUri = p.viewer?.following
            isMuted = p.viewer?.muted == true
            isBlocked = p.viewer?.blocking != nil
            await loadPosts()
        } catch {
            errorMessage = "Couldn't load this profile. \(error.localizedDescription)"
        }
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
        } catch {
            errorMessage = "Couldn't load posts. \(error.localizedDescription)"
        }
    }
}
