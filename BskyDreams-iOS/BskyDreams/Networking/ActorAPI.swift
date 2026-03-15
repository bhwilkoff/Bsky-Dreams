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
        return try await post("com.atproto.repo.createRecord", body: [
            "repo": myDid,
            "collection": "app.bsky.graph.follow",
            "record": record
        ] as [String: Any])
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

    func resolveHandle(handle: String) async throws -> String {
        struct Response: Codable { let did: String }
        let resp: Response = try await get("com.atproto.identity.resolveHandle", params: ["handle": handle])
        return resp.did
    }
}
