import Foundation
import Observation
import SwiftUI
import UIKit
import Network

// MARK: - Global App State

@Observable
@MainActor
final class AppStore {
    // Navigation
    var selectedTab: AppTab? = .home
    var navigationPath = NavigationPath()

    // Unread badge
    var unreadNotificationCount: Int = 0
    var unreadDMCount: Int = 0

    // Feed state
    var feedMode: FeedMode = .discover
    var feedItems: [FeedItem] = []
    var feedCursor: String?
    var feedIsLoading = false
    var feedError: String?

    // Search state
    var searchQuery: String = ""
    var searchResults: [PostView] = []
    var searchActorResults: [ActorProfile] = []
    var searchCursor: String?
    var searchMode: SearchMode = .posts
    var searchIsLoading = false
    var pendingChannelQuery: String? = nil    // triggers channel search in SearchView
    var pendingTimelineQuery: String? = nil   // triggers timeline search in TimelineView
    var pendingAnalyticsActor: String? = nil  // pre-loads an actor when navigating to Analytics from a profile

    // Compose state (shared for sheet presentation)
    var composeText: String = ""
    var composeImages: [ComposeImage] = []
    var composeVideo: ComposeVideo? = nil
    var composeLinkEmbed: ExternalCard?
    var composeReplyTo: PostView?
    var composeQuote: PostView?
    var composeIsPosting = false
    var showComposeSheet = false

    // Notifications
    var notifications: [BskyNotification] = []
    var notificationCursor: String?

    // DMs
    var conversations: [Conversation] = []
    var activeConversation: Conversation?
    var pendingDMConvoId: String? = nil   // set by notification tap; DMsView opens on appear

    // Theme
    var accentColorHex: String = UserDefaults.standard.string(forKey: "nb_accent_color_hex") ?? "#0047FF"
    var accentColor: Color { Color(hex: accentColorHex) }

    /// Color scheme override: "system" (nil) | "light" | "dark"
    var colorSchemeOverride: String = UserDefaults.standard.string(forKey: "nb_color_scheme") ?? "system"

