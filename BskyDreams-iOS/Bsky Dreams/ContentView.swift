import SwiftUI
import SwiftData
import UserNotifications

struct RootView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if auth.isLoggedIn {
                MainAppView()
            } else {
                LoginView()
            }
        }
        #if DEBUG
        .task { await DebugLaunchDoors.apply(auth: auth, store: store) }
        .modifier(DebugTypeSizeOverride())
        #endif
    }
}

// MARK: - Main App (native shell, iOS-DESIGN §1, §10)
//
// Apple's own navigation, so iPhone Duo can do what it was built to do: a `TabView`
// with `.sidebarAdaptable` is a tab bar on every iPhone, moves into the vertical bar
// beside the status bar on the closed Duo (and the inner display in landscape), and
// becomes the system's collapsible sidebar on the open Duo. Each tab has its own
// `NavigationStack`; screens use the system navigation bar (see NBNavBar.swift).

struct MainAppView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var seenPosts: [SeenPost]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let seenMaxAge: TimeInterval = 7 * 24 * 3600

    /// Regular width AND regular height = the open iPhone Duo's inner display, every pose.
    private var isSplitLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    private var showsSidebarPlaces: Bool { horizontalSizeClass == .regular }

    private var tabSelection: Binding<AppStore.AppTab> {
        Binding(get: { store.selectedTab ?? .home }, set: { store.selectedTab = $0 })
    }

    // People may reorder/hide sidebar entries (system customization); kept across launches.
    @AppStorage("tabCustomization.v2") private var tabCustomizationData = Data()
    private var tabCustomization: Binding<TabViewCustomization> {
        Binding(
            get: { (try? JSONDecoder().decode(TabViewCustomization.self, from: tabCustomizationData))
                   ?? TabViewCustomization() },
            set: { tabCustomizationData = (try? JSONEncoder().encode($0)) ?? Data() })
    }

    var body: some View {
        TabView(selection: tabSelection) {
            phoneTabs
            // More: compact width only. At regular width the sidebar / vertical bar lists
            // its places, and the system's own "…" overflow covers what doesn't fit — a
            // More tab there was a second, duplicate overflow (owner, 2026-11-10).
            if !showsSidebarPlaces { exploreTab }
            // Sidebar places only at regular width: hidden-for-tab-bar tabs still count
            // toward the phone's bar and make the system add its own More tab.
            if showsSidebarPlaces { sidebarPlaces }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization(tabCustomization)
        .onChange(of: showsSidebarPlaces, initial: true) { _, shown in
            store.sidebarPlacesShown = shown
            // Narrowed to compact (Duo closed, Split View): a selected sidebar place hands
            // over to More, opened at that place.
            if !shown, let tab = store.selectedTab, !tab.isPhoneTab {
                store.select(tab)
            }
            // Widened: More's place becomes its own sidebar entry.
            if shown, store.selectedTab == .explore {
                store.selectedTab = .home
            }
        }
        .onChange(of: isSplitLayout, initial: true) { _, split in
            store.setSplitLayoutActive(split)
        }
        .onChange(of: store.secondaryTab) { _, _ in
            store.secondaryPath = NavigationPath()
        }
        .overlay(alignment: .bottom) {
            if let failed = store.failedPost {
                NBErrorBanner(message: "Your post didn't send — \(failed.reason)",
                              retry: { store.retryFailedPost() },
                              onDismiss: { store.failedPost = nil })
                    .padding(.bottom, 24)
            } else if let message = store.actionError {
                NBErrorBanner(message: message, onDismiss: { store.actionError = nil })
                    .padding(.bottom, 24)
            }
        }
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
                store.select(.dms)   // a place: its own tab when open, inside More when closed
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
            store.detailPaneTabChanged()
        }
    }

    @TabContentBuilder<AppStore.AppTab>
    private var phoneTabs: some TabContent<AppStore.AppTab> {
        Tab(AppStore.AppTab.home.label, systemImage: AppStore.AppTab.home.icon,
            value: AppStore.AppTab.home) {
            TabColumns(tab: .home)
        }
        .customizationID("home")
        Tab(AppStore.AppTab.search.label, systemImage: AppStore.AppTab.search.icon,
            value: AppStore.AppTab.search, role: .search) {
            TabColumns(tab: .search)
        }
        .customizationID("search")
        Tab(AppStore.AppTab.notifications.label, systemImage: AppStore.AppTab.notifications.icon,
            value: AppStore.AppTab.notifications) {
            TabColumns(tab: .notifications)
        }
        .badge(store.unreadNotificationCount)
        .customizationID("notifications")
        Tab(AppStore.AppTab.reader.label, systemImage: AppStore.AppTab.reader.icon,
            value: AppStore.AppTab.reader) {
            TabColumns(tab: .reader)
        }
        .customizationID("reader")
    }

    @TabContentBuilder<AppStore.AppTab>
    private var exploreTab: some TabContent<AppStore.AppTab> {
        Tab(AppStore.AppTab.explore.label, systemImage: AppStore.AppTab.explore.icon,
            value: AppStore.AppTab.explore) {
            TabColumns(tab: .explore)
        }
        .customizationID("explore")
    }

    @TabContentBuilder<AppStore.AppTab>
    private var sidebarPlaces: some TabContent<AppStore.AppTab> {
        ForEach(AppStore.AppTab.sidebarPlaces, id: \.self) { tab in
            Tab(tab.label, systemImage: tab.icon, value: tab) {
                TabColumns(tab: tab)
            }
            .badge(tab == .dms ? store.unreadDMCount : 0)
            .customizationID(tab.rawValue)
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

    /// Badges are ambient, best-effort hints: a failed refresh keeps the last count
    /// (no banner — the views themselves surface real failures).
    private func refreshBadges() async {
        async let notifs = try? ATProtocolClient.shared.unreadNotificationCount()
        async let convos = try? ATProtocolClient.shared.listConversations(limit: 50)
        if let n = await notifs { store.unreadNotificationCount = n }
        if let c = await convos {
            // Accepted conversations only — requests have their own inbox.
            store.unreadDMCount = c.convos.filter { $0.status != "request" }.reduce(0) { $0 + $1.unreadCount }
        }
    }

    private func fetchCurrentUserAvatar() async {
        guard let did = auth.session?.did else { return }
        if let profile = try? await ATProtocolClient.shared.getProfile(actor: did) {
            store.currentUserAvatar = profile.avatar
        }
    }
}

// MARK: - A tab's columns (open iPhone Duo, §10.3)

/// One tab's content: the tab's own NavigationStack, and on the open Duo a right side
/// (the conversation pane or a second view) — in `FoldSplitLayout`, whose divider sits on
/// the fold (Apple's reserved-region API) in book and tabletop poses.
struct TabColumns: View {
    let tab: AppStore.AppTab
    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isSplitLayout: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
    private var isCurrent: Bool { (store.selectedTab ?? .home) == tab }
    private var hasRightPane: Bool {
        guard isSplitLayout, !tab.isFullScreenExperience else { return false }
        return store.secondaryTab != nil || tab.hostsPostPane || tab == .dms
    }

    /// ONE container in every state — closed, open, rotated, either Layout choice — with
    /// the primary column always in the same slot. Switching containers (one column ↔
    /// ArrangementView ↔ HStack) made SwiftUI rebuild the column, so every open/close
    /// reloaded the feed and lost the person's place (owner, device, 2026-11-10).
    /// Only the right side comes and goes.
    var body: some View {
        FoldSplitLayout(stacked: stacked, fold: foldGap) {
            primary
                // With a right side, the primary never touches the trailing (or, stacked,
                // bottom) edge — the vertical bar / tab bar's inset belongs to the right
                // side. Without this the column was laid out 84pt narrower than its frame
                // (the rail's width), as if the rail sat beside it (owner, device).
                .ignoresSafeArea(edges: primaryIgnoredEdges)
                .environment(\.barInsetEdges, primaryIgnoredEdges)
            if hasRightPane {
                rightPane
                    .overlay(alignment: stacked ? .top : .leading) {
                        Rectangle().fill(Color.nbBorder)
                            .frame(width: stacked ? nil : 1, height: stacked ? 1 : nil)
                    }
            }
        }
        .onGeometryChange(for: FoldGeometry.self) { proxy in
            FoldGeometry(proxy: proxy)
        } action: { geo in
            fold = geo
            if isCurrent { store.columnsAreTall = geo.isTall }
        }
    }

    @State private var fold = FoldGeometry()
    /// With a right side, the primary never touches the trailing (stacked: bottom) edge,
    /// so the vertical bar's / tab bar's inset there isn't its to keep.
    private var primaryIgnoredEdges: Edge.Set { hasRightPane ? (stacked ? .bottom : .trailing) : [] }

    /// Rotated (taller than wide) stacks top/bottom unless the person chose side by side.
    private var stacked: Bool { fold.isTall && !store.columnsSideBySideWhenTall }
    /// The fold's span along the split axis, when the device is folded (book or tabletop)
    /// and the fold runs across that axis — the columns meet on either side of it.
    private var foldGap: ClosedRange<CGFloat>? { stacked ? fold.foldY : fold.foldX }

    private var primary: some View {
        NavigationStack(path: store.pathBinding(tab)) {
            DetailView(tab: tab)
                .withAppDestinations(myDid: auth.session?.did ?? "")
                // The Duo's vertical bar adds its inset to EVERY view controller under the
                // tab view (UIKit additionalSafeAreaInsets — not geometric, so SwiftUI's
                // ignoresSafeArea can't remove it): the left column's root measured 350pt
                // in a 434pt column. Cancel it on this stack's navigation controller.
                .modifier(BarInsetCancelling())
                .toolbar {
                    // Full-display screens on the open Duo (TV, Stream…): no right side to
                    // hold the menu, so it sits here (§10.3).
                    if isSplitLayout && !hasRightPane && !tab.isFullScreenExperience {
                        ToolbarItem(placement: .topBarTrailing) { NBColumnMenu() }
                    }
                }
        }
    }

    @ViewBuilder
    private var rightPane: some View {
        if let column = store.secondaryTab {
            if isCurrent {
                SecondaryColumn(tab: column)
            } else {
                Color.nbBackground
            }
        } else if isCurrent, let item = store.detailPane {
            DetailPaneView(item: item)
        } else {
            NavigationStack {
                NBEmptyState(
                    icon: tab == .dms ? "bubble.left.and.bubble.right" : "text.bubble",
                    title: tab == .dms ? "No chat open" : "No conversation open",
                    message: tab == .dms
                        ? "Pick a chat and it opens here."
                        : "Tap a post and its conversation opens here. Use Right Side to show another view instead."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.nbBackground)
                .toolbar { ToolbarItem(placement: .topBarLeading) { NBColumnMenu() } }
            }
        }
    }
}

/// The open Duo's second column: any destination, with its own stack, so what you open
/// there stays there. Its leading toolbar item picks the view or closes the column.
struct SecondaryColumn: View {
    let tab: AppStore.AppTab
    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth

    var body: some View {
        NavigationStack(path: Bindable(store).secondaryPath) {
            DetailView(tab: tab)
                .id(tab)
                .withAppDestinations(myDid: auth.session?.did ?? "")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { NBColumnMenu() }
                }
        }
        .environment(\.navColumn, .secondary)
    }
}

