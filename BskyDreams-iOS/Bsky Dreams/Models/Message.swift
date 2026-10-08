import Foundation

// MARK: - Conversation
//
// A convo is either a 1:1 DM or a group (up to 50). `kind` is a `$type`-tagged union
// (#directConvo | #groupConvo); group name / member count / join link live inside the
// groupConvo arm. `members` is `chat.bsky.actor.defs#profileViewBasic` — same shape we
// already decode into ActorProfile (extra group fields like per-member role are ignored).

struct Conversation: Codable, Identifiable, Hashable {
    var id: String { convoId }
    let convoId: String
    let rev: String
    let members: [ActorProfile]
    let lastMessage: ChatMessage?
    let unreadCount: Int
    let muted: Bool
    let status: String?          // "request" | "accepted"
    let kind: ConvoKind?

    enum CodingKeys: String, CodingKey {
        case convoId = "id"
        case rev, members, lastMessage, unreadCount, muted, status, kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        convoId = try c.decode(String.self, forKey: .convoId)
        rev = (try? c.decode(String.self, forKey: .rev)) ?? ""
        members = (try? c.decode([ActorProfile].self, forKey: .members)) ?? []
        lastMessage = try? c.decodeIfPresent(ChatMessage.self, forKey: .lastMessage)
        unreadCount = (try? c.decode(Int.self, forKey: .unreadCount)) ?? 0
        muted = (try? c.decode(Bool.self, forKey: .muted)) ?? false
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        kind = try? c.decodeIfPresent(ConvoKind.self, forKey: .kind)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(convoId, forKey: .convoId)
        try c.encode(rev, forKey: .rev)
        try c.encode(members, forKey: .members)
        try c.encode(unreadCount, forKey: .unreadCount)
        try c.encode(muted, forKey: .muted)
    }

    var isGroup: Bool { kind?.isGroup ?? (members.count > 2) }
    var groupName: String? { kind?.name }
    var memberCount: Int { kind?.memberCount ?? members.count }
    var joinLink: JoinLinkView? { kind?.joinLink }
    var isRequest: Bool { status == "request" }

    func otherMembers(myDid: String) -> [ActorProfile] {
        members.filter { $0.did != myDid }
    }

    /// Title to show in the convo list / chat header.
    func title(myDid: String) -> String {
        if isGroup { return groupName ?? "Group" }
        return otherMembers(myDid: myDid).first?.name ?? "Conversation"
    }

    func hash(into hasher: inout Hasher) { hasher.combine(convoId) }
    static func == (lhs: Conversation, rhs: Conversation) -> Bool { lhs.convoId == rhs.convoId }
}

/// The `convoView.kind` union — only the group fields we render. Decode-only.
struct ConvoKind: Codable {
    let isGroup: Bool
    let name: String?
    let memberCount: Int?
    let memberLimit: Int?
    let joinLink: JoinLinkView?

    enum CodingKeys: String, CodingKey {
        case type = "$type", name, memberCount, memberLimit, joinLink
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = (try? c.decode(String.self, forKey: .type)) ?? ""
        isGroup = t.contains("groupConvo")
        name = try? c.decodeIfPresent(String.self, forKey: .name)
        memberCount = try? c.decodeIfPresent(Int.self, forKey: .memberCount)
        memberLimit = try? c.decodeIfPresent(Int.self, forKey: .memberLimit)
        joinLink = try? c.decodeIfPresent(JoinLinkView.self, forKey: .joinLink)
    }
    func encode(to encoder: Encoder) throws {}   // decode-only response model
}

struct JoinLinkView: Codable, Hashable {
    let code: String
    let enabledStatus: String?   // "enabled" | "disabled"
    let requireApproval: Bool?
    let joinRule: String?        // "anyone" | "followedByOwner"
    let createdAt: String?

    var isEnabled: Bool { enabledStatus == "enabled" }
    /// A shareable bsky.app URL for the join link.
    var shareURL: String { "https://bsky.app/messages/join/\(code)" }
}