    var preferredColorScheme: ColorScheme? {
        switch colorSchemeOverride {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    func setColorScheme(_ mode: String) {
        colorSchemeOverride = mode
        UserDefaults.standard.set(mode, forKey: "nb_color_scheme")
    }

    // Current user profile
    var currentUserAvatar: String? = nil

    // Seen posts — bypass flag lets the user see already-seen posts for one session
    var feedSeenBypass = false
    private var seenSyncTask: Task<Void, Never>? = nil

    // MARK: - Discover moderation + personalization context

    /// The user's own Bluesky moderation settings (muted words, hidden labels, adult pref,
    /// subscribed labelers) — fetched once per session so Discover honors them.
    var moderationPrefs = ModerationPrefs()
    /// Topic hashtags drawn from the user's own posts — their declared interests.
    var interestTags: Set<String> = []
    /// True once preferences + interest model are loaded.
    var discoverContextReady = false
    /// How Discover ranks: Conversations (default), In Network, or Trending.
    var discoverRankMode: DiscoverRankMode =
        DiscoverRankMode(rawValue: UserDefaults.standard.string(forKey: "nb_discover_rank") ?? "") ?? .conversations

    func setDiscoverRankMode(_ mode: DiscoverRankMode) {
        discoverRankMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "nb_discover_rank")
    }

    /// Fetch the user's moderation preferences + build the interest model. Idempotent;
    /// safe to call on session start. Failures degrade gracefully (Discover still works,
    /// just with weaker personalization/moderation).
    func buildDiscoverContext(did: String) async {
        if let prefs = try? await ATProtocolClient.shared.getPreferences() {
            var m = ModerationPrefs()
            for p in prefs.preferences {
                switch p.type {
                case "app.bsky.actor.defs#adultContentPref":
                    m.adultEnabled = p.enabled ?? false
                case "app.bsky.actor.defs#contentLabelPref":
                    if p.visibility == "hide" || p.visibility == "warn", let l = p.label { m.hiddenLabels.insert(l) }
                case "app.bsky.actor.defs#mutedWordsPref":
                    m.mutedWords.append(contentsOf: (p.items ?? []).map { $0.value.lowercased() }.filter { !$0.isEmpty })
                case "app.bsky.actor.defs#labelersPref":
                    m.subscribedLabelers = (p.labelers ?? []).map { $0.did }
                default: break
                }
            }
            moderationPrefs = m
            ATProtocolClient.shared.setAcceptLabelers(m.subscribedLabelers)
        }
        // Interest tags from the user's own recent posts (what THEY choose to post about).
        if let mine = try? await ATProtocolClient.shared.getAuthorFeed(actor: did, limit: 60, filter: "posts_no_replies") {
            var tags = Set<String>()
            for item in mine.feed { tags.formUnion(DiscoverEngine.hashtags(in: item.post)) }
            interestTags = tags
        }
        discoverContextReady = true
    }

    // MARK: - Share Extension Handoff

    /// Read pending shared content from the App Group container and open the compose sheet.
    /// Checks UserDefaults directly — no flag needed. Safe to call on every foreground.
    func processPendingShare() {
        let appGroupID = "group.app.bskydreams.ios"
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let containerURL = FileManager.default.containerURL(
                  forSecurityApplicationGroupIdentifier: appGroupID) else { return }

        let imagePaths = defaults.stringArray(forKey: "pendingShare_imagePaths") ?? []
        let videoPaths = defaults.stringArray(forKey: "pendingShare_videoPaths") ?? []
        let urlStrings = defaults.stringArray(forKey: "pendingShare_urls") ?? []
        let sharedText = defaults.string(forKey: "pendingShare_text")

        // Nothing pending — bail out without touching compose state
        guard !imagePaths.isEmpty || !videoPaths.isEmpty || !urlStrings.isEmpty || sharedText != nil else { return }

        let shareDir = containerURL.appendingPathComponent("PendingShare", isDirectory: true)
        var loadedImages: [ComposeImage] = []
        for path in imagePaths.prefix(4) {
            let fileURL = shareDir.appendingPathComponent(path)
            if let data = try? Data(contentsOf: fileURL) {
                loadedImages.append(ComposeImage(imageData: data))
            }
        }

        var loadedVideo: ComposeVideo? = nil
        if let firstVideoPath = videoPaths.first {
            let fileURL = shareDir.appendingPathComponent(firstVideoPath)
            if let data = try? Data(contentsOf: fileURL) {
                let ext = firstVideoPath.components(separatedBy: ".").last?.lowercased() ?? "mp4"
                let mimeType = (ext == "mov") ? "video/quicktime" : "video/mp4"
                loadedVideo = ComposeVideo(videoData: data, mimeType: mimeType)
            }
        }

        var draft = ""
        if let urlString = urlStrings.first { draft = urlString }
        else if let t = sharedText { draft = t }

        // Clear so a second foreground doesn't re-open compose
        defaults.removeObject(forKey: "pendingShare_urls")
        defaults.removeObject(forKey: "pendingShare_text")
        defaults.removeObject(forKey: "pendingShare_imagePaths")
        defaults.removeObject(forKey: "pendingShare_videoPaths")

        self.composeText = draft
        self.composeImages = loadedImages
        self.composeVideo = loadedVideo
        self.showComposeSheet = true
    }

    /// Called when iOS opens the app as a document handler (CFBundleDocumentTypes).
    /// Reads the image or video file at the given URL and opens the compose sheet.
    func handleIncomingFile(_ url: URL) {
        // Security-scope the URL if needed (sandboxed file from another app)
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        let videoExts = ["mp4", "mov", "m4v", "avi"]

        if videoExts.contains(ext) {
            // Video — copy to a temp location the compose view can read
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try? FileManager.default.copyItem(at: url, to: dest)
            // Video compose support can be wired here; for now open compose with no attachment
            // so the user can still type text (video attach is handled separately in ComposeView)
            showComposeSheet = true
        } else {
            // Image — convert to JPEG data via UIImage so HEIC/TIFF/etc. all work
            guard let data = try? Data(contentsOf: url),
                  let uiImage = UIImage(data: data),
                  let jpeg = uiImage.jpegData(compressionQuality: 0.85) else {
                showComposeSheet = true
                return
            }
            composeImages = [ComposeImage(imageData: jpeg)]
            showComposeSheet = true
        }
    }

    func setAccentColor(_ hex: String) {
        accentColorHex = hex
        UserDefaults.standard.set(hex, forKey: "nb_accent_color_hex")
    }

    // MARK: - Seen Posts Cloud Sync

    /// Notification posted after cloud seen-posts merge completes.
    /// FeedView observes this to refresh its in-memory seenURISet.
    static let seenPostsMergedNotification = Notification.Name("BskyDreamsSeenPostsMerged")

    /// Debounces a seen-posts upload: cancels any pending sync and schedules a new
    /// one 30 seconds out. Pass the current list of URIs (7-day window).
    func scheduleSeenSync(uris: [String], did: String) {
        seenSyncTask?.cancel()
        let snapshot = uris
        seenSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, let self else { return }
            await self.saveSeenToCloud(uris: snapshot, did: did)
        }
    }

