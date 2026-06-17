import Foundation

struct ActorProfile: Codable, Identifiable, Hashable {
    var id: String { did }
    let did: String
    let handle: String
    let displayName: String?
    let avatar: String?
    let banner: String?
    let description: String?
    let followersCount: Int?
    let followsCount: Int?
    let postsCount: Int?
    let indexedAt: String?
    let viewer: ActorViewer?
    let labels: [BskyLabel]?

    var name: String { displayName ?? handle }

    static func == (lhs: ActorProfile, rhs: ActorProfile) -> Bool { lhs.did == rhs.did }
    func hash(into hasher: inout Hasher) { hasher.combine(did) }
}

struct ActorViewer: Codable {
    let muted: Bool?
    let blockedBy: Bool?        // true if THEY block you
    let blocking: String?       // AT URI of YOUR block record (present if you block them)
    let following: String?      // AT URI of follow record (present if you follow them)
    let followedBy: String?     // AT URI of their follow record
    let knownFollowers: KnownFollowers?

    /// You follow this account.
    var isFollowing: Bool { following != nil }
    /// You muted or blocked this account, or they block you — hide their posts in Discover.
    var isHidden: Bool { (muted ?? false) || (blocking != nil) || (blockedBy ?? false) }
}

struct KnownFollowers: Codable {
    let count: Int
    let followers: [ActorProfile]
}

// MARK: - Actor Search Result

struct ActorSearchResult: Codable {
    let actors: [ActorProfile]
    let cursor: String?
}