// MARK: - Chat message
//
// In getMessages/getLog and convo.lastMessage, a message is a 3-way union:
//   #messageView         — has text, sender, optional reactions
//   #deletedMessageView  — sender + sentAt, no text/reactions
//   #systemMessageView   — `data` union (member added/joined/left, group renamed, …)
// We decode all three into one type and branch on `system`/`isDeleted`.

struct ChatMessage: Codable, Identifiable {
    var id: String { messageId }
    let messageId: String
    let rev: String
    let text: String?
    let sender: MessageSender?
    let sentAt: String?
    let facets: [RichTextFacet]?
    let reactions: [MessageReaction]?
    let system: SystemMessageData?

    enum CodingKeys: String, CodingKey {
        case messageId = "id"
        case rev, text, sender, sentAt, facets, reactions
        case data       // present on #systemMessageView
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try c.decode(String.self, forKey: .messageId)
        rev = (try? c.decode(String.self, forKey: .rev)) ?? ""
        text = try? c.decodeIfPresent(String.self, forKey: .text)
        sender = try? c.decodeIfPresent(MessageSender.self, forKey: .sender)
        sentAt = try? c.decodeIfPresent(String.self, forKey: .sentAt)
        facets = try? c.decodeIfPresent([RichTextFacet].self, forKey: .facets)
        reactions = try? c.decodeIfPresent([MessageReaction].self, forKey: .reactions)
        system = try? c.decodeIfPresent(SystemMessageData.self, forKey: .data)
    }

    /// Memberwise init for locally-built (optimistic) messages.
    init(messageId: String, rev: String, text: String?, sender: MessageSender?,
         sentAt: String?, facets: [RichTextFacet]?,
         reactions: [MessageReaction]? = nil, system: SystemMessageData? = nil) {
        self.messageId = messageId
        self.rev = rev
        self.text = text
        self.sender = sender
        self.sentAt = sentAt
        self.facets = facets
        self.reactions = reactions
        self.system = system
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(messageId, forKey: .messageId)
        try c.encode(rev, forKey: .rev)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(sender, forKey: .sender)
        try c.encodeIfPresent(sentAt, forKey: .sentAt)
    }

    var isSystem: Bool { system != nil }
    var isDeleted: Bool { !isSystem && (text == nil || sender == nil) }
    var displayText: String { text ?? "Message deleted" }

    struct MessageSender: Codable {
        let did: String
    }
}

/// A single 👍-style reaction on a message. `value` is one emoji grapheme.
struct MessageReaction: Codable, Hashable, Identifiable {
    let value: String
    let sender: ReactionSender
    let createdAt: String
    var id: String { "\(value)-\(sender.did)" }
    struct ReactionSender: Codable, Hashable { let did: String }
}

/// The `data` of a #systemMessageView. Referred users carry only a DID — hydrate
/// names from the convo's `members`. Decode-only.
struct SystemMessageData: Codable {
    let type: String                 // data $type, e.g. "...#systemMessageDataAddMember"
    let memberDid: String?
    let addedByDid: String?
    let removedByDid: String?
    let approvedByDid: String?
    let oldName: String?
    let newName: String?