/// A destination opened inside More (compact width).
struct ExplorePlace: Hashable {
    let tab: AppStore.AppTab
}

/// More — compact width (every iPhone, the closed Duo): the destinations that aren't in
/// the tab bar, the saved channels, and the account. A system List.
struct ExploreView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @State private var confirmSignOut = false

    var body: some View {
        List {
            Section {
                ForEach(AppStore.AppTab.sidebarPlaces.filter { $0 != .channels }, id: \.self) { tab in
                    NavigationLink(value: ExplorePlace(tab: tab)) {
                        Label(tab.label, systemImage: tab.icon)
                    }
                }
            }
            ChannelsSection()
            Section("Account") {
                if let handle = auth.session?.handle {
                    NavigationLink(value: ProfileDestination(actor: handle)) {
                        Label("@\(handle)", systemImage: "person.crop.circle")
                    }
                }
                Button(role: .destructive) { confirmSignOut = true } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .confirmationDialog("Sign out of Bsky Dreams?", isPresented: $confirmSignOut,
                                    titleVisibility: .visible) {
                    Button("Sign Out", role: .destructive) { auth.logout() }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
        .navigationTitle("More")
    }
}

/// Channels — regular width: a sidebar place listing the saved channels.
struct ChannelsView: View {
    var body: some View {
        List { ChannelsSection() }
            .navigationTitle("Channels")
    }
}

/// The saved search / timeline channels: tap to open, context menu to rename or delete.
struct ChannelsSection: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query private var savedSearches: [SavedSearch]
    @State private var editingChannel: SavedSearch? = nil
    @State private var channelRenameText = ""

    var body: some View {
        Section("Channels") {
            if savedSearches.isEmpty {
                Text("Save a search or a timeline to keep it here.")
                    .foregroundStyle(.secondary)
            }
            ForEach(savedSearches) { channel in
                Button {
                    store.openChannel(query: channel.query, isTimeline: channel.channelType == "timeline")
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(channel.name)
                            Text(channel.query).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: channel.channelType == "timeline"
                              ? "calendar.day.timeline.leading" : "number")
                    }
                }
                .badge(channel.unreadCount)
                .contextMenu {
                    Button("Rename", systemImage: "pencil") {
                        channelRenameText = channel.name
                        editingChannel = channel
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        modelContext.delete(channel)
                    }
                }
            }
        }
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
}

