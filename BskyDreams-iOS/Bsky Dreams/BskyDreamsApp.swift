import SwiftUI
import SwiftData
import BackgroundTasks
import UserNotifications

// MARK: - Notification Name

extension Notification.Name {
    static let bskyNotificationTapped = Notification.Name("bskyNotificationTapped")
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// Called when a notification is tapped while the app is in the background or not running.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Forward the full userInfo so ContentView can deep-link to the right destination
        let info = response.notification.request.content.userInfo
        NotificationCenter.default.post(name: .bskyNotificationTapped, object: nil, userInfo: info)
        completionHandler()
    }

    /// Called when a notification arrives while the app is in the foreground — show the banner.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    let notificationDelegate = NotificationDelegate()

    /// Set to true while StreamView is active so the system allows landscape orientations.
    static var streamingActive = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Clear badge when user opens the app
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.streamingActive ? .landscape : .portrait
    }
}

// MARK: - App

@main
struct BskyDreamsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authManager = AuthManager()
    @State private var appStore = AppStore()
    @State private var networkMonitor = NetworkMonitor()

    private static let bgTaskID = "com.bskydreams.app.notificationRefresh"

    /// Build the SwiftData container with graceful fallback so a corrupt or
    /// migration-failed store can never hard-crash the app at launch: try the
    /// on-disk store, then fall back to an in-memory store (the app still runs;
    /// local seen/saved data just won't persist this session).
    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([SeenPost.self, SavedSearch.self, CachedPreferences.self])
        do {
            return try ModelContainer(for: schema,
                                      configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: false))
        } catch {
            // Last resort: in-memory so the app always launches.
            return try! ModelContainer(for: schema,
                                       configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        }
    }

    init() {
        // Large disk cache so AsyncImage and URLSession responses persist across sessions
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024,   // 100 MB memory
            diskCapacity: 500 * 1024 * 1024        // 500 MB disk
        )
        // Register background refresh task for notification polling
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BskyDreamsApp.bgTaskID,
            using: nil
        ) { task in
            BskyDreamsApp.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
    }

    /// Schedule the next background notification check.
    /// iOS enforces a minimum interval (~15 min) regardless of earliestBeginDate,
    /// but setting it to 5 min signals higher urgency to the system scheduler.
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Background handler: fetch latest Bluesky notifications and deliver local notifications
    /// for unseen replies, likes, reposts, follows, and new DMs.
    static func handleBackgroundRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()  // Reschedule immediately so we keep running
        let bgTask = Task {
            await performNotificationCheck()
        }
        task.expirationHandler = { bgTask.cancel() }
        Task {
            await bgTask.value
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Delivered notification deduplication

    /// Key for the UserDefaults set of already-delivered notification IDs.
    private static let deliveredIDsKey = "bskydreams_delivered_notif_ids"

    /// Returns the set of IDs we have already delivered, capped at 500 entries.
    private static func loadDeliveredIDs() -> Set<String> {
        let arr = UserDefaults.standard.stringArray(forKey: deliveredIDsKey) ?? []
        return Set(arr)
    }

    /// Persists a set of delivered IDs, keeping only the newest 500.
    private static func saveDeliveredIDs(_ ids: Set<String>) {
        let trimmed = Array(ids).suffix(500)
        UserDefaults.standard.set(Array(trimmed), forKey: deliveredIDsKey)
    }

    // MARK: - Background notification check

    static func performNotificationCheck() async {
        // Retrieve session from Keychain for background use
        let keychain = KeychainManager()
        guard let session = keychain.loadSession(key: "bsky_session") else { return }
        let accessJwt = session.accessJwt

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        var deliveredIDs = loadDeliveredIDs()

        // ── 1. Social notifications ──────────────────────────────────────────────

        let notifURL = URL(string: "https://bsky.social/xrpc/app.bsky.notification.listNotifications?limit=20")!
        var notifReq = URLRequest(url: notifURL)
        notifReq.setValue("Bearer \(accessJwt)", forHTTPHeaderField: "Authorization")
        notifReq.timeoutInterval = 15

        if let (data, _) = try? await URLSession.shared.data(for: notifReq),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let notifications = json["notifications"] as? [[String: Any]] {

            let totalUnread = notifications.filter { ($0["isRead"] as? Bool) == false }.count

            for note in notifications.prefix(10) {
                guard let isRead = note["isRead"] as? Bool, !isRead,
                      let reason = note["reason"] as? String,
                      let uri = note["uri"] as? String,
                      let author = (note["author"] as? [String: Any])?["handle"] as? String
                else { continue }

                // Use the notification URI as a stable identifier to prevent duplicates
                let notifID = "notif-\(uri.suffix(40))"
                guard !deliveredIDs.contains(notifID) else { continue }

                let (title, body): (String, String)
                switch reason {
                case "like":            (title, body) = ("New like", "@\(author) liked your post")
                case "repost":          (title, body) = ("New repost", "@\(author) reposted your post")
                case "follow":          (title, body) = ("New follower", "@\(author) followed you")
                case "reply":           (title, body) = ("New reply", "@\(author) replied to your post")
                case "mention":         (title, body) = ("New mention", "@\(author) mentioned you")
                case "quote":           (title, body) = ("New quote", "@\(author) quoted your post")
                case "like-via-repost":   (title, body) = ("New like", "@\(author) liked a post you reposted")
                case "repost-via-repost": (title, body) = ("New repost", "@\(author) reposted a post you reposted")
                default: continue
                }

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                content.badge = NSNumber(value: totalUnread)
                content.userInfo = ["nav_type": "notifications"]

                let request = UNNotificationRequest(identifier: notifID, content: content, trigger: nil)
                try? await center.add(request)
                deliveredIDs.insert(notifID)
            }
        }

        // ── 2. DM notifications ──────────────────────────────────────────────────

        let dmURL = URL(string: "https://api.bsky.chat/xrpc/chat.bsky.convo.listConvos?limit=20")!
        var dmReq = URLRequest(url: dmURL)
        dmReq.setValue("Bearer \(accessJwt)", forHTTPHeaderField: "Authorization")
        dmReq.timeoutInterval = 15

        if let (dmData, _) = try? await URLSession.shared.data(for: dmReq),
           let dmJson = try? JSONSerialization.jsonObject(with: dmData) as? [String: Any],
           let convos = dmJson["convos"] as? [[String: Any]] {

            for convo in convos {
                guard let unread = convo["unreadCount"] as? Int, unread > 0,
                      let convoId = convo["id"] as? String,
                      let lastMsg = convo["lastMessage"] as? [String: Any],
                      let msgId = lastMsg["id"] as? String,
                      let sender = (lastMsg["sender"] as? [String: Any])?["did"] as? String,
                      sender != session.did   // don't notify for our own messages
                else { continue }

                let dmNotifID = "dm-\(convoId)-\(msgId)"
                guard !deliveredIDs.contains(dmNotifID) else { continue }

                // Resolve sender handle from the convo members list if available
                let senderHandle: String
                if let members = convo["members"] as? [[String: Any]],
                   let member = members.first(where: { ($0["did"] as? String) == sender }),
                   let handle = member["handle"] as? String {
                    senderHandle = "@\(handle)"
                } else {
                    senderHandle = "Someone"
                }

                let msgText = (lastMsg["text"] as? String) ?? "Sent you a message"
                let content = UNMutableNotificationContent()
                content.title = "\(senderHandle) messaged you"
                content.body = msgText.isEmpty ? "Sent you a message" : msgText
                content.sound = .default
                content.userInfo = ["nav_type": "dm", "convo_id": convoId]

                let request = UNNotificationRequest(identifier: dmNotifID, content: content, trigger: nil)
                try? await center.add(request)
                deliveredIDs.insert(dmNotifID)
            }
        }

        saveDeliveredIDs(deliveredIDs)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(appStore)
                .environment(networkMonitor)
                .preferredColorScheme(appStore.preferredColorScheme)
                .onOpenURL { url in
                    if url.scheme == "bskydreams", url.host == "share" {
                        appStore.processPendingShare()
                    } else if url.isFileURL {
                        appStore.handleIncomingFile(url)
                    }
                }
                .onAppear {
                    BskyDreamsApp.scheduleBackgroundRefresh()
                    // Request notification permission on first launch
                    Task {
                        let center = UNUserNotificationCenter.current()
                        let settings = await center.notificationSettings()
                        if settings.authorizationStatus == .notDetermined {
                            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
                        }
                    }
                }
        }
        .modelContainer(BskyDreamsApp.makeModelContainer())
    }
}
