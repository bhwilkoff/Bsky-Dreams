import Foundation

struct ATURI {
    let repo: String     // DID or handle
    let collection: String
    let rkey: String

    static func parse(_ uri: String) -> ATURI? {
        guard uri.hasPrefix("at://") else { return nil }
        let parts = uri.dropFirst(5).components(separatedBy: "/")
        guard parts.count >= 3 else { return nil }
        return ATURI(repo: parts[0], collection: parts[1], rkey: parts[2])
    }

    /// Convert bsky.app URL to AT URI
    static func fromBskyAppURL(_ url: URL) async -> ATURI? {
        // https://bsky.app/profile/{handle}/post/{rkey}
        let path = url.pathComponents
        guard path.count >= 5,
              path[1] == "profile",
              path[3] == "post" else { return nil }

        let handle = path[2]
        let rkey = path[4]

        // Resolve handle to DID
        do {
            let did = try await ATProtocolClient.shared.resolveHandle(handle: handle)
            return ATURI(
                repo: did,
                collection: "app.bsky.feed.post",
                rkey: rkey
            )
        } catch {
            return ATURI(
                repo: handle,
                collection: "app.bsky.feed.post",
                rkey: rkey
            )
        }
    }

    var atURI: String { "at://\(repo)/\(collection)/\(rkey)" }
}

// MARK: - Feed Generator URIs

enum FeedGenerator {
    static let whatsHot = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot"
    static let bskyTeam = "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/bsky-team"
}