// MARK: - Shared push destinations

extension View {
    /// Every push destination, for each stack: the main stack, and on the open iPhone
    /// Duo the second column's and the detail pane's (iOS-DESIGN §1.1, §10.3).
    func withAppDestinations(myDid: String) -> some View {
        self
            .navigationDestination(for: ExplorePlace.self) { place in
                DetailView(tab: place.tab)
                    .modifier(BarInsetCancelling())
                    .environment(\.nbIsPushed, true)
            }
            .navigationDestination(for: PostDestination.self) { dest in
                ThreadView(uri: dest.uri, initialPost: dest.post)
                    .modifier(BarInsetCancelling())
                    .enableNavigationBackSwipe()
                    .environment(\.nbIsPushed, true)
            }
            .navigationDestination(for: ProfileDestination.self) { dest in
                ProfileView(actor: dest.actor)
                    .modifier(BarInsetCancelling())
                    .enableNavigationBackSwipe()
                    .environment(\.nbIsPushed, true)
            }
            .navigationDestination(for: HashtagDestination.self) { dest in
                SearchView(initialQuery: "#\(dest.tag)")
                    .modifier(BarInsetCancelling())
                    .enableNavigationBackSwipe()
                    .environment(\.nbIsPushed, true)
            }
            .navigationDestination(for: Conversation.self) { convo in
                ChatView(conversation: convo, myDid: myDid)
                    .modifier(BarInsetCancelling())
                    .enableNavigationBackSwipe()
                    .environment(\.nbIsPushed, true)
            }
            .navigationDestination(for: AnalyticsDestination.self) { dest in
                AnalyticsView(initialActor: dest.actor)
                    .modifier(BarInsetCancelling())
                    .enableNavigationBackSwipe()
                    .environment(\.nbIsPushed, true)
            }
            .navigationDestination(for: ConstellationDestination.self) { dest in
                ConstellationView(initialActor: dest.actor)
                    .modifier(BarInsetCancelling())
                    .enableNavigationBackSwipe()
                    .environment(\.nbIsPushed, true)
            }
    }
}

