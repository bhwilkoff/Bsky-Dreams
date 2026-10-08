import Foundation

// MARK: - Feed API

struct FeedResponse: Codable {
    let feed: [FeedItem]
    let cursor: String?
}

struct FeedItem: Codable, Identifiable {
    var id: String { post.uri }
    let post: PostView
    let reply: FeedReplyContext?
    let reason: RepostReason?

    struct RepostReason: Codable {
        let by: ActorProfile?
        let indexedAt: String?
    }
}

struct PostSearchResponse: Codable {
    let posts: [PostView]
    let cursor: String?
    let hitsTotal: Int?
}

extension ATProtocolClient {

    // MARK: - Timeline

    func getTimeline(limit: Int = 50, cursor: String? = nil) async throws -> FeedResponse {
        var params: [String: String] = ["limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await get("app.bsky.feed.getTimeline", params: params)
    }

    func getFeed(uri: String, limit: Int = 50, cursor: String? = nil) async throws -> FeedResponse {
        var params: [String: String] = ["feed": uri, "limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await get("app.bsky.feed.getFeed", params: params)
    }

    func getAuthorFeed(actor: String, limit: Int = 50, cursor: String? = nil, filter: String = "posts_no_replies") async throws -> FeedResponse {
        var params: [String: String] = ["actor": actor, "limit": "\(limit)", "filter": filter]
        if let cursor { params["cursor"] = cursor }
        return try await get("app.bsky.feed.getAuthorFeed", params: params)
    }

    func getPostThread(uri: String, depth: Int = 4) async throws -> ThreadResponse {
        return try await get("app.bsky.feed.getPostThread", params: ["uri": uri, "depth": "\(depth)"])
    }

    func searchPosts(
        q: String,
        sort: String = "latest",
        limit: Int = 25,
        cursor: String? = nil,
        author: String? = nil,
        since: String? = nil,
        until: String? = nil,
        lang: String? = nil,
        tag: String? = nil
    ) async throws -> PostSearchResponse {
        var params: [String: String] = ["q": q, "sort": sort, "limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        if let author { params["author"] = author }
        if let since { params["since"] = since }
        if let until { params["until"] = until }
        if let lang { params["lang"] = lang }
        if let tag { params["tag"] = tag }
        return try await get("app.bsky.feed.searchPosts", params: params)
    }

    func getPosts(uris: [String]) async throws -> [PostView] {
        guard !uris.isEmpty else { return [] }
        struct PostsResponse: Decodable { let posts: [PostView] }
        let items = uris.map { URLQueryItem(name: "uris", value: $0) }
        let resp: PostsResponse = try await get("app.bsky.feed.getPosts", queryItems: items)
        return resp.posts
    }

    // MARK: - Post Actions

    func likePost(uri: String, cid: String, did: String) async throws -> CreateRecordResponse {
        let record: [String: Any] = [
            "$type": "app.bsky.feed.like",
            "subject": ["uri": uri, "cid": cid],
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        let body: [String: Any] = ["repo": did, "collection": "app.bsky.feed.like", "record": record]
        return try await postDict("com.atproto.repo.createRecord", body: body)
    }

    func unlikePost(likeUri: String, did: String) async throws {
        let rkey = likeUri.components(separatedBy: "/").last ?? ""
        try await postVoid("com.atproto.repo.deleteRecord", body: [
            "repo": did,
            "collection": "app.bsky.feed.like",
            "rkey": rkey
        ])
    }

    func repost(uri: String, cid: String, did: String) async throws -> CreateRecordResponse {
        let record: [String: Any] = [
            "$type": "app.bsky.feed.repost",
            "subject": ["uri": uri, "cid": cid],
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        let body: [String: Any] = ["repo": did, "collection": "app.bsky.feed.repost", "record": record]
        return try await postDict("com.atproto.repo.createRecord", body: body)
    }

    /// Like (`on`) or unlike a post. Returns the like record URI to keep for the
    /// NEXT toggle — `post.viewer.like` is a load-time snapshot, so a post liked
    /// this session has no URI there and unliking it would like it again.
    func setLiked(_ on: Bool, post: PostView, recordURI: String?, did: String) async throws -> String? {
        if on { return try await likePost(uri: post.uri, cid: post.cid, did: did).uri }
        if let recordURI { try await unlikePost(likeUri: recordURI, did: did) }
        return nil
    }

    /// Repost counterpart of `setLiked` — same stale-snapshot reason.
    func setReposted(_ on: Bool, post: PostView, recordURI: String?, did: String) async throws -> String? {
        if on { return try await repost(uri: post.uri, cid: post.cid, did: did).uri }
        if let recordURI { try await unrepost(repostUri: recordURI, did: did) }
        return nil
    }

    /// AT Protocol rich-text facets for `text`, with UTF-8 BYTE offsets.
    /// Mirrors the official client's detection: links, `@handle.domain` mentions
    /// (skipped if the handle doesn't resolve), and `#tags` (trailing punctuation
    /// trimmed, no all-digit tags, ≤64 chars).
    func detectFacets(in text: String) async -> [[String: Any]] {
        let ns = text as NSString
        let whole = NSRange(location: 0, length: ns.length)
        func bytes(_ r: NSRange) -> (Int, Int) {
            let start = ns.substring(to: r.location).utf8.count
            return (start, start + ns.substring(with: r).utf8.count)
        }
        func facet(_ r: NSRange, _ feature: [String: Any]) -> [String: Any] {
            let (s, e) = bytes(r)
            return ["index": ["byteStart": s, "byteEnd": e], "features": [feature]]
        }
        var facets: [[String: Any]] = []

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for m in detector.matches(in: text, range: whole) {
                guard let url = m.url, url.scheme == "http" || url.scheme == "https" else { continue }
                facets.append(facet(m.range, ["$type": "app.bsky.richtext.facet#link", "uri": url.absoluteString]))
            }
        }

        if let re = try? NSRegularExpression(pattern: #"(?:^|[\s(])(@([a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+))"#) {
            for m in re.matches(in: text, range: whole) {
                var handle = ns.substring(with: m.range(at: 2))
                var range = m.range(at: 1)
                while handle.hasSuffix(".") || handle.hasSuffix("-") {   // "@ben.bsky.social." at sentence end
                    handle.removeLast(); range.length -= 1
                }
                guard let did = try? await resolveHandle(handle: handle) else { continue }
                facets.append(facet(range, ["$type": "app.bsky.richtext.facet#mention", "did": did]))
            }
        }

        if let re = try? NSRegularExpression(pattern: #"(?:^|\s)([#＃]([^\s#＃]+))"#) {
            for m in re.matches(in: text, range: whole) {
                var tag = ns.substring(with: m.range(at: 2))
                var range = m.range(at: 1)
                while let last = tag.unicodeScalars.last, CharacterSet.punctuationCharacters.contains(last) {
                    tag.unicodeScalars.removeLast(); range.length -= (String(last) as NSString).length
                }
                guard !tag.isEmpty, tag.count <= 64, !tag.allSatisfy(\.isNumber) else { continue }
                facets.append(facet(range, ["$type": "app.bsky.richtext.facet#tag", "tag": tag]))
            }
        }
        return facets
    }

    func unrepost(repostUri: String, did: String) async throws {
        let rkey = repostUri.components(separatedBy: "/").last ?? ""
        try await postVoid("com.atproto.repo.deleteRecord", body: [
            "repo": did,
            "collection": "app.bsky.feed.repost",
            "rkey": rkey
        ])
    }

    func createPost(
        text: String,
        did: String,
        reply: PostReplyRef? = nil,
        images: [UploadedBlob] = [],
        imageAlts: [String] = [],
        video: UploadedBlob? = nil,
        videoAlt: String = "",
        linkEmbed: ExternalCard? = nil,
        quoteUri: String? = nil,
        quoteCid: String? = nil,
        facets explicitFacets: [[String: Any]]? = nil
    ) async throws -> CreateRecordResponse {
        // Every compose surface gets links, @mentions (resolved to DIDs — without a
        // mention facet the person is NOT notified) and #hashtags for free.
        let facets: [[String: Any]]
        if let explicitFacets { facets = explicitFacets } else { facets = await detectFacets(in: text) }
        var record: [String: Any] = [
            "$type": "app.bsky.feed.post",
            "text": text,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "langs": ["en"]
        ]

        if !facets.isEmpty { record["facets"] = facets }

        if let reply {
            record["reply"] = [
                "root": ["uri": reply.root.uri, "cid": reply.root.cid],
                "parent": ["uri": reply.parent.uri, "cid": reply.parent.cid]
            ]
        }

        if !images.isEmpty {
            let imageObjects = zip(images, imageAlts).map { blob, alt -> [String: Any] in
                [
                    "alt": alt,
                    "image": [
                        "$type": "blob",
                        "ref": ["$link": blob.ref.link],
                        "mimeType": blob.mimeType ?? "image/jpeg",
                        "size": blob.size ?? 0
                    ] as [String: Any]
                ]
            }
            record["embed"] = [
                "$type": "app.bsky.embed.images",
                "images": imageObjects
            ]
        } else if let videoBlob = video {
            record["embed"] = [
                "$type": "app.bsky.embed.video",
                "video": [
                    "$type": "blob",
                    "ref": ["$link": videoBlob.ref.link],
                    "mimeType": videoBlob.mimeType ?? "video/mp4",
                    "size": videoBlob.size ?? 0
                ] as [String: Any],
                "alt": videoAlt
            ]
        } else if let link = linkEmbed {
            var external: [String: Any] = [
                "uri": link.uri,
                "title": link.title,
                "description": link.description
            ]
            // Include thumb blob CID if one was uploaded
            if let thumbBlob = link.uploadedThumb {
                external["thumb"] = [
                    "$type": "blob",
                    "ref": ["$link": thumbBlob.ref.link],
                    "mimeType": thumbBlob.mimeType ?? "image/jpeg",
                    "size": thumbBlob.size ?? 0
                ] as [String: Any]
            }
            record["embed"] = [
                "$type": "app.bsky.embed.external",
                "external": external
            ]
        } else if let qUri = quoteUri, let qCid = quoteCid {
            record["embed"] = [
                "$type": "app.bsky.embed.record",
                "record": ["uri": qUri, "cid": qCid]
            ]
        }

        let body: [String: Any] = ["repo": did, "collection": "app.bsky.feed.post", "record": record]
        return try await postDict("com.atproto.repo.createRecord", body: body)
    }

    func deletePost(uri: String, did: String) async throws {
        let rkey = uri.components(separatedBy: "/").last ?? ""
        try await postVoid("com.atproto.repo.deleteRecord", body: [
            "repo": did,
            "collection": "app.bsky.feed.post",
            "rkey": rkey
        ])
    }

    // MARK: - Actor Preferences (moderation: muted words, label visibility, labelers)

    /// Fetch the signed-in user's private Bluesky preferences. Carries the SAME
    /// moderation settings the official app uses — muted words, per-label visibility,
    /// adult-content toggle, and subscribed labelers — so Bsky Dreams can honor them.
    func getPreferences() async throws -> PreferencesResponse {
        try await get("app.bsky.actor.getPreferences")
    }
}

// MARK: - Preferences models
//
// getPreferences returns a heterogeneous array discriminated by `$type`. We decode
// each entry leniently into one struct with all possible fields optional, then sort
// them out by type when building the ModerationPrefs.

struct PreferencesResponse: Codable {
    let preferences: [PreferenceItem]
}

struct PreferenceItem: Codable {
    let type: String
    // adultContentPref
    let enabled: Bool?
    // contentLabelPref
    let label: String?
    let labelerDid: String?
    let visibility: String?     // "ignore" | "show" | "warn" | "hide"
    // mutedWordsPref
    let items: [MutedWordItem]?
    // labelersPref
    let labelers: [LabelerPrefItem]?

    enum CodingKeys: String, CodingKey {
        case type = "$type", enabled, label, labelerDid, visibility, items, labelers
    }
}

struct MutedWordItem: Codable {
    let value: String
    let targets: [String]?      // ["content", "tag"]
    let expiresAt: String?
}

struct LabelerPrefItem: Codable {
    let did: String
}
