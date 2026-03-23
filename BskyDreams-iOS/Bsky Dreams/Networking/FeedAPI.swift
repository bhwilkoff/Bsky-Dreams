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
}