    /// Read-merge-write: fetch cloud record, union with local URIs, write merged result.
    /// This prevents one platform from overwriting the other's seen posts.
    func saveSeenToCloud(uris: [String], did: String) async {
        do {
            let cloudURIs = (try? await ATProtocolClient.shared.getSeenRecord(repo: did)) ?? []
            let merged = Array(Set(uris).union(cloudURIs))
            try await ATProtocolClient.shared.putSeenRecord(repo: did, uris: merged)
        } catch {}
    }

    /// Fetch the cloud seen-posts record and return the URI list for merging into SwiftData.
    func loadSeenFromCloud(did: String) async -> [String] {
        return (try? await ATProtocolClient.shared.getSeenRecord(repo: did)) ?? []
    }

    enum AppTab: String, CaseIterable {
        case home, search, notifications, dms, gallery, tv, stream, reader, analytics, constellation, timeline, settings
        var label: String {
            switch self {
            case .home: "Home"
            case .search: "Search"
            case .notifications: "Notifications"
            case .dms: "Messages"
            case .gallery: "Gallery"
            case .tv: "TV"
            case .stream: "Stream"
            case .reader: "Reader"
            case .analytics: "Analytics"
            case .constellation: "Constellation"
            case .timeline: "Timeline"
            case .settings: "Settings"
            }
        }
        var icon: String {
            switch self {
            case .home: "house"
            case .search: "magnifyingglass"
            case .notifications: "bell"
            case .dms: "bubble.left.and.bubble.right"
            case .gallery: "photo.stack"
            case .tv: "iphone"
            case .stream: "play.rectangle"
            case .reader: "doc.text"
            case .analytics: "chart.bar"
            case .constellation: "network"
            case .timeline: "calendar.day.timeline.leading"
            case .settings: "gearshape"
            }
        }
    }

    enum FeedMode: String, CaseIterable {
        case discover = "Discover"
        case following = "Following"
    }

    enum SearchMode: String, CaseIterable {
        case posts = "Posts"
        case people = "People"
    }
}

/// Navigation destination that pushes a fresh AnalyticsView pre-loaded for a specific actor.
/// Used by ProfileView's "ANALYTICS" button so the actor is injected at init time,
/// avoiding any `.task` / `.onChange` timing issues.
struct AnalyticsDestination: Hashable {
    let actor: String   // handle or DID
}

/// Navigation destination that pushes a fresh ConstellationView pre-seeded for a specific actor.
struct ConstellationDestination: Hashable {
    let actor: String   // handle
}

struct ComposeImage: Identifiable {
    var id = UUID()
    var imageData: Data
    var uiImage: UIImage? { UIImage(data: imageData) }
    var altText: String = ""

