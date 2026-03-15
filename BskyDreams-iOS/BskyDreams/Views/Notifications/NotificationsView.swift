import SwiftUI

struct NotificationsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store

    @State private var notifications: [BskyNotification] = []
    @State private var cursor: String?
    @State private var isLoading = false
    @State private var groupedByDate: [(String, [BskyNotification])] = []

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && notifications.isEmpty {
                    ProgressView("Loading notifications...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if notifications.isEmpty {
                    ContentUnavailableView("No Notifications", systemImage: "bell.slash", description: Text("You're all caught up!"))
                } else {
                    notificationList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PostDestination.self) { dest in
                ThreadView(uri: dest.uri, initialPost: dest.post)
            }
            .navigationDestination(for: ProfileDestination.self) { dest in
                ProfileView(actor: dest.actor)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark All Read") { markAllRead() }
                        .font(.inter(14))
                        .foregroundStyle(Color.nbBlue)
                }
            }
        }
        .task { await load() }
    }

    private var notificationList: some View {
        List {
            ForEach(notifications) { notif in
                NotificationRowView(notification: notif)
                    .listRowSeparator(.hidden)
                    .listRowBackground(notif.isRead ? Color.clear : Color.nbAccent.opacity(0.05))
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .onAppear {
                        if notif.id == notifications.last?.id {
                            Task { await loadMore() }
                        }
                    }
            }
            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await ATProtocolClient.shared.listNotifications()
            notifications = resp.notifications
            cursor = resp.cursor
            store.unreadNotificationCount = 0
            try? await ATProtocolClient.shared.updateNotificationsSeen()
        } catch {}
    }

    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await ATProtocolClient.shared.listNotifications(cursor: cursor)
            notifications.append(contentsOf: resp.notifications)
            cursor = resp.cursor
        } catch {}
    }

    private func markAllRead() {
        Task { try? await ATProtocolClient.shared.updateNotificationsSeen() }
    }
}

// MARK: - Notification Row

struct NotificationRowView: View {
    let notification: BskyNotification

    var accentColor: Color {
        switch notification.reason {
        case .like: return .nbAccent
        case .repost: return .nbLime
        case .follow: return .nbBlue
        default: return .nbBlack
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                NavigationLink(value: ProfileDestination(actor: notification.author.did)) {
                    AvatarView(url: notification.author.avatar, size: 44)
                }
                .buttonStyle(.plain)

                Image(systemName: notification.reason.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(accentColor)
                    .clipShape(.circle)
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Group {
                    Text(notification.author.name)
                        .font(.inter(14, weight: .semibold))
                    + Text(" \(notification.reason.displayName)")
                        .font(.inter(14))
                }
                .foregroundStyle(Color.nbBlack)

                if let text = notification.record?.text, !text.isEmpty {
                    Text(text)
                        .font(.inter(13))
                        .foregroundStyle(Color.nbBlack.opacity(0.6))
                        .lineLimit(2)
                }

                let formatter = RelativeDateTimeFormatter()
                if let date = ISO8601DateFormatter().date(from: notification.indexedAt) {
                    Text(formatter.localizedString(for: date, relativeTo: Date()))
                        .font(.inter(12))
                        .foregroundStyle(Color.nbBlack.opacity(0.4))
                }
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(Color.nbAccent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }
}