    private struct Ref: Codable { let did: String }
    enum CodingKeys: String, CodingKey {
        case type = "$type", member, addedBy, removedBy, approvedBy, oldName, newName
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? c.decode(String.self, forKey: .type)) ?? ""
        memberDid = (try? c.decodeIfPresent(Ref.self, forKey: .member))?.did
        addedByDid = (try? c.decodeIfPresent(Ref.self, forKey: .addedBy))?.did
        removedByDid = (try? c.decodeIfPresent(Ref.self, forKey: .removedBy))?.did
        approvedByDid = (try? c.decodeIfPresent(Ref.self, forKey: .approvedBy))?.did
        oldName = try? c.decodeIfPresent(String.self, forKey: .oldName)
        newName = try? c.decodeIfPresent(String.self, forKey: .newName)
    }
    func encode(to encoder: Encoder) throws {}   // decode-only

    /// Render the event as a sentence, resolving DIDs to names via `nameFor`.
    func summary(nameFor: (String?) -> String) -> String {
        if type.hasSuffix("AddMember") { return "\(nameFor(addedByDid)) added \(nameFor(memberDid))" }
        if type.hasSuffix("RemoveMember") { return "\(nameFor(removedByDid)) removed \(nameFor(memberDid))" }
        if type.hasSuffix("MemberJoin") {
            if let by = approvedByDid { return "\(nameFor(memberDid)) joined · approved by \(nameFor(by))" }
            return "\(nameFor(memberDid)) joined"
        }
        if type.hasSuffix("MemberLeave") { return "\(nameFor(memberDid)) left" }
        if type.hasSuffix("EditGroup") {
            if let n = newName { return "Group renamed to “\(n)”" }
            return "Group updated"
        }
        if type.hasSuffix("CreateJoinLink") || type.hasSuffix("EnableJoinLink") { return "Invite link enabled" }
        if type.hasSuffix("DisableJoinLink") { return "Invite link disabled" }
        if type.contains("Lock") { return "Conversation locked" }
        return "Conversation updated"
    }
}

// MARK: - Owner's view of a pending join request (group)
struct JoinRequestView: Codable, Identifiable {
    let convoId: String
    let requestedBy: ActorProfile
    let requestedAt: String
    var id: String { requestedBy.did }
}

// MARK: - Response wrappers

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

/// `createGroup` / `addMembers` / `removeMembers` / `approveJoinRequest` all return `{ convo }`.
typealias GroupConvoResponse = ConvoResponse

struct ConvoRequestsResponse: Codable {
    let requests: [Conversation]   // incoming convo requests; outgoing join-request arms are skipped
    let cursor: String?

    enum CodingKeys: String, CodingKey { case requests, cursor }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cursor = try? c.decodeIfPresent(String.self, forKey: .cursor)
        // The array is a union of #convoView and #joinRequestConvoView. Decode each element
        // through a failable wrapper (always consumes exactly one element) and keep the
        // convoView arms; the joinRequestConvoView arms have no "id" and resolve to nil.
        let raw = (try? c.decode([FailableConvo].self, forKey: .requests)) ?? []
        requests = raw.compactMap { $0.convo }
    }
    func encode(to encoder: Encoder) throws {}
}

/// Always-succeeds wrapper so a heterogeneous union array advances reliably.
private struct FailableConvo: Codable {
    let convo: Conversation?
    init(from decoder: Decoder) throws { convo = try? Conversation(from: decoder) }
    func encode(to encoder: Encoder) throws {}
}

struct JoinRequestsResponse: Codable {
    let requests: [JoinRequestView]
    let cursor: String?
}

struct JoinLinkResponse: Codable {
    let joinLink: JoinLinkView
}

struct RequestJoinResponse: Codable {
    let status: String        // "joined" | "pending"
    let convo: Conversation?
}

struct ReactionMessageResponse: Codable {
    let message: ChatMessage
}

/// sendMessage's echoed message. Decodes BOTH shapes: `{ "message": <messageView> }`
/// and a bare `<messageView>` at the top level — group vs 1:1 responses have differed,
/// and either way the send already succeeded (HTTP 200) so we must not fail on the echo.
struct SendMessageResponse: Decodable {
    let message: ChatMessage
    enum CodingKeys: String, CodingKey { case message }
    init(from decoder: Decoder) throws {
        if let c = try? decoder.container(keyedBy: CodingKeys.self),
           let m = try? c.decode(ChatMessage.self, forKey: .message) {
            message = m
        } else {
            message = try ChatMessage(from: decoder)   // bare messageView
        }
    }
}
