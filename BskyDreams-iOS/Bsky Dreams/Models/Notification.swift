import Foundation

struct BskyNotification: Codable, Identifiable {
    var id: String { uri }
    let uri: String
    let cid: String
    let author: ActorProfile
    let reason: NotificationReason
    let reasonSubject: String?
    let record: NotificationRecord?
    var isRead: Bool
    let indexedAt: String

    enum NotificationReason: String, Codable {
        case like, repost, follow, mention, reply, quote
        // AT Protocol sends kebab-case reason strings
        case starterpackJoined = "starterpack-joined"
        // Engagement-via-repost reasons: fired when someone likes/reposts a post
        // that you originally reposted (your repost amplified the engagement).
        case likeViaRepost = "like-via-repost"
        case repostViaRepost = "repost-via-repost"
        case unknown

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            self = NotificationReason(rawValue: value) ?? .unknown
        }

        var displayName: String {
            switch self {
            case .like: "liked your post"
            case .repost: "reposted your post"
            case .follow: "followed you"
            case .mention: "mentioned you"
            case .reply: "replied to you"
            case .quote: "quoted your post"
            case .starterpackJoined: "joined via your starter pack"
            case .likeViaRepost: "liked a post you reposted"
            case .repostViaRepost: "reposted a post you reposted"
            case .unknown: "interacted with you"
            }
        }

        var icon: String {
            switch self {
            case .like: "heart.fill"
            case .repost: "arrow.2.squarepath"
            case .follow: "person.badge.plus"
            case .mention: "at"
            case .reply: "bubble.left.fill"
            case .quote: "quote.bubble.fill"
            case .starterpackJoined: "person.3.fill"
            case .likeViaRepost: "heart.fill"
            case .repostViaRepost: "arrow.2.squarepath"
            case .unknown: "bell.fill"
            }
        }
    }

    // Loose record — just extract what we need.
    // `subject` is intentionally omitted: its type varies (StrongRef for likes/reposts,
    // plain DID string for follows), causing decoding failures. Only `text` is used in UI.
    struct NotificationRecord: Codable {
        let text: String?
    }
}

struct NotificationsResponse: Codable {
    let notifications: [BskyNotification]
    let cursor: String?
    let seenAt: String?
}
