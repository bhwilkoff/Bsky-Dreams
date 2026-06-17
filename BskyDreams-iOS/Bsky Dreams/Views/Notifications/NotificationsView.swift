import SwiftUI
import UserNotifications

// MARK: - Notification Group
// Groups consecutive likes/reposts that share the same subject URI

struct NotificationGroup: Identifiable {
    let id: String
    let notifications: [BskyNotification]
    var subjectText: String? = nil

    var primary: BskyNotification { notifications[0] }

    var displayText: String {
        guard notifications.count > 1 else { return "" }
        let extra = notifications.count - 1
        return "+\(extra) more"
    }

    var isGrouped: Bool { notifications.count > 1 }
}

struct NotificationsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store
    @Environment(NetworkMonitor.self) private var network

    @State private var notifications: [BskyNotification] = []
    @State private var groups: [NotificationGroup] = []
    @State private var cursor: String?
    @State private var isLoading = false
    @State private var scrollToTopTrigger = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if network.isOffline { NBOfflineBanner() }
            if let errorMessage {
                NBErrorBanner(
                    message: errorMessage,
                    retry: { self.errorMessage = nil; Task { await load() } },
                    onDismiss: { self.errorMessage = nil }
                )
            }
            Group {
                if isLoading && notifications.isEmpty {
                    ProgressView("Loading notifications...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if groups.isEmpty {
                    NBEmptyState(
                        icon: "bell.slash",
                        title: "No Notifications",
                        message: "You're all caught up!"
                    )
                } else {
                    notificationList
                }
            }
        }
        .nbNavBar(title: "NOTIFICATIONS", leading: { NBHamburger() }, trailing: {
            Text("MARK READ")
                .font(.syne(10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.nbBlack)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                .contentShape(Rectangle())
                .onTapGesture { markAllRead() }
        })
        .task { await load() }
    }

    private var notificationList: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 0).id("notif-top")
                ForEach(groups) { group in
                    NotificationGroupRowView(group: group)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(group.primary.isRead ? Color.clear : Color.nbAccent.opacity(0.05))
                        .onAppear {
                            if group.id == groups.last?.id {
                                Task { await loadMore() }
                            }
                        }
                    Divider().padding(.horizontal, 12)
                }
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                }
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await load() }
        .onChange(of: scrollToTopTrigger) { _, _ in
            withAnimation { proxy.scrollTo("notif-top", anchor: .top) }
        }
        }
    }

    // MARK: - Grouping

    private func buildGroups(from notifs: [BskyNotification]) -> [NotificationGroup] {
        var result: [NotificationGroup] = []
        var i = 0
        while i < notifs.count {
            let n = notifs[i]
            // Group likes/reposts (including via-repost variants) that share the same reasonSubject
            let isGroupable = [.like, .repost, .likeViaRepost, .repostViaRepost].contains(n.reason)
            if isGroupable, let subject = n.reasonSubject {
                var grouped = [n]
                var j = i + 1
                while j < notifs.count {
                    let m = notifs[j]
                    if m.reason == n.reason && m.reasonSubject == subject {
                        grouped.append(m)
                        j += 1
                    } else {
                        break
                    }
                }
                result.append(NotificationGroup(id: n.uri, notifications: grouped))
                i = j
            } else {
                result.append(NotificationGroup(id: n.uri, notifications: [n]))
                i += 1
            }
        }
        return result
    }

    // MARK: - Subject text fetching

    private func enrichGroupsWithSubjectText(_ groups: inout [NotificationGroup]) async {
        let subjectReasons: Set<BskyNotification.NotificationReason> = [.like, .repost, .likeViaRepost, .repostViaRepost]
        let subjectURIs = groups
            .compactMap { g -> String? in
                guard subjectReasons.contains(g.primary.reason) else { return nil }
                return g.primary.reasonSubject
            }
        guard !subjectURIs.isEmpty else { return }
        let uniqueURIs = Array(Set(subjectURIs))
        guard let posts = try? await ATProtocolClient.shared.getPosts(uris: uniqueURIs) else { return }
        let textMap = Dictionary(uniqueKeysWithValues: posts.map { ($0.uri, $0.record.text) })
        for i in groups.indices {
            if let subject = groups[i].primary.reasonSubject,
               let text = textMap[subject], !text.isEmpty {
                groups[i].subjectText = text
            }
        }
    }

    // MARK: - Data Loading

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await ATProtocolClient.shared.listNotifications()
            // Merge: prepend genuinely new notifications, preserve cached older ones
            let existingURIs = Set(notifications.map { $0.uri })
            let freshOnly = resp.notifications.filter { !existingURIs.contains($0.uri) }
            let merged = freshOnly + notifications
            var newGroups = buildGroups(from: merged)
            await enrichGroupsWithSubjectText(&newGroups)
            notifications = merged
            cursor = resp.cursor
            groups = newGroups
            store.unreadNotificationCount = 0
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
            try? await ATProtocolClient.shared.updateNotificationsSeen()
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load notifications. \(error.localizedDescription)"
        }
    }

    private func loadMore() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await ATProtocolClient.shared.listNotifications(cursor: cursor)
            let existingURIs = Set(notifications.map { $0.uri })
            let newOnes = resp.notifications.filter { !existingURIs.contains($0.uri) }
            notifications.append(contentsOf: newOnes)
            cursor = resp.cursor
            var newGroups = buildGroups(from: notifications)
            await enrichGroupsWithSubjectText(&newGroups)
            groups = newGroups
        } catch {
            errorMessage = "Couldn't load more notifications. \(error.localizedDescription)"
        }
    }

    private func markAllRead() {
        Haptics.success()
        notifications = notifications.map { var n = $0; n.isRead = true; return n }
        groups = groups.map { g in
            var updated = g
            updated = NotificationGroup(
                id: g.id,
                notifications: g.notifications.map { var n = $0; n.isRead = true; return n },
                subjectText: g.subjectText
            )
            return updated
        }
        store.unreadNotificationCount = 0
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        Task { try? await ATProtocolClient.shared.updateNotificationsSeen() }
    }
}

