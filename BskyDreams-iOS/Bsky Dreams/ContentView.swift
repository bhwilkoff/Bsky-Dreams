import SwiftUI
import SwiftData
import UserNotifications

struct RootView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        if auth.isLoggedIn {
            MainAppView()
        } else {
            LoginView()
        }
    }
}

// MARK: - Main App

struct MainAppView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var seenPosts: [SeenPost]
    @State private var sidebarOpen = false
    @State private var sidebarDragOffset: CGFloat = 0
    @State private var isDraggingSidebar = false

    private let seenMaxAge: TimeInterval = 7 * 24 * 3600

    private var sidebarWidth: CGFloat { min(UIScreen.main.bounds.width * 0.78, 300) }
    private var sidebarCurrentX: CGFloat {
        let base: CGFloat = sidebarOpen ? 0 : -sidebarWidth
        return max(-sidebarWidth, min(0, base + sidebarDragOffset))
    }
    private var dimOpacity: Double {
        Double((sidebarCurrentX + sidebarWidth) / sidebarWidth) * 0.35
    }
    private func closeSidebar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            sidebarOpen = false
            sidebarDragOffset = 0
        }
    }
    private func toggleSidebarAnimated() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            sidebarOpen.toggle()
            sidebarDragOffset = 0
        }
    }

    /// Transparent left-edge strip that sits above child ScrollViews in the hit-test
    /// hierarchy. Because it's its own view at high zIndex, it wins the gesture
    /// competition before any scroll view sees the touch — no angle check needed.
    /// Only active when the sidebar is closed and no pushed view is on the stack.
    private var edgeOpenStrip: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 28)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 5, coordinateSpace: .global)
                        .onChanged { value in
                            // Any rightward motion from the left edge = open intent.
                            // No angle check — the narrow strip implies horizontal intent.
                            guard value.translation.width > 0 else { return }
                            isDraggingSidebar = true
                            sidebarDragOffset = value.translation.width
                        }
                        .onEnded { value in
                            guard isDraggingSidebar else { return }
                            isDraggingSidebar = false
                            // base = -sidebarWidth (sidebar was closed)
                            let predicted = max(-sidebarWidth, min(0,
                                -sidebarWidth + value.predictedEndTranslation.width))
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                sidebarOpen = predicted > -sidebarWidth / 2
                                sidebarDragOffset = 0
                            }
                        }
                )
            Spacer()
        }
        .ignoresSafeArea()
        .allowsHitTesting(!sidebarOpen && store.navigationPath.isEmpty)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Page background — deep navy-black in dark mode so cards float above it.
            Color.nbBackground.ignoresSafeArea()

            // Full-screen content
            NavigationStack(path: Bindable(store).navigationPath) {
                DetailView(toggleSidebar: { toggleSidebarAnimated() })
                    .environment(\.toggleSidebar, { toggleSidebarAnimated() })
                    .navigationDestination(for: PostDestination.self) { dest in
                        ThreadView(uri: dest.uri, initialPost: dest.post)
                            .enableNavigationBackSwipe()
                    }
                    .navigationDestination(for: ProfileDestination.self) { dest in
                        ProfileView(actor: dest.actor)
                            .enableNavigationBackSwipe()
                    }
                    .navigationDestination(for: HashtagDestination.self) { dest in
                        SearchView(initialQuery: "#\(dest.tag)")
                            .enableNavigationBackSwipe()
                    }
                    .navigationDestination(for: Conversation.self) { convo in
                        ChatView(conversation: convo, myDid: auth.session?.did ?? "")
                            .enableNavigationBackSwipe()
                    }
                    .navigationDestination(for: AnalyticsDestination.self) { dest in
                        AnalyticsView(initialActor: dest.actor)
                            .enableNavigationBackSwipe()
                    }
                    .navigationDestination(for: ConstellationDestination.self) { dest in
                        ConstellationView(initialActor: dest.actor)
                            .enableNavigationBackSwipe()
                    }
            }

            // Dim overlay — opacity tracks sidebar position 1:1 during drag
            Color.black.opacity(dimOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(dimOpacity > 0.01)
                .onTapGesture { closeSidebar() }
                .zIndex(1)

            // Sidebar — always in hierarchy, translated off-screen when closed
            SidebarView(onNavigate: closeSidebar)
                .frame(width: sidebarWidth)
                .ignoresSafeArea(edges: .vertical)
                .offset(x: sidebarCurrentX)
                .zIndex(2)

            // Left-edge ghost strip — above sidebar so it wins gesture competition
            // over child ScrollViews; passes through all hits when sidebar is open
            edgeOpenStrip
                .zIndex(3)
        }
        // Close-only gesture on the ZStack: handles dragging the sidebar shut.
        // Opening is handled exclusively by edgeOpenStrip above.
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .global)
                .onChanged { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if !isDraggingSidebar {
                        // Only handle close: sidebar must be open, swipe must be left
                        guard sidebarOpen && abs(dx) > abs(dy) && dx < 0 else { return }
                        isDraggingSidebar = true
                    }
                    sidebarDragOffset = dx
                }
                .onEnded { value in
                    guard isDraggingSidebar else { return }
                    isDraggingSidebar = false
                    // base = 0 (sidebar was open); predicted end determines open/close
                    let predicted = max(-sidebarWidth, min(0, value.predictedEndTranslation.width))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        sidebarOpen = predicted > -sidebarWidth / 2
                        sidebarDragOffset = 0
                    }
                }
        )
        .sheet(isPresented: Bindable(store).showComposeSheet, onDismiss: {
            store.composeQuote = nil
            store.composeText = ""
            store.composeImages = []
            store.composeVideo = nil
        }) {
            ComposeView(
                quotePost: store.composeQuote,
                initialText: store.composeText,
                initialImages: store.composeImages,
                initialVideo: store.composeVideo
            )
        }
        .task {
            ATProtocolClient.shared.configure(authManager: auth)
            // Proactively refresh token on cold start before any API calls
            await auth.refreshIfNeeded()
            // Pick up any share that arrived before auth was ready (cold-start from Share Extension)
            store.processPendingShare()
            await refreshBadges()
            await fetchCurrentUserAvatar()
            // Merge cloud seen-posts into local SwiftData on every login/cold start
            await mergeSeenFromCloud()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await auth.refreshIfNeeded() }
            // Belt-and-suspenders: pick up any share saved while app was backgrounded.
            store.processPendingShare()
            Task { await refreshBadges() }
            // Re-merge cloud seen posts on every foreground (catches cross-device syncs)
            Task { await mergeSeenFromCloud() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bskyNotificationTapped)) { notification in
            let navType = notification.userInfo?["nav_type"] as? String
            if navType == "dm", let convoId = notification.userInfo?["convo_id"] as? String {
                store.pendingDMConvoId = convoId
                store.selectedTab = .dms
            } else {
                store.selectedTab = .notifications
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Clear app icon badge and refresh count when app becomes active
                UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
                Task { await refreshBadges() }
            } else if phase == .background {
                // Flush seen-posts to cloud immediately when app goes to background
                if let did = auth.session?.did {
                    let cutoff = Date().addingTimeInterval(-seenMaxAge)
                    let recentURIs = seenPosts.filter { $0.seenAt >= cutoff }.map { $0.uri }
                    Task { await store.saveSeenToCloud(uris: recentURIs, did: did) }
                }
                // Immediately check and deliver any pending notifications before the app
                // suspends — this reduces latency compared to waiting for the next
                // BGAppRefreshTask (which iOS can delay significantly past the 15-min minimum).
                Task { await BskyDreamsApp.performNotificationCheck() }
                BskyDreamsApp.scheduleBackgroundRefresh()
            }
        }
        .onChange(of: store.selectedTab) { _, _ in
            store.navigationPath = NavigationPath()
        }
    }

    /// Fetch the seen-posts record from the AT Protocol repo and insert any
    /// URIs that aren't already in local SwiftData. Cloud wins on merge
    /// (union strategy — never removes local records).
    private func mergeSeenFromCloud() async {
        guard let did = auth.session?.did else { return }
        let cloudURIs = await store.loadSeenFromCloud(did: did)
        guard !cloudURIs.isEmpty else { return }
        let existingURIs = Set(seenPosts.map { $0.uri })
        let cutoff = Date().addingTimeInterval(-seenMaxAge)
        var added = 0
        for uri in cloudURIs where !existingURIs.contains(uri) {
            modelContext.insert(SeenPost(uri: uri))
            added += 1
        }
        // Prune local entries beyond 7-day window
        seenPosts.filter { $0.seenAt < cutoff }.forEach { modelContext.delete($0) }
        // Notify FeedView (and other views) to refresh their in-memory seenURISet
        if added > 0 {
            NotificationCenter.default.post(name: AppStore.seenPostsMergedNotification, object: nil)
        }
    }

    private func refreshBadges() async {
        do {
            let notifs = try await ATProtocolClient.shared.listNotifications(limit: 1)
            store.unreadNotificationCount = notifs.notifications.filter { !$0.isRead }.count
        } catch {}
    }

    private func fetchCurrentUserAvatar() async {
        guard let did = auth.session?.did else { return }
        if let profile = try? await ATProtocolClient.shared.getProfile(actor: did) {
            store.currentUserAvatar = profile.avatar
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    let onNavigate: () -> Void

    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Query private var savedSearches: [SavedSearch]

    @State private var editingChannel: SavedSearch? = nil
    @State private var channelRenameText = ""

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider().background(Color.nbBlack)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(AppStore.AppTab.allCases, id: \.self) { tab in
                        SidebarNavButton(
                            tab: tab,
                            isActive: store.selectedTab == tab,
                            badge: badgeCount(for: tab)
                        ) {
                            store.selectedTab = tab
                            onNavigate()
                        }
                    }

                    if !savedSearches.isEmpty {
                        Divider().background(Color.nbBlack).padding(.vertical, 8)

                        HStack {
                            Text("CHANNELS")
                                .font(.syne(10, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(Color.nbTextTertiary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)

                        ForEach(savedSearches) { channel in
                            SidebarChannelButton(channel: channel, isActive: false) {
                                if channel.channelType == "timeline" {
                                    store.selectedTab = .timeline
                                    store.pendingTimelineQuery = channel.query
                                } else {
                                    store.selectedTab = .search
                                    store.pendingChannelQuery = channel.query
                                }
                                onNavigate()
                            }
                            .contextMenu {
                                Button("Rename") {
                                    channelRenameText = channel.name
                                    editingChannel = channel
                                }
                                Button("Delete", role: .destructive) {
                                    modelContext.delete(channel)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()
            Divider().background(Color.nbBlack)
            sidebarFooter
        }
        .background(Color.nbWhite)
        .alert("Rename Channel", isPresented: Binding(
            get: { editingChannel != nil },
            set: { if !$0 { editingChannel = nil } }
        )) {
            TextField("Channel name", text: $channelRenameText)
            Button("Save") {
                editingChannel?.name = channelRenameText
                editingChannel = nil
            }
            Button("Cancel", role: .cancel) { editingChannel = nil }
        } message: {
            Text("Enter a new name for this channel")
        }
    }

    private var sidebarHeader: some View {
        // VStack + .background() keeps the header non-greedy.
        // Neither Color nor DiagonalStripeBackground (GeometryReader) can expand
        // the height when used as backgrounds — only content drives the size.
        VStack(spacing: 0) {
            // Push content below Dynamic Island / notch
            Color.clear.frame(height: topSafeAreaInset)

            // Logo + title row
            HStack(spacing: 0) {
                Spacer()
                CloudLogoView(size: 36)
                Text("BSKY DREAMS")
                    .font(.syne(20, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.nbBlack)
                    .padding(.leading, 10)
                Spacer()
            }
            .padding(.vertical, 12)

            // Thin stripe accent at the very bottom of the header
            DiagonalStripeBackground()
                .frame(height: 14)
        }
        .background(Color.nbWhite)
    }

    private var topSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 0
    }

    private var sidebarFooter: some View {
        HStack(spacing: 10) {
            if let handle = auth.session?.handle {
                Button {
                    store.navigationPath.append(ProfileDestination(actor: handle))
                    onNavigate()
                } label: {
                    HStack(spacing: 8) {
                        AvatarView(url: store.currentUserAvatar, size: 32)
                        Text("@\(handle)")
                            .font(.inter(13))
                            .foregroundStyle(Color.nbTextSecondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                auth.logout()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.red)
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.nbWhite)
    }

    private func badgeCount(for tab: AppStore.AppTab) -> Int {
        switch tab {
        case .notifications: store.unreadNotificationCount
        case .dms: store.unreadDMCount
        default: 0
        }
    }
}

// MARK: - Sidebar Nav Button

struct SidebarNavButton: View {
    let tab: AppStore.AppTab
    let isActive: Bool
    let badge: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? Color.white : Color.nbBlack)
                    .frame(width: 20)

                Text(tab.label)
                    .font(.syne(14, weight: isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? Color.white : Color.nbBlack)

                Spacer()

                if badge > 0 {
                    Circle()
                        .fill(isActive ? Color.nbWhite : Color.nbAccent)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(isActive ? Color.nbAccent : Color.clear)
            .overlay(
                isActive ? Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2) : nil
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sidebar Channel Button

struct SidebarChannelButton: View {
    let channel: SavedSearch
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: channel.channelType == "timeline"
                      ? "calendar.day.timeline.leading"
                      : "number")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.nbBlue)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(channel.name)
                        .font(.syne(13))
                        .foregroundStyle(Color.nbBlack)
                    Text(channel.query)
                        .font(.inter(11))
                        .foregroundStyle(Color.nbTextTertiary)
                }

                Spacer()

                if channel.unreadCount > 0 {
                    Text("\(channel.unreadCount)")
                        .font(.inter(10, weight: .bold))
                        .foregroundStyle(Color.nbWhite)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.nbLime)
                        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 1.5))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detail Router

struct DetailView: View {
    let toggleSidebar: () -> Void
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            switch store.selectedTab {
            case .home, nil:
                // FeedView manages its own custom nav bar (hides UIKit toolbar to eliminate
                // system rounded-rect on POST button), so it owns the hamburger button too.
                FeedView(toggleSidebar: toggleSidebar)
            case .search:         SearchView()
            case .notifications:  NotificationsView()
            case .dms:            DMsView()
            case .gallery:        GalleryView()
            case .tv:             TVView()
            case .stream:         StreamView()
            case .reader:         ReaderView()
            case .analytics:      AnalyticsView()
            case .constellation:  ConstellationView()
            case .timeline:       TimelineScrubberView()
            case .settings:       SettingsView()
            }
        }
        // Each tab view manages its own NBNavBar header via .nbNavBar(...) extension.
        // No toolbar set here — avoids UIKit UIBarButtonItem rounded-rect rendering.
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query private var seenPosts: [SeenPost]
    @Query private var cachedPrefs: [CachedPreferences]

    @State private var showClearSeenConfirm = false
    @State private var showLogoutConfirm = false

    private var prefs: CachedPreferences? { cachedPrefs.first }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                settingsHeader
                VStack(spacing: 12) {
                    settingsSection("APPEARANCE") {
                        accentColorRow
                        colorSchemeRow
                        defaultFeedRow
                    }
                    settingsSection("DATA & HISTORY") {
                        seenPostsRow
                    }
                    settingsSection("ACCOUNT") {
                        if let handle = auth.session?.handle {
                            settingsRow(title: "Signed in as", value: "@\(handle)")
                        }
                        Button { showLogoutConfirm = true } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.red)
                                Text("Log Out")
                                    .font(.inter(15))
                                    .foregroundStyle(.red)
                                Spacer()
                            }
                            .padding(14)
                            .background(Color.nbWhite)
                            .nbBorder()
                        }
                        .buttonStyle(.plain)
                    }
                    settingsSection("ABOUT") {
                        settingsRow(
                            title: "Version",
                            value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                        )
                        externalLinkRow(title: "Privacy Policy", subtitle: "bskydreams.com/privacy", url: "https://bskydreams.com/privacy")
                        externalLinkRow(title: "Web App", subtitle: "bskydreams.com", url: "https://bskydreams.com")
                        externalLinkRow(title: "Bluesky", subtitle: "@laserdiscleftist.bsky.social", url: "https://bsky.app/profile/laserdiscleftist.bsky.social")
                        externalLinkRow(title: "Contact Support", subtitle: "ben@bskydreams.com", url: "mailto:ben@bskydreams.com")
                    }
                }
                .padding(16)
            }
        }
        .nbNavBar(title: "SETTINGS", leading: { NBHamburger() })
        .alert("Clear Seen Posts?", isPresented: $showClearSeenConfirm) {
            Button("Clear All", role: .destructive) { clearSeenPosts() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset your feed to show all posts again.")
        }
        .confirmationDialog("Log Out?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { auth.logout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var settingsHeader: some View {
        ZStack {
            DiagonalStripeBackground()
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.nbAccent)
                Text("SETTINGS")
                    .font(.syne(22, weight: .bold))
                    .foregroundStyle(Color.nbBlack)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .nbBorder()
        .padding(.bottom, 16)
    }

    private let accentColors: [(name: String, hex: String)] = [
        ("Blue", "#0047FF"), ("Coral", "#FF5C35"), ("Lime", "#B8E04A"),
        ("Purple", "#AF52DE"), ("Pink", "#FF2D55"), ("Orange", "#FF9500"), ("Teal", "#34C759")
    ]

    private var accentColorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accent Color")
                .font(.inter(14, weight: .semibold))
                .foregroundStyle(Color.nbBlack)
                .padding(.horizontal, 14)
                .padding(.top, 14)
            HStack(spacing: 0) {
                ForEach(accentColors, id: \.hex) { item in
                    let isSelected = store.accentColorHex == item.hex
                    Button { updateAccentColor(item.hex) } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: item.hex))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(Color.nbBlack, lineWidth: isSelected ? 3 : 1.5))
                            Text(item.name)
                                .font(.inter(10))
                                .foregroundStyle(Color.nbTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(Color.nbWhite)
        .nbBorder()
    }

    private var colorSchemeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.inter(14, weight: .semibold))
                .foregroundStyle(Color.nbBlack)
            HStack(spacing: 0) {
                ForEach([("System", "system"), ("Light", "light"), ("Dark", "dark")], id: \.1) { label, value in
                    let isSelected = store.colorSchemeOverride == value
                    Button { store.setColorScheme(value) } label: {
                        Text(label.uppercased())
                            .font(.syne(12, weight: .bold))
                            .foregroundStyle(isSelected ? Color.white : Color.nbBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.nbAccent : Color.nbWhite)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
        }
        .padding(14)
        .background(Color.nbWhite)
        .nbBorder()
    }

    private var defaultFeedRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Feed")
                .font(.inter(14, weight: .semibold))
                .foregroundStyle(Color.nbBlack)
            HStack(spacing: 0) {
                ForEach(AppStore.FeedMode.allCases, id: \.self) { mode in
                    let isSelected = (prefs?.defaultFeedTab ?? "discover") == mode.rawValue.lowercased()
                    Button {
                        updateDefaultFeed(mode.rawValue.lowercased())
                        store.feedMode = mode
                    } label: {
                        Text(mode.rawValue.uppercased())
                            .font(.syne(12, weight: .bold))
                            .foregroundStyle(isSelected ? Color.white : Color.nbBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.nbAccent : Color.nbWhite)
                    }
                }
            }
            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
        }
        .padding(14)
        .background(Color.nbWhite)
        .nbBorder()
    }

    private var seenPostsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Seen Posts")
                    .font(.inter(15, weight: .semibold))
                    .foregroundStyle(Color.nbBlack)
                Text("\(seenPosts.filter { $0.seenAt >= Date().addingTimeInterval(-7 * 24 * 3600) }.count) posts tracked (last 7 days)")
                    .font(.inter(12))
                    .foregroundStyle(Color.nbTextSecondary)
            }
            Spacer()
            Button { showClearSeenConfirm = true } label: {
                Text("CLEAR")
                    .font(.syne(12, weight: .bold))
                    .foregroundStyle(Color.nbBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.nbWhite)
                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                    .background(Color.nbBlack.offset(x: 2, y: 2))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.nbWhite)
        .nbBorder()
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.syne(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color.nbTextTertiary)
                .padding(.leading, 4)
            content()
        }
    }

    private func externalLinkRow(title: String, subtitle: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        } label: {
            HStack {
                Text(title)
                    .font(.inter(15))
                    .foregroundStyle(Color.nbBlack)
                Spacer()
                Text(subtitle)
                    .font(.inter(13))
                    .foregroundStyle(Color.nbBlue)
                    .lineLimit(1)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nbBlue)
            }
            .padding(14)
            .background(Color.nbWhite)
            .nbBorder()
        }
        .buttonStyle(.plain)
    }

    private func settingsRow(title: String, value: String) -> some View {
        HStack {
            Text(title).font(.inter(15)).foregroundStyle(Color.nbBlack)
            Spacer()
            Text(value).font(.inter(14)).foregroundStyle(Color.nbTextSecondary)
        }
        .padding(14)
        .background(Color.nbWhite)
        .nbBorder()
    }

    private func clearSeenPosts() {
        for post in seenPosts { modelContext.delete(post) }
    }

    private func updateAccentColor(_ hex: String) {
        store.setAccentColor(hex)
        if let p = prefs { p.accentColorHex = hex }
        else { let p = CachedPreferences(); p.accentColorHex = hex; modelContext.insert(p) }
        updateAppIcon(for: hex)
    }

    private func updateAppIcon(for hex: String) {
        let iconMap: [String: String?] = [
            "#0047FF": nil,           // primary (blue)
            "#FF5C35": "AppIcon-Coral",
            "#B8E04A": "AppIcon-Lime",
            "#AF52DE": "AppIcon-Purple",
            "#FF2D55": "AppIcon-Pink",
            "#FF9500": "AppIcon-Orange",
            "#34C759": "AppIcon-Teal",
        ]
        guard UIApplication.shared.supportsAlternateIcons,
              let iconName = iconMap[hex] else {
            if hex == "#0047FF" {
                UIApplication.shared.setAlternateIconName(nil) { _ in }
            }
            return
        }
        UIApplication.shared.setAlternateIconName(iconName) { _ in }
    }

    private func updateDefaultFeed(_ tab: String) {
        if let p = prefs { p.defaultFeedTab = tab }
        else { let p = CachedPreferences(); p.defaultFeedTab = tab; modelContext.insert(p) }
    }
}