// MARK: - iPhone Duo detail pane (iOS-DESIGN §10)

/// The right-hand pane on the open iPhone Duo: the conversation or chat opened from the
/// list beside it. It is the detail column of a list/detail split (what
/// NavigationSplitView's detail column is), so it owns a small stack of its own for
/// drilling into replies — §1.1's "one stack" still governs every other push flow.
struct DetailPaneView: View {
    let item: AppStore.DetailPaneItem
    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth

    var body: some View {
        NavigationStack(path: Bindable(store).detailPanePath) {
            paneRoot
                .withAppDestinations(myDid: auth.session?.did ?? "")
                .toolbar { ToolbarItem(placement: .topBarLeading) { NBColumnMenu() } }
        }
        .environment(\.navColumn, .detail)
        .environment(\.closeDetailPane, { store.closeDetailPane() })
        .id(item.id)   // a new conversation gets fresh view state, not the last one's
    }

    @ViewBuilder
    private var paneRoot: some View {
        switch item {
        case .post(let dest):
            ThreadView(uri: dest.uri, initialPost: dest.post)
        case .chat(let convo):
            ChatView(conversation: convo, myDid: auth.session?.did ?? "")
        case .profile(let dest):
            ProfileView(actor: dest.actor)
        }
    }
}

// MARK: - Detail Router

struct DetailView: View {
    /// Which destination this column shows.
    let tab: AppStore.AppTab