// MARK: - Notification Group Row

struct NotificationGroupRowView: View {
    let group: NotificationGroup
    @Environment(AppStore.self) private var store

    private var notification: BskyNotification { group.primary }

    var accentColor: Color {
        switch notification.reason {
        case .like, .likeViaRepost: return .nbAccent
        case .repost, .repostViaRepost: return .nbLime
        case .follow, .starterpackJoined: return .nbBlue
        default: return .nbBlack
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar stack — show up to 3 avatars for grouped notifications
            avatarStack

            VStack(alignment: .leading, spacing: 4) {
                // Author names + reason
                authorLine

                // Subject post text (for likes/reposts) or reply text
                if let subjectText = group.subjectText, !subjectText.isEmpty {
                    Text(subjectText)
                        .font(.inter(13))
                        .foregroundStyle(Color.nbTextSecondary)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.nbBorder.opacity(0.2))
                } else if let text = notification.record?.text, !text.isEmpty {
                    Text(text)
                        .font(.inter(13))
                        .foregroundStyle(Color.nbTextSecondary)
                        .lineLimit(2)
                }

                let formatter = RelativeDateTimeFormatter()
                if let date = ISO8601DateFormatter().date(from: notification.indexedAt) {
                    Text(formatter.localizedString(for: date, relativeTo: Date()))
                        .font(.inter(12))
                        .foregroundStyle(Color.nbTextTertiary)
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
        .contentShape(Rectangle())
        .onTapGesture { navigate() }
    }

    @ViewBuilder
    private var avatarStack: some View {
        let avatars = group.notifications.prefix(3)
        ZStack(alignment: .bottomTrailing) {
            if avatars.count > 1 {
                // Stacked avatars
                ZStack(alignment: .topLeading) {
                    ForEach(Array(avatars.enumerated().reversed()), id: \.element.id) { idx, notif in
                        Button {
                            store.navigationPath.append(ProfileDestination(actor: notif.author.did))
                        } label: {
                            AvatarView(url: notif.author.avatar, size: 36)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("View \(notif.author.name)'s profile")
                        .offset(x: CGFloat(idx) * 10, y: CGFloat(idx) * 6)
                    }
                }
                .frame(width: 56, height: 50)
            } else {
                Button {
                    store.navigationPath.append(ProfileDestination(actor: notification.author.did))
                } label: {
                    AvatarView(url: notification.author.avatar, size: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(notification.author.name)'s profile")
            }

            Image(systemName: notification.reason.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(4)
                .background(accentColor)
                .clipShape(.circle)
                .offset(x: 4, y: 4)
        }
    }

    @ViewBuilder
    private var authorLine: some View {
        if group.isGrouped {
            Group {
                Text(notification.author.name)
                    .font(.inter(14, weight: .semibold))
                + Text(" and \(group.notifications.count - 1) others")
                    .font(.inter(14))
                + Text(" \(notification.reason.displayName)")
                    .font(.inter(14))
            }
            .foregroundStyle(Color.nbBlack)
        } else {
            Group {
                Text(notification.author.name)
                    .font(.inter(14, weight: .semibold))
                + Text(" \(notification.reason.displayName)")
                    .font(.inter(14))
            }
            .foregroundStyle(Color.nbBlack)
        }
    }

    private func navigate() {
        switch notification.reason {
        case .follow, .starterpackJoined:
            store.navigationPath.append(ProfileDestination(actor: notification.author.did))
        case .like, .repost, .likeViaRepost, .repostViaRepost:
            if let subject = notification.reasonSubject {
                store.navigationPath.append(PostDestination(uri: subject, post: nil))
            }
        case .reply, .mention, .quote:
            store.navigationPath.append(PostDestination(uri: notification.uri, post: nil))
        case .unknown:
            // Best-effort: try reasonSubject first, fall back to notification URI, then profile
            if let subject = notification.reasonSubject {
                store.navigationPath.append(PostDestination(uri: subject, post: nil))
            } else {
                store.navigationPath.append(PostDestination(uri: notification.uri, post: nil))
            }
        }
    }
}
