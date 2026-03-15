import Foundation

extension ATProtocolClient {
    func listConversations(limit: Int = 20, cursor: String? = nil) async throws -> ConversationListResponse {
        var params: [String: String] = ["limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await get("chat.bsky.convo.listConvos", params: params, useChat: true)
    }

    func getMessages(convoId: String, limit: Int = 50, cursor: String? = nil) async throws -> MessagesResponse {
        var params: [String: String] = ["convoId": convoId, "limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await get("chat.bsky.convo.getMessages", params: params, useChat: true)
    }

    func sendMessage(convoId: String, text: String) async throws -> ChatMessage {
        struct Response: Codable { let message: ChatMessage }
        let resp: Response = try await post(
            "chat.bsky.convo.sendMessage",
            body: [
                "convoId": convoId,
                "message": ["$type": "chat.bsky.convo.defs#messageInput", "text": text]
            ] as [String: Any],
            useChat: true
        )
        return resp.message
    }

    func getConvoForMembers(dids: [String]) async throws -> ConvoResponse {
        return try await get(
            "chat.bsky.convo.getConvoForMembers",
            params: ["members": dids.joined(separator: ",")],
            useChat: true
        )
    }

    func updateRead(convoId: String, messageId: String) async throws {
        try await postVoid(
            "chat.bsky.convo.updateRead",
            body: ["convoId": convoId, "messageId": messageId],
            useChat: true
        )
    }
}
