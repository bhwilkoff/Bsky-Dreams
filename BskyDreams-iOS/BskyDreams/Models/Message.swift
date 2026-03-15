import Foundation

struct Conversation: Codable, Identifiable {
    var id: String { convoId }
    let convoId: String
    let rev: String
    let members: [ActorProfile]
    let lastMessage: ChatMessage?
    let unreadCount: Int
    let muted: Bool

    func otherMembers(myDid: String) -> [ActorProfile] {
        members.filter { $0.did != myDid }
    }
}

struct ChatMessage: Codable, Identifiable {
    var id: String { messageId }
    let messageId: String
    let rev: String
    let text: String
    let sender: MessageSender
    let sentAt: String
    let facets: [RichTextFacet]?

    struct MessageSender: Codable {
        let did: String
    }
}

struct ConversationListResponse: Codable {
    let convos: [Conversation]
    let cursor: String?
}

struct MessagesResponse: Codable {
    let messages: [ChatMessage]
    let cursor: String?
}

struct ConvoResponse: Codable {
    let convo: Conversation
}