    var body: some View {
        switch tab {
        case .home:           FeedView()
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
        case .explore:        ExploreView()
        case .channels:       ChannelsView()
        }
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
    @State private var cacheCleared = false
    @State private var hints = HintsManager.shared

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
                        clearCacheRow
                        notificationSettingsRow
                    }
                    settingsSection("TIPS & HINTS") {
                        hintsToggleRow
                        resetHintsRow
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
                        // App Review 4.1: a brand name in the app name needs a clear independence line.
                        Text("Bsky Dreams is an independent app and is not affiliated with or endorsed by Bluesky Social, PBC.")
                            .font(.inter(12))
                            .foregroundStyle(Color.nbTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
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

    /// The Memphis stripe as a thin band — the nav bar already says SETTINGS, so the old
    /// 22pt duplicate title (≈52pt tall) is gone.
    private var settingsHeader: some View {
        DiagonalStripeBackground()
            .frame(height: 12)
            .nbBorder()
            .padding(.bottom, 16)
            .accessibilityHidden(true)
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
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.name) accent")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            // Seven swatches across 390pt: names split mid-word ("Cor/al") at
            // accessibility sizes (device run). Chrome caps; the labels stay readable.
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(isSelected ? Color.nbLabel(on: .nbAccent) : Color.nbBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.nbAccent : Color.nbWhite)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)   // segmented chrome cap
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
                    // Legacy default "discover" maps to the new Conversations feed.
                    let stored = (prefs?.defaultFeedTab ?? "conversations")
                    let normalized = stored == "discover" ? "conversations" : stored
                    let isSelected = normalized == mode.rawValue.lowercased()
                    Button {
                        updateDefaultFeed(mode.rawValue.lowercased())
                        store.feedMode = mode
                    } label: {
                        Text(mode.rawValue.uppercased())
                            .font(.syne(11, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .dynamicTypeSize(...DynamicTypeSize.xxLarge)   // segmented chrome cap
                            .foregroundStyle(isSelected ? Color.nbLabel(on: .nbAccent) : Color.nbBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 4)
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

    private var clearCacheRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Image Cache")
                    .font(.inter(15, weight: .semibold))
                    .foregroundStyle(Color.nbBlack)
                Text(cacheCleared ? "Cleared" : "Free up space used by cached images")
                    .font(.inter(12))
                    .foregroundStyle(cacheCleared ? Color.nbLinkColor : Color.nbTextSecondary)
            }
            Spacer()
            Button {
                NBImageLoader.clearCache()
                Haptics.success()
                withAnimation { cacheCleared = true }
            } label: {
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
            .accessibilityLabel("Clear image cache")
        }
        .padding(14)
        .background(Color.nbWhite)
        .nbBorder()
    }

    private var notificationSettingsRow: some View {
        Button {
            if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
        } label: {
            HStack {
                Text("Notification Settings")
                    .font(.inter(15))
                    .foregroundStyle(Color.nbBlack)
                Spacer()
                Text("System")
                    .font(.inter(13))
                    .foregroundStyle(Color.nbLinkColor)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nbLinkColor)
            }
            .padding(14)
            .background(Color.nbWhite)
            .nbBorder()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open notification settings in the system Settings app")
    }

    private var hintsToggleRow: some View {
        Toggle(isOn: Binding(
            get: { hints.hintsEnabled },
            set: { hints.hintsEnabled = $0; Haptics.selection() }
        )) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Show Tips")
                    .font(.inter(15, weight: .semibold))
                    .foregroundStyle(Color.nbBlack)
                Text("In-context hints on feeds and tools")
                    .font(.inter(12))
                    .foregroundStyle(Color.nbTextSecondary)
            }
        }
        .tint(Color.nbAccent)
        .padding(14)
        .background(Color.nbWhite)
        .nbBorder()
    }

    private var resetHintsRow: some View {
        Button {
            hints.resetAll()
            Haptics.success()
        } label: {
            HStack {
                Text("Reset All Tips")
                    .font(.inter(15))
                    .foregroundStyle(Color.nbBlack)
                Spacer()
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nbAccentLegible)
            }
            .padding(14)
            .background(Color.nbWhite)
            .nbBorder()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reset all dismissed tips")
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
                    .foregroundStyle(Color.nbLinkColor)
                    .lineLimit(1)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.nbLinkColor)
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
        if let did = auth.session?.did { Task { await store.clearSeenInCloud(did: did) } }
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

// MARK: - Duo columns container (iOS-DESIGN §10.3)

/// Where the fold is, from Apple's reserved-region API (the API for custom layouts on
/// iPhone Duo). Active only while the device is folded; flat, the columns split evenly.
nonisolated struct FoldGeometry: Equatable, Sendable {
    var isTall = false
    var foldX: ClosedRange<CGFloat>? = nil   // a fold running top to bottom (book)
    var foldY: ClosedRange<CGFloat>? = nil   // a fold running across (rotated / tabletop)

    init() {}
    @MainActor init(proxy: GeometryProxy) {
        isTall = proxy.size.height > proxy.size.width
        if #available(iOS 27.1, *) {
            for region in proxy.reservedRegions(kind: .division) where region.isActive {
                let f = region.frame
                if f.height >= f.width { foldX = f.minX...f.maxX } else { foldY = f.minY...f.maxY }
            }
        }
    }
}

