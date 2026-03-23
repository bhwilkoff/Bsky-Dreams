import Foundation

struct ActorProfileResponse: Codable {
    // getProfile returns ActorProfile directly
}

extension ATProtocolClient {
    func getProfile(actor: String) async throws -> ActorProfile {
        return try await get("app.bsky.actor.getProfile", params: ["actor": actor])
    }

    func searchActors(q: String, limit: Int = 8) async throws -> ActorSearchResult {
        return try await get("app.bsky.actor.searchActors", params: ["q": q, "limit": "\(limit)"])
    }

    func follow(did: String, myDid: String) async throws -> CreateRecordResponse {
        let record: [String: Any] = [
            "$type": "app.bsky.graph.follow",
            "subject": did,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        let body: [String: Any] = ["repo": myDid, "collection": "app.bsky.graph.follow", "record": record]
        return try await postDict("com.atproto.repo.createRecord", body: body)
    }

    func unfollow(followUri: String, myDid: String) async throws {
        let rkey = followUri.components(separatedBy: "/").last ?? ""
        try await postVoid("com.atproto.repo.deleteRecord", body: [
            "repo": myDid,
            "collection": "app.bsky.graph.follow",
            "rkey": rkey
        ])
    }

    func muteActor(actor: String) async throws {
        try await postVoid("app.bsky.graph.muteActor", body: ["actor": actor])
    }

    func unmuteActor(actor: String) async throws {
        try await postVoid("app.bsky.graph.unmuteActor", body: ["actor": actor])
    }

    func blockActor(did: String, myDid: String) async throws -> CreateRecordResponse {
        let record: [String: Any] = [
            "$type": "app.bsky.graph.block",
            "subject": did,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]
        let body: [String: Any] = ["repo": myDid, "collection": "app.bsky.graph.block", "record": record]
        return try await postDict("com.atproto.repo.createRecord", body: body)
    }

    func unblockActor(blockUri: String, myDid: String) async throws {
        let rkey = blockUri.components(separatedBy: "/").last ?? ""
        try await postVoid("com.atproto.repo.deleteRecord", body: [
            "repo": myDid,
            "collection": "app.bsky.graph.block",
            "rkey": rkey
        ])
    }

    func reportPost(uri: String, cid: String, reason: String) async throws {
        struct Subject: Encodable {
            let type: String = "com.atproto.repo.strongRef"
            let uri: String
            let cid: String
            enum CodingKeys: String, CodingKey { case type = "$type"; case uri; case cid }
        }
        struct Body: Encodable {
            let reasonType: String
            let reason: String
            let subject: Subject
        }
        let body = Body(
            reasonType: reason,
            reason: reason,
            subject: Subject(uri: uri, cid: cid)
        )
        struct R: Codable { let id: Int? }
        let _: R = try await post("com.atproto.moderation.createReport", body: body)
    }

    func reportAccount(did: String, reason: String) async throws {
        struct Subject: Encodable {
            let type: String = "com.atproto.admin.defs#repoRef"
            let did: String
            enum CodingKeys: String, CodingKey { case type = "$type"; case did }
        }
        struct Body: Encodable {
            let reasonType: String
            let reason: String
            let subject: Subject
        }
        let body = Body(reasonType: reason, reason: reason, subject: Subject(did: did))
        struct R: Codable { let id: Int? }
        let _: R = try await post("com.atproto.moderation.createReport", body: body)
    }

    func resolveHandle(handle: String) async throws -> String {
        struct Response: Codable { let did: String }
        let resp: Response = try await get("com.atproto.identity.resolveHandle", params: ["handle": handle])
        return resp.did
    }

    func getActorFollows(actor: String, limit: Int = 100) async throws -> [ActorProfile] {
        struct Response: Codable { let follows: [ActorProfile] }
        let resp: Response = try await get("app.bsky.graph.getFollows", params: ["actor": actor, "limit": "\(limit)"])
        return resp.follows
    }

    func getActorFollowers(actor: String, limit: Int = 100) async throws -> [ActorProfile] {
        struct Response: Codable { let followers: [ActorProfile] }
        let resp: Response = try await get("app.bsky.graph.getFollowers", params: ["actor": actor, "limit": "\(limit)"])
        return resp.followers
    }
}
