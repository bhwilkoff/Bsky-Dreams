import Foundation

struct BskyNotification: Codable, Identifiable {
    var id: String { uri }
    let uri: String
    let cid: String
    let author: ActorProfile
    let reason: NotificationReason
    let reasonSubject: String?
    let record: NotificationRecord?
    let isRead: Bool
    let indexedAt: String

    enum NotificationReason: String, Codable {
        case like, repost, follow, mention, reply, quote
        case starterpackJoined
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
            case .unknown: "bell.fill"
            }
        }
    }

    // Loose record — just extract what we need
    struct NotificationRecord: Codable {
        let text: String?
        let subject: StrongRef?
    }
}

struct NotificationsResponse: Codable {
    let notifications: [BskyNotification]
    let cursor: String?
    let seenAt: String?
}
