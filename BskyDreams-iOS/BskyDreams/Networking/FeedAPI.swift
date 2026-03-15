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
        let by: ActorProfile
        let indexedAt: String
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

    // MARK: - Post Actions

    func likePost(uri: String, cid: String, did: String) async throws -> CreateRecordResponse {
        let record: [String: Any] = [
            "$type": "app.bsky.feed.like",
            "subject": ["uri": uri, "cid": cid],
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        return try await post("com.atproto.repo.createRecord", body: [
            "repo": did,
            "collection": "app.bsky.feed.like",
            "record": record
        ] as [String: Any])
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
        return try await post("com.atproto.repo.createRecord", body: [
            "repo": did,
            "collection": "app.bsky.feed.repost",
            "record": record
        ] as [String: Any])
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
        images: [BlobRef] = [],
        imageAlts: [String] = [],
        linkEmbed: ExternalCard? = nil,
        quoteUri: String? = nil,
        quoteCid: String? = nil,
        facets: [[String: Any]] = []
    ) async throws -> CreateRecordResponse {
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
                        "ref": ["$link": blob.link],
                        "mimeType": "image/jpeg",
                        "size": 0
                    ] as [String: Any]
                ]
            }
            record["embed"] = [
                "$type": "app.bsky.embed.images",
                "images": imageObjects
            ]
        } else if let link = linkEmbed {
            record["embed"] = [
                "$type": "app.bsky.embed.external",
                "external": ["uri": link.uri, "title": link.title, "description": link.description]
            ]
        } else if let qUri = quoteUri, let qCid = quoteCid {
            record["embed"] = [
                "$type": "app.bsky.embed.record",
                "record": ["uri": qUri, "cid": qCid]
            ]
        }

        return try await post("com.atproto.repo.createRecord", body: [
            "repo": did,
            "collection": "app.bsky.feed.post",
            "record": record
        ] as [String: Any])
    }
}
