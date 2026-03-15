import Foundation
import Observation

// MARK: - Global App State

@Observable
@MainActor
final class AppStore {
    // Navigation
    var selectedTab: AppTab = .feed
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

    // Compose state
    var composeText: String = ""
    var composeImages: [ComposeImage] = []
    var composeLinkEmbed: ExternalCard?
    var composeReplyTo: PostView?
    var composeQuote: PostView?
    var composeIsPosting = false

    // Notifications
    var notifications: [BskyNotification] = []
    var notificationCursor: String?

    // DMs
    var conversations: [Conversation] = []
    var activeConversation: Conversation?

    enum AppTab: String, CaseIterable {
        case feed, search, compose, notifications, dms, gallery, tv, reader, analytics, constellation
        var label: String {
            switch self {
            case .feed: "Feed"
            case .search: "Search"
            case .compose: "Compose"
            case .notifications: "Alerts"
            case .dms: "Messages"
            case .gallery: "Gallery"
            case .tv: "TV"
            case .reader: "Reader"
            case .analytics: "Analytics"
            case .constellation: "Network"
            }
        }
        var icon: String {
            switch self {
            case .feed: "house"
            case .search: "magnifyingglass"
            case .compose: "square.and.pencil"
            case .notifications: "bell"
            case .dms: "bubble.left.and.bubble.right"
            case .gallery: "photo.stack"
            case .tv: "play.tv"
            case .reader: "doc.text"
            case .analytics: "chart.bar"
            case .constellation: "network"
            }
        }
    }

    enum FeedMode: String, CaseIterable {
        case following = "Following"
        case discover = "Discover"
    }

    enum SearchMode: String, CaseIterable {
        case posts = "Posts"
        case people = "People"
    }
}

struct ComposeImage: Identifiable {
    var id = UUID()
    var imageData: Data
    var uiImage: UIImage? { UIImage(data: imageData) }
    var altText: String = ""
}
