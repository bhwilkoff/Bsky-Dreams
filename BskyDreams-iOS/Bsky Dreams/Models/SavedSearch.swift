import Foundation
import SwiftData

@Model
final class SavedSearch {
    var id: String
    var name: String
    var query: String
    /// "search" (default) routes to SearchView; "timeline" routes to TimelineView.
    var channelType: String = "search"
    var createdAt: Date
    var lastSeenAt: Date?
    var unreadCount: Int

    init(id: String = UUID().uuidString, name: String, query: String, channelType: String = "search") {
        self.id = id
        self.name = name
        self.query = query
        self.channelType = channelType
        self.createdAt = Date()
        self.unreadCount = 0
    }
}

@Model
final class SeenPost {
    var uri: String
    var seenAt: Date
    var likeCount: Int
    var repostCount: Int

    init(uri: String, likeCount: Int = 0, repostCount: Int = 0) {
        self.uri = uri
        self.seenAt = Date()
        self.likeCount = likeCount
        self.repostCount = repostCount
    }
}

@Model
final class CachedPreferences {
    var accentColorHex: String
    var defaultFeedTab: String
    var hideAdultContent: Bool
    var lastSynced: Date?

    init() {
        self.accentColorHex = "#FF5C35"
        self.defaultFeedTab = "discover"
        self.hideAdultContent = false
    }
}
