import SwiftUI

struct DMsView: View {
    @Environment(AuthManager.self) private var auth
    @State private var conversations: [Conversation] = []
    @State private var isLoading = false
    @State private var activeConvo: Conversation? = nil
    @State private var showNewConvo = false

    var body: some View {
        NavigationSplitView {
            conversationList
        } detail: {
            if let convo = activeConvo {
                ChatView(conversation: convo, myDid: auth.session?.did ?? "")
            } else {
                ContentUnavailableView(
                    "Select a Conversation",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Choose a conversation from the list")
                )
            }
        }
        .task { await loadConversations() }
        .sheet(isPresented: $showNewConvo) {
            NewConversationView { convo in
                activeConvo = convo
                if !conversations.contains(where: { $0.id == convo.id }) {
                    conversations.insert(convo, at: 0)
                }
            }
        }
    }

    private var conversationList: some View {
        List(conversations, selection: $activeConvo) { convo in
            ConversationRowView(conversation: convo, myDid: auth.session?.did ?? "")
                .tag(convo)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showNewConvo = true }) {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(Color.nbAccent)
                }
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await loadConversations() }
    }

    private func loadConversations() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await ATProtocolClient.shared.listConversations()
            conversations = resp.convos
        } catch {}
    }
}

// MARK: - Conversation Row

struct ConversationRowView: View {
    let conversation: Conversation
    let myDid: String

    var other: ActorProfile? { conversation.otherMembers(myDid: myDid).first }

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: other?.avatar, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(other?.name ?? "Unknown")
                        .font(.inter(15, weight: conversation.unreadCount > 0 ? .semibold : .regular))
                    Spacer()
                    if let lastMsg = conversation.lastMessage {
                        Text(relativeTime(lastMsg.sentAt))
                            .font(.inter(12))
                            .foregroundStyle(Color.nbBlack.opacity(0.4))
                    }
                }

                HStack {
                    if let lastMsg = conversation.lastMessage {
                        Text(lastMsg.text)
                            .font(.inter(13))
                            .foregroundStyle(Color.nbBlack.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.inter(11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.nbAccent)
                            .clipShape(.capsule)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func relativeTime(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return "" }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Chat View

struct ChatView: View {
    let conversation: Conversation
    let myDid: String

    @State private var messages: [ChatMessage] = []
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var pollingTask: Task<Void, Never>?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(messages.reversed()) { msg in
                            MessageBubbleView(message: msg, isOwn: msg.sender.did == myDid)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: messages.count) { _, _ in
                    if let lastId = messages.first?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
            }

            // Input
            HStack(spacing: 8) {
                TextField("Message...", text: $messageText, axis: .vertical)
                    .font(.inter(15))
                    .lineLimit(5)
                    .focused($isInputFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.nbWhite)
                    .nbBorder()

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(messageText.isEmpty || isSending ? Color.nbBorder : Color.nbAccent)
                }
                .disabled(messageText.isEmpty || isSending)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.nbWhite)
            .overlay(alignment: .top) {
                Divider()
            }
        }
        .navigationTitle(conversation.otherMembers(myDid: myDid).first?.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMessages() }
        .onAppear { startPolling() }
        .onDisappear { pollingTask?.cancel() }
    }

    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await ATProtocolClient.shared.getMessages(convoId: conversation.id)
            messages = resp.messages
            // Mark as read
            if let lastMsg = messages.first {
                try? await ATProtocolClient.shared.updateRead(
                    convoId: conversation.id,
                    messageId: lastMsg.id
                )
            }
        } catch {}
    }

    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if !Task.isCancelled { await loadMessages() }
            }
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let text = messageText
        messageText = ""
        isSending = true

        Task {
            do {
                let msg = try await ATProtocolClient.shared.sendMessage(
                    convoId: conversation.id,
                    text: text
                )
                messages.insert(msg, at: 0)
            } catch {
                messageText = text // Restore on failure
            }
            isSending = false
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: ChatMessage
    let isOwn: Bool

    var body: some View {
        HStack {
            if isOwn { Spacer(minLength: 60) }

            Text(message.text)
                .font(.inter(15))
                .foregroundStyle(isOwn ? Color.nbBlack : Color.nbBlack)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isOwn ? Color.nbAccent : Color.nbBorder.opacity(0.4))
                .nbBorder()
                .nbShadow(size: 2)

            if !isOwn { Spacer(minLength: 60) }
        }
    }
}

// MARK: - New Conversation

struct NewConversationView: View {
    let onSelect: (Conversation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var actors: [ActorProfile] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack {
                NBTextField(
                    placeholder: "Search by handle...",
                    text: $searchQuery,
                    label: "Find People"
                )
                .padding(16)
                .onChange(of: searchQuery) { _, q in
                    if q.count >= 2 { Task { await searchActors() } }
                }

                List(actors) { actor in
                    Button(action: { startConvo(with: actor) }) {
                        ActorRowView(actor: actor)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)

                if isLoading { ProgressView() }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func searchActors() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await ATProtocolClient.shared.searchActors(q: searchQuery)
            actors = resp.actors
        } catch {}
    }

    private func startConvo(with actor: ActorProfile) {
        Task {
            do {
                let resp = try await ATProtocolClient.shared.getConvoForMembers(dids: [actor.did])
                onSelect(resp.convo)
                dismiss()
            } catch {}
        }
    }
}

// MARK: - Conversation Hashable for NavigationSplitView

extension Conversation: Hashable {
    static func == (lhs: Conversation, rhs: Conversation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(convoId) }
}
