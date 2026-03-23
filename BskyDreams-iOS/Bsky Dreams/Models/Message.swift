import Foundation

struct Conversation: Codable, Identifiable, Hashable {
    var id: String { convoId }
    let convoId: String
    let rev: String
    let members: [ActorProfile]
    let lastMessage: ChatMessage?
    let unreadCount: Int
    let muted: Bool

    // The AT Protocol wire format uses "id" for the conversation identifier,
    // but we store it as convoId to avoid collision with the Identifiable.id
    // computed property (Swift can't decode into a computed property).
    enum CodingKeys: String, CodingKey {
        case convoId = "id"
        case rev, members, lastMessage, unreadCount, muted
    }

    func otherMembers(myDid: String) -> [ActorProfile] {
        members.filter { $0.did != myDid }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(convoId) }
    static func == (lhs: Conversation, rhs: Conversation) -> Bool { lhs.convoId == rhs.convoId }
}

struct ChatMessage: Codable, Identifiable {
    var id: String { messageId }
    let messageId: String
    let rev: String
    // Optional to handle both #messageView (has text/sender/sentAt) and
    // #deletedMessageView (has none of these). Without optionals, a single
    // deleted last-message breaks decoding of the entire conversation list.
    let text: String?
    let sender: MessageSender?
    let sentAt: String?
    let facets: [RichTextFacet]?

    // Same wire-format issue as Conversation: the JSON field is "id".
    enum CodingKeys: String, CodingKey {
        case messageId = "id"
        case rev, text, sender, sentAt, facets
    }

    var isDeleted: Bool { text == nil || sender == nil }
    var displayText: String { text ?? "Message deleted" }

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