/// Primary + optional second view, side by side or stacked. Halves, or — when the device
/// is folded across the split axis — the halves meet at the fold's edges (what Apple's
/// ArrangementView does; verified on device: 0–455.5 | 495.5–867pt). One Layout type in
/// every state, so the primary column keeps its identity and state.
struct FoldSplitLayout: Layout {
    var stacked: Bool
    var fold: ClosedRange<CGFloat>?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let first = subviews.first else { return }
        guard subviews.count > 1 else {
            first.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            return
        }
        let total = stacked ? bounds.height : bounds.width
        var firstEnd = (total / 2).rounded()
        var secondStart = firstEnd
        // Use the fold only if it's near the middle (never squeeze a column to a sliver).
        if let fold, fold.lowerBound > total * 0.3, fold.upperBound < total * 0.7 {
            firstEnd = fold.lowerBound
            secondStart = fold.upperBound
        }
        if stacked {
            first.place(at: bounds.origin,
                        proposal: ProposedViewSize(width: bounds.width, height: firstEnd))
            subviews[1].place(at: CGPoint(x: bounds.minX, y: bounds.minY + secondStart),
                              proposal: ProposedViewSize(width: bounds.width, height: total - secondStart))
        } else {
            first.place(at: bounds.origin,
                        proposal: ProposedViewSize(width: firstEnd, height: bounds.height))
            subviews[1].place(at: CGPoint(x: bounds.minX + secondStart, y: bounds.minY),
                              proposal: ProposedViewSize(width: total - secondStart, height: bounds.height))
        }
    }
}

/// Cancels, on this screen's hosting controller, the inset the iPhone Duo's vertical bar
/// (or a bottom tab bar) propagates to every screen under the tab view — for a column that
/// doesn't touch that edge. Applied to every screen of the primary column via
/// `\.barInsetEdges` + `.withAppDestinations` (pushed screens have their own controller). Measures the inherited inset and offsets it
/// with `additionalSafeAreaInsets`; a no-op when `edges` is empty (§10.3).
struct BarInsetCanceller: UIViewRepresentable {
    let edges: Edge.Set

    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) {
        view.edges = edges
        view.setNeedsLayout()
    }

    final class Probe: UIView {
        var edges: Edge.Set = []

        override func layoutSubviews() {
            super.layoutSubviews()
            apply()
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            // The nearest view controller is this screen's hosting controller; SwiftUI hands
            // it the tab view's inset directly (the navigation controller above it has 0).
            var r: UIResponder? = self
            while let next = r?.next, !(next is UIViewController) { r = next }
            guard let vc = r?.next as? UIViewController, vc.view.window != nil else { return }
            let added = vc.additionalSafeAreaInsets
            let total = vc.view.safeAreaInsets
            var want = UIEdgeInsets.zero
            if edges.contains(.trailing) { want.right = -(total.right - added.right) }
            if edges.contains(.bottom) { want.bottom = -(total.bottom - added.bottom) }
            if want != added { vc.additionalSafeAreaInsets = want }
        }
    }
}

private struct BarInsetEdgesKey: EnvironmentKey {
    static let defaultValue: Edge.Set = []
}
extension EnvironmentValues {
    /// Edges whose inherited bar inset this column's screens cancel (open Duo, left column).
    var barInsetEdges: Edge.Set {
        get { self[BarInsetEdgesKey.self] }
        set { self[BarInsetEdgesKey.self] = newValue }
    }
}

/// Applies `BarInsetCanceller` with the column's `\.barInsetEdges`.
struct BarInsetCancelling: ViewModifier {
    @Environment(\.barInsetEdges) private var edges
    func body(content: Content) -> some View {
        content.background(BarInsetCanceller(edges: edges))
    }
}

