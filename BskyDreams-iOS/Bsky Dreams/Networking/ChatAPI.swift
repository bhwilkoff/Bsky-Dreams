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
}