    /// Resize image data to stay within AT Protocol's 1 MB blob limit.
    /// Shared by ComposeView and InlineReplyView.
    static func resizeImageData(_ data: Data, maxBytes: Int = 950_000) -> Data {
        guard let image = UIImage(data: data) else { return data }

        // Step 1 — cap the long side at 2048px
        let maxDimension: CGFloat = 2048
        let imgScale = image.scale
        let pixelW = image.size.width * imgScale
        let pixelH = image.size.height * imgScale
        let longSide = max(pixelW, pixelH)

        let working: UIImage
        if longSide > maxDimension {
            let factor = maxDimension / longSide
            let newSize = CGSize(width: image.size.width * factor,
                                 height: image.size.height * factor)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            working = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            working = image
        }

        // Step 2 — quality sweep: start at 0.85, step down by 0.10
        var quality: CGFloat = 0.85
        while quality >= 0.05 {
            if let compressed = working.jpegData(compressionQuality: quality),
               compressed.count <= maxBytes {
                return compressed
            }
            quality -= 0.10
        }

        // Step 3 — shrink dimensions progressively
        var shrinkFactor: CGFloat = 0.70
        while shrinkFactor >= 0.25 {
            let newSize = CGSize(width: working.size.width * shrinkFactor,
                                 height: working.size.height * shrinkFactor)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let smaller = renderer.image { _ in working.draw(in: CGRect(origin: .zero, size: newSize)) }
            if let compressed = smaller.jpegData(compressionQuality: 0.75),
               compressed.count <= maxBytes {
                return compressed
            }
            shrinkFactor -= 0.15
        }

        return working.jpegData(compressionQuality: 0.4) ?? data
    }
}

struct ComposeVideo: Identifiable {
    var id = UUID()
    var videoData: Data
    var thumbnail: UIImage?
    var mimeType: String = "video/mp4"
    var altText: String = ""
}

// MARK: - Network reachability
//
// NOTE: this type lives here (not a standalone NetworkMonitor.swift) because the
// project uses Xcode file-system-synchronized groups, which intermittently fail to
// pick up brand-new .swift files even after a clean build. Co-locating new types in
// an already-compiled file is the reliable workaround (see DECISIONS.md).

/// Observable network-reachability monitor. Inject via `.environment` and read
/// `monitor.isOffline` to drive the offline banner and to distinguish a true
/// "no network" condition from a server-side error. Degrade, don't block:
/// cached content stays usable while offline.
@Observable
@MainActor
final class NetworkMonitor {
    /// True when the device has no usable network path. Starts `false` (optimistic)
    /// so the UI never flashes an offline banner before the first path update.
    private(set) var isOffline = false

    /// True when the active path is expensive (cellular) or constrained (Low Data Mode).
    private(set) var isConstrained = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.bskydreams.networkmonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            let constrained = path.isConstrained || path.isExpensive
            Task { @MainActor in
                self?.isOffline = offline
                self?.isConstrained = constrained
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}

// MARK: - Discover engine (moderation + conversation-weighted personalization)
//
// Inlined here (not a standalone file) because Xcode file-system-synchronized groups
// don't reliably pick up new .swift files (see DECISIONS.md). The Discover feed is
// rebuilt around three principles aligned with the app's purpose:
//   1. Honor the USER's own moderation (muted words, label visibility, blocks) — not a
//      hardcoded list.
//   2. Personalize from the user's OWN signals (their network + their topics), and tell
//      them WHY each post is shown — no opaque "for you" box.
//   3. Reward conversation (replies, questions) over raw virality; penalize reposts.

/// The user's moderation settings, fetched from app.bsky.actor.getPreferences.
struct ModerationPrefs {
    var adultEnabled = false           // does the user allow adult content at all?
    var hiddenLabels: Set<String> = [] // labels the user set to hide/warn
    var mutedWords: [String] = []      // lowercased
    var subscribedLabelers: [String] = []

    /// Adult/violent labels always hidden when the user has adult content disabled.
    static let adultLabels: Set<String> = [
        "porn", "sexual", "nudity", "graphic-media", "adult", "gore", "nsfw", "sexual-figurative"
    ]
}

/// How Discover ranks. The user can switch this; default is Conversations.
enum DiscoverRankMode: String, CaseIterable {
    case conversations = "Conversations"
    case network = "In Network"
    case trending = "Trending"
    var icon: String {
        switch self {
        case .conversations: "bubble.left.and.bubble.right"
        case .network: "person.2"
        case .trending: "flame"
        }
    }
}

enum DiscoverEngine {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(_ s: String) -> Date {
        iso.date(from: s) ?? isoNoFrac.date(from: s) ?? Date()
    }

