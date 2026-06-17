import Foundation

extension ATProtocolClient {

    // MARK: - Conversations

    func listConversations(limit: Int = 20, cursor: String? = nil) async throws -> ConversationListResponse {
        var params: [String: String] = ["limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await get("chat.bsky.convo.listConvos", params: params, useChat: true)
    }

    /// Create or retrieve the 1:1 conversation for the given member DIDs.
    /// IMPORTANT: `dids` must include BOTH the current user's DID and the
    /// recipient's DID. The AT Protocol endpoint also requires repeated query
    /// params (?members=did1&members=did2), not a comma-joined single value.
    func getConvoForMembers(dids: [String]) async throws -> ConvoResponse {
        let queryItems = dids.map { URLQueryItem(name: "members", value: $0) }
        return try await get(
            "chat.bsky.convo.getConvoForMembers",
            queryItems: queryItems,
            useChat: true
        )
    }

    func muteConvo(convoId: String) async throws -> ConvoResponse {
        struct Body: Encodable { let convoId: String }
        return try await post("chat.bsky.convo.muteConvo",
                              body: Body(convoId: convoId), useChat: true)
    }

    func unmuteConvo(convoId: String) async throws -> ConvoResponse {
        struct Body: Encodable { let convoId: String }
        return try await post("chat.bsky.convo.unmuteConvo",
                              body: Body(convoId: convoId), useChat: true)
    }

    func leaveConvo(convoId: String) async throws {
        struct Body: Encodable { let convoId: String }
        try await postVoid("chat.bsky.convo.leaveConvo",
                           body: Body(convoId: convoId), useChat: true)
    }

    // MARK: - Messages

    func getMessages(convoId: String, limit: Int = 50, cursor: String? = nil) async throws -> MessagesResponse {
        var params: [String: String] = ["convoId": convoId, "limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await get("chat.bsky.convo.getMessages", params: params, useChat: true)
    }

    func sendMessage(convoId: String, text: String) async throws -> ChatMessage {
        struct MessageInput: Encodable {
            let type: String = "chat.bsky.convo.defs#messageInput"
            let text: String
            enum CodingKeys: String, CodingKey { case type = "$type"; case text }
        }
        struct Body: Encodable { let convoId: String; let message: MessageInput }
        struct Response: Codable { let message: ChatMessage }
        let resp: Response = try await post(
            "chat.bsky.convo.sendMessage",
            body: Body(convoId: convoId, message: MessageInput(text: text)),
            useChat: true
        )
        return resp.message
    }

    func deleteMessageForSelf(convoId: String, messageId: String) async throws {
        struct Body: Encodable { let convoId: String; let messageId: String }
        try await postVoid("chat.bsky.convo.deleteMessageForSelf",
                           body: Body(convoId: convoId, messageId: messageId),
                           useChat: true)
    }

    func updateRead(convoId: String, messageId: String) async throws {
        struct Body: Encodable { let convoId: String; let messageId: String }
        try await postVoid("chat.bsky.convo.updateRead",
                           body: Body(convoId: convoId, messageId: messageId),
                           useChat: true)
    }

    // MARK: - Group conversations (chat.bsky.group.*)
    //
    // Same transport as 1:1 chat (api.bsky.chat via useChat:true, same access token).
    // Group lexicons were shipped June 2026 and are marked "unstable" upstream — re-verify
    // field names if the API changes. A convo is a group when convoView.kind is #groupConvo.

    /// Create a group. All invited members start as pending requests; you are accepted.
    func createGroup(name: String, memberDids: [String]) async throws -> GroupConvoResponse {
        struct Body: Encodable { let name: String; let members: [String] }
        return try await post("chat.bsky.group.createGroup",
                              body: Body(name: name, members: memberDids), useChat: true)
    }

    func addGroupMembers(convoId: String, dids: [String]) async throws -> GroupConvoResponse {
        struct Body: Encodable { let convoId: String; let members: [String] }
        return try await post("chat.bsky.group.addMembers",
                              body: Body(convoId: convoId, members: dids), useChat: true)
    }

    func removeGroupMembers(convoId: String, dids: [String]) async throws -> GroupConvoResponse {
        struct Body: Encodable { let convoId: String; let members: [String] }
        return try await post("chat.bsky.group.removeMembers",
                              body: Body(convoId: convoId, members: dids), useChat: true)
    }

    /// Owner: list pending join requests for a group.
    func listJoinRequests(convoId: String, cursor: String? = nil) async throws -> JoinRequestsResponse {
        var params = ["convoId": convoId, "limit": "50"]
        if let cursor { params["cursor"] = cursor }
        return try await get("chat.bsky.group.listJoinRequests", params: params, useChat: true)
    }

    func approveJoinRequest(convoId: String, memberDid: String) async throws -> GroupConvoResponse {
        struct Body: Encodable { let convoId: String; let member: String }
        return try await post("chat.bsky.group.approveJoinRequest",
                              body: Body(convoId: convoId, member: memberDid), useChat: true)
    }

    func rejectJoinRequest(convoId: String, memberDid: String) async throws {
        struct Body: Encodable { let convoId: String; let member: String }
        try await postVoid("chat.bsky.group.rejectJoinRequest",
                           body: Body(convoId: convoId, member: memberDid), useChat: true)
    }

    /// Join a group via an invite-link code. Returns "joined" (with convo) or "pending".
    func requestJoinGroup(code: String) async throws -> RequestJoinResponse {
        struct Body: Encodable { let code: String }
        return try await post("chat.bsky.group.requestJoin", body: Body(code: code), useChat: true)
    }

    /// Owner: create the group's invite link.
    func createJoinLink(convoId: String, joinRule: String = "anyone", requireApproval: Bool = false) async throws -> JoinLinkResponse {
        struct Body: Encodable { let convoId: String; let joinRule: String; let requireApproval: Bool }
        return try await post("chat.bsky.group.createJoinLink",
                              body: Body(convoId: convoId, joinRule: joinRule, requireApproval: requireApproval), useChat: true)
    }

    // MARK: - Convo requests + reactions (chat.bsky.convo.*)

    /// Incoming conversation/group requests awaiting your acceptance.
    func listConvoRequests(cursor: String? = nil) async throws -> ConvoRequestsResponse {
        var params = ["limit": "50"]
        if let cursor { params["cursor"] = cursor }
        return try await get("chat.bsky.convo.listConvoRequests", params: params, useChat: true)
    }

    /// Accept a pending conversation/group invite.
    func acceptConvo(convoId: String) async throws {
        struct Body: Encodable { let convoId: String }
        struct Resp: Decodable { let rev: String? }
        _ = try await post("chat.bsky.convo.acceptConvo", body: Body(convoId: convoId), useChat: true) as Resp
    }

    /// Add an emoji reaction to a message. `value` must be a single emoji grapheme.
    /// Returns the updated message (full reactions array) — use it to refresh state.
    func addReaction(convoId: String, messageId: String, value: String) async throws -> ChatMessage {
        struct Body: Encodable { let convoId: String; let messageId: String; let value: String }
        let resp: ReactionMessageResponse = try await post(
            "chat.bsky.convo.addReaction",
            body: Body(convoId: convoId, messageId: messageId, value: value), useChat: true)
        return resp.message
    }

    func removeReaction(convoId: String, messageId: String, value: String) async throws -> ChatMessage {
        struct Body: Encodable { let convoId: String; let messageId: String; let value: String }
        let resp: ReactionMessageResponse = try await post(
            "chat.bsky.convo.removeReaction",
            body: Body(convoId: convoId, messageId: messageId, value: value), useChat: true)
        return resp.message
    }
}
