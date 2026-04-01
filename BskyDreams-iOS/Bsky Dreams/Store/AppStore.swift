import Foundation
import Observation
import SwiftUI
import UIKit

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

    /// Immediately upload seen-posts URIs to AT Protocol (e.g. on app background).
    func saveSeenToCloud(uris: [String], did: String) async {
        try? await ATProtocolClient.shared.putSeenRecord(repo: did, uris: uris)
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