    /// Hashtags for a post — from the structured `tags` field plus any `#word` in the text.
    static func hashtags(in post: PostView) -> Set<String> {
        var out = Set((post.record.tags ?? []).map { $0.lowercased() })
        let text = post.record.text
        var idx = text.startIndex
        while let hash = text[idx...].firstIndex(of: "#") {
            var end = text.index(after: hash)
            while end < text.endIndex, text[end].isLetter || text[end].isNumber || text[end] == "_" {
                end = text.index(after: end)
            }
            let tag = text[text.index(after: hash)..<end]
            if tag.count >= 2 { out.insert(tag.lowercased()) }
            idx = end < text.endIndex ? text.index(after: end) : text.endIndex
            if idx >= text.endIndex { break }
        }
        return out
    }

    /// Moderation gate: true = hide this post from Discover.
    static func shouldHide(_ item: FeedItem, prefs: ModerationPrefs) -> Bool {
        let post = item.post
        // Author muted/blocked (by you or them).
        if post.author.viewer?.isHidden == true { return true }
        // Post + author labels.
        let allLabels = (post.labels ?? []) + (post.author.labels ?? [])
        for lbl in allLabels where !(lbl.neg ?? false) {
            if prefs.hiddenLabels.contains(lbl.val) { return true }
            if !prefs.adultEnabled && ModerationPrefs.adultLabels.contains(lbl.val) { return true }
        }
        // Muted words (content + tags).
        if !prefs.mutedWords.isEmpty {
            let hay = (post.record.text + " " + (post.record.tags ?? []).joined(separator: " ")).lowercased()
            for w in prefs.mutedWords where hay.contains(w) { return true }
        }
        return false
    }

    /// Conversation-weighted, personalized score. Higher = ranked higher.
    static func score(_ item: FeedItem, mode: DiscoverRankMode, interestTags: Set<String>) -> Double {
        let post = item.post
        let likes = Double(post.likeCount ?? 0)
        let replies = Double(post.replyCount ?? 0)

        let hours = max(0, Date().timeIntervalSince(date(post.indexedAt)) / 3600)
        let recency = pow(hours + 2, 1.6)

        // Conversation: replies dominate; reply-to-like ratio rewards genuine discussion
        // over applause. Raw likes are intentionally de-emphasized.
        let replyRatio = replies / max(1, likes)
        var conversation = (replies * 3 + likes * 0.4) * (1 + min(replyRatio, 2))

        let isReply = post.record.reply != nil
        let isRepost = item.reason != nil
        if post.record.text.contains("?") && !isReply { conversation *= 1.25 }   // questions
        if isRepost { conversation *= 0.5 }                                       // penalize re-sharing
        else if !isReply { conversation *= 1.15 }                                 // reward originals

        // Network boost — your graph is the input, not a hidden model.
        var network = 1.0
        if post.author.viewer?.isFollowing == true { network += 1.2 }
        else if let kf = post.author.viewer?.knownFollowers?.count, kf > 0 {
            network += min(Double(kf) * 0.15, 0.9)
        }

        // Topic boost — overlap with the user's own hashtags.
        var topic = 1.0
        if !interestTags.isEmpty, !hashtags(in: post).isDisjoint(with: interestTags) { topic += 0.8 }

        switch mode {
        case .conversations: return (conversation / recency) * network * topic
        case .network:       return (conversation / recency) * pow(network, 2.0) * topic
        case .trending:      return ((likes + replies - 1) / recency) * topic
        }
    }

    /// A short, honest reason this post is in Discover — shown as a chip. nil = no chip.
    static func why(_ item: FeedItem, interestTags: Set<String>) -> String? {
        let post = item.post
        if let by = item.reason?.by?.name { return "Reposted by \(by)" }
        if post.author.viewer?.isFollowing == true { return "From someone you follow" }
        if let kf = post.author.viewer?.knownFollowers, kf.count > 0 {
            if let first = kf.followers.first?.name {
                return kf.count == 1 ? "Followed by \(first)" : "Followed by \(first) +\(kf.count - 1) you know"
            }
            return "Popular in your network"
        }
        if !interestTags.isEmpty, let m = hashtags(in: post).first(where: { interestTags.contains($0) }) {
            return "Matches your interest in #\(m)"
        }
        if let r = post.replyCount, r >= 5 { return "Active conversation · \(r) replies" }
        return nil
    }
}
