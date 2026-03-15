import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store

    var body: some View {
        if auth.isLoggedIn {
            MainAppView()
        } else {
            LoginView()
        }
    }
}

// MARK: - Main App (iPad: NavigationSplitView, iPhone: Tab-based sidebar)

struct MainAppView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store
    @Environment(ATProtocolClient.self) private var api

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
        .task {
            ATProtocolClient.shared.configure(authManager: auth)
            await refreshBadges()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await auth.refreshIfNeeded() }
        }
    }

    private func refreshBadges() async {
        do {
            let notifs = try await ATProtocolClient.shared.listNotifications(limit: 1)
            store.unreadNotificationCount = notifs.notifications.filter { !$0.isRead }.count
        } catch {}
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthManager.self) private var auth

    var body: some View {
        List(selection: Bindable(store).selectedTab) {
            Section {
                ForEach(AppStore.AppTab.allCases, id: \.self) { tab in
                    NavigationLink(value: tab) {
                        SidebarRow(tab: tab, store: store)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Bsky Dreams")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Log Out", role: .destructive) { auth.logout() }
                } label: {
                    AsyncImage(url: URL(string: "")) { _ in
                        Image(systemName: "person.circle")
                    } placeholder: {
                        Image(systemName: "person.circle")
                    }
                }
            }
        }
    }
}

struct SidebarRow: View {
    let tab: AppStore.AppTab
    let store: AppStore

    var badge: Int {
        switch tab {
        case .notifications: store.unreadNotificationCount
        case .dms: store.unreadDMCount
        default: 0
        }
    }

    var body: some View {
        Label(tab.label, systemImage: tab.icon)
            .badge(badge > 0 ? badge : nil)
    }
}

// MARK: - Detail Router

struct DetailView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        switch store.selectedTab {
        case .feed:
            FeedView()
        case .search:
            SearchView()
        case .compose:
            ComposeView()
        case .notifications:
            NotificationsView()
        case .dms:
            DMsView()
        case .gallery:
            GalleryView()
        case .tv:
            TVView()
        case .reader:
            ReaderView()
        case .analytics:
            AnalyticsView()
        case .constellation:
            ConstellationView()
        }
    }
}
