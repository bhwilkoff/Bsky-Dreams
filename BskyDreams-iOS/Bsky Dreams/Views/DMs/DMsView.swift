import SwiftUI

// MARK: - DMs List

struct DMsView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store
    @State private var conversations: [Conversation] = []
    @State private var isLoading = false
    @State private var loadError: String? = nil
    @State private var showNewConvo = false
    @State private var justCreatedConvo: Conversation? = nil
    @State private var actionError: String? = nil

    private var myDid: String { auth.session?.did ?? "" }

    var body: some View {
        Group {
            if isLoading && conversations.isEmpty {
                ProgressView("Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = loadError, conversations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.nbAccent)
                    Text(err)
                        .font(.inter(14))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") { Task { await loadConversations() } }
                        .nbButton()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if conversations.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    if let actionError {
                        NBErrorBanner(message: actionError, onDismiss: { self.actionError = nil })
                            .padding(.top, 8)
                    }
                    convoList
                }
            }
        }
        .nbNavBar(title: "MESSAGES", leading: { NBHamburger() }, trailing: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.nbAccent)
                .frame(width: 36, height: 36)
                .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                .contentShape(Rectangle())
                .onTapGesture { showNewConvo = true }
                .accessibilityLabel("New conversation")
                .accessibilityAddTraits(.isButton)
        })
        .task { await loadConversations() }
        .onChange(of: store.pendingDMConvoId) { _, convoId in
            guard let convoId else { return }
            store.pendingDMConvoId = nil
            if let convo = conversations.first(where: { $0.id == convoId }) {
                store.navigationPath.append(convo)
            }
        }
        .sheet(isPresented: $showNewConvo, onDismiss: {
            // Navigate after the sheet is fully dismissed to avoid presentation conflicts
            if let created = justCreatedConvo {
                store.navigationPath.append(created)
                justCreatedConvo = nil
            }
        }) {
            NewConversationView(myDid: myDid) { convo in
                if !conversations.contains(where: { $0.id == convo.id }) {
                    conversations.insert(convo, at: 0)
                }
                justCreatedConvo = convo
            }
        }
    }

    private var convoList: some View {
        List {
            ForEach(conversations) { convo in
                NavigationLink(value: convo) {
                    ConversationRowView(conversation: convo, myDid: myDid)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .contextMenu {
                    if convo.muted {
                        Button { Task { await toggleMute(convo: convo, mute: false) } } label: {
                            Label("Unmute", systemImage: "bell")
                        }
                    } else {
                        Button { Task { await toggleMute(convo: convo, mute: true) } } label: {
                            Label("Mute", systemImage: "bell.slash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
        .refreshable { await loadConversations() }
    }

    private var emptyState: some View {
        ScrollView {
            NBEmptyState(
                icon: "bubble.left.and.bubble.right",
                title: "NO MESSAGES YET",
                message: "Start a conversation with anyone on Bluesky",
                actionTitle: "Start New Conversation",
                action: { showNewConvo = true }
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        }
        .refreshable { await loadConversations() }
    }

    private func loadConversations() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let resp = try await ATProtocolClient.shared.listConversations()
            conversations = resp.convos
            // If a DM deep-link is pending and the convo is now loaded, open it
            if let convoId = store.pendingDMConvoId,
               let convo = conversations.first(where: { $0.id == convoId }) {
                store.pendingDMConvoId = nil
                store.navigationPath.append(convo)
            }
        } catch {
            if conversations.isEmpty {
                loadError = error.localizedDescription
            }
        }
    }

    private func toggleMute(convo: Conversation, mute: Bool) async {
        do {
            let resp = mute
                ? try await ATProtocolClient.shared.muteConvo(convoId: convo.id)
                : try await ATProtocolClient.shared.unmuteConvo(convoId: convo.id)
            if let idx = conversations.firstIndex(where: { $0.id == convo.id }) {
                conversations[idx] = resp.convo
            }
        } catch {
            actionError = mute ? "Couldn't mute conversation. Try again." : "Couldn't unmute conversation. Try again."
        }
    }
}

// MARK: - Conversation Row

struct ConversationRowView: View {
    let conversation: Conversation
    let myDid: String

    private var other: ActorProfile? { conversation.otherMembers(myDid: myDid).first }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(url: other?.avatar, size: 48)
                if conversation.muted {
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.nbWhite)
                        .padding(3)
                        .background(Color.nbBlack)
                        .clipShape(Circle())
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(other?.name ?? "Unknown")
                        .font(.inter(15, weight: conversation.unreadCount > 0 ? .semibold : .regular))
                        .foregroundStyle(Color.nbBlack)
                    Spacer()
                    if let sentAt = conversation.lastMessage?.sentAt {
                        Text(relativeTime(sentAt))
                            .font(.inter(12))
                            .foregroundStyle(Color.nbTextTertiary)
                    }
                }

                HStack {
                    if let lastMsg = conversation.lastMessage {
                        Text(lastMsg.isDeleted ? "Message deleted" : (lastMsg.text ?? ""))
                            .font(.inter(13))
                            .italic(lastMsg.isDeleted)
                            .foregroundStyle(lastMsg.isDeleted
                                ? Color.nbTextTertiary
                                : Color.nbTextSecondary)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                            .font(.inter(13))
                            .italic()
                            .foregroundStyle(Color.nbTextTertiary)
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
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Chat View

private let tapbackEmojis = ["❤️", "👍", "😂", "😮", "😢", "👎"]

struct ChatView: View {
    let conversation: Conversation
    let myDid: String
    var onLeave: (() -> Void)? = nil

    @State private var messages: [ChatMessage] = []   // oldest → newest
    @State private var cursor: String? = nil
    @State private var hasMoreMessages = false
    @State private var isLoadingMore = false
    @State private var messageText = ""
    @State private var isSending = false
    @State private var pollingTask: Task<Void, Never>?
    @State private var messageToDelete: ChatMessage? = nil
    @State private var showLeaveConfirm = false
    @State private var chatError: String? = nil
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var other: ActorProfile? { conversation.otherMembers(myDid: myDid).first }
    private var canSend: Bool { !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            if let chatError {
                NBErrorBanner(message: chatError, onDismiss: { self.chatError = nil })
                    .padding(.vertical, 6)
            }
            inputBar
        }
        .nbNavBar(
            title: other?.name ?? "Chat",
            leading: { NBBackButton() },
            trailing: {
                Menu {
                    Button(role: .destructive) { showLeaveConfirm = true } label: {
                        Label("Leave Conversation", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.nbBlack)
                        .frame(width: 36, height: 36)
                        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Conversation options")
            }
        )
        .task { await loadInitialMessages() }
        .onAppear { startPolling() }
        .onDisappear { pollingTask?.cancel() }
        .confirmationDialog("Leave Conversation?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { Task { await leaveConversation() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will no longer receive messages in this conversation.")
        }
        .confirmationDialog(
            "Delete Message?",
            isPresented: Binding(get: { messageToDelete != nil }, set: { if !$0 { messageToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete for Me", role: .destructive) {
                if let msg = messageToDelete { Task { await deleteMessage(msg) } }
            }
            Button("Cancel", role: .cancel) { messageToDelete = nil }
        } message: {
            Text("This message will only be removed from your view.")
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    // Load earlier
                    if hasMoreMessages {
                        Button {
                            Task { await loadMoreMessages(proxy: proxy) }
                        } label: {
                            if isLoadingMore {
                                ProgressView().frame(maxWidth: .infinity).padding()
                            } else {
                                Text("Load earlier messages")
                                    .font(.inter(13))
                                    .foregroundStyle(Color.nbBlue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(Array(messages.enumerated()), id: \.element.id) { item in
                        let idx = item.offset
                        let msg = item.element
                        let isOwn = msg.sender?.did == myDid
                        // Day separator when the calendar date changes
                        let prevSentAt = idx > 0 ? messages[idx - 1].sentAt : nil
                        if idx == 0 || !sameDay(prevSentAt, msg.sentAt) {
                            if let sentAt = msg.sentAt {
                                daySeparator(for: sentAt)
                                    .padding(.top, idx == 0 ? 0 : 8)
                            }
                        }
                        // Show avatar only on the last bubble in an incoming group
                        let nextSenderDid = idx < messages.count - 1 ? messages[idx + 1].sender?.did : nil
                        let lastInGroup = nextSenderDid != msg.sender?.did
                        MessageBubbleView(
                            message: msg,
                            isOwn: isOwn,
                            showAvatar: !isOwn && lastInGroup,
                            senderAvatarURL: other?.avatar
                        )
                        .id(msg.id)
                        .contextMenu {
                            // Tapback reactions — sent as quick emoji messages
                            if !msg.isDeleted {
                                ForEach(tapbackEmojis, id: \.self) { emoji in
                                    Button(emoji) { sendTapback(emoji) }
                                }
                            }
                            if isOwn && !msg.isDeleted {
                                Button(role: .destructive) {
                                    messageToDelete = msg
                                } label: {
                                    Label("Delete for Me", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Color.clear.frame(height: 1).id("chat-bottom")
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .onChange(of: messages.count) { old, new in
                guard new > old else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("chat-bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
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
                    .foregroundStyle(canSend ? Color.nbAccent : Color.nbBorder)
            }
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.nbWhite)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Date Helpers

    @ViewBuilder
    private func daySeparator(for iso: String) -> some View {
        if let date = ISO8601DateFormatter().date(from: iso) {
            Text(dayLabel(for: date))
                .font(.inter(11, weight: .semibold))
                .foregroundStyle(Color.nbTextTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    private func sameDay(_ a: String?, _ b: String?) -> Bool {
        guard let a, let b,
              let da = ISO8601DateFormatter().date(from: a),
              let db = ISO8601DateFormatter().date(from: b)
        else { return false }
        return Calendar.current.isDate(da, inSameDayAs: db)
    }

    private func dayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    // MARK: - Data Loading

    private func loadInitialMessages() async {
        do {
            let resp = try await ATProtocolClient.shared.getMessages(convoId: conversation.id)
            // API returns newest-first; reverse to oldest-first for display
            messages = Array(resp.messages.reversed())
            cursor = resp.cursor
            hasMoreMessages = cursor != nil
            chatError = nil
            // Mark as read using the newest message (first in API response)
            if let newestId = resp.messages.first?.id {
                try? await ATProtocolClient.shared.updateRead(
                    convoId: conversation.id,
                    messageId: newestId
                )
            }
        } catch {
            if messages.isEmpty {
                chatError = "Couldn't load messages. Pull to retry."
            }
        }
    }

    private func loadMoreMessages(proxy: ScrollViewProxy) async {
        guard hasMoreMessages, let cur = cursor, !isLoadingMore else { return }
        let anchorId = messages.first?.id   // scroll back here after prepend
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let resp = try await ATProtocolClient.shared.getMessages(convoId: conversation.id, cursor: cur)
            let older = Array(resp.messages.reversed())
            messages = older + messages
            cursor = resp.cursor
            hasMoreMessages = cursor != nil
            if let anchor = anchorId {
                DispatchQueue.main.async {
                    proxy.scrollTo(anchor, anchor: .top)
                }
            }
        } catch {
            chatError = "Couldn't load earlier messages. Try again."
        }
    }

    private func pollNewMessages() async {
        do {
            let resp = try await ATProtocolClient.shared.getMessages(convoId: conversation.id)
            let existingIds = Set(messages.map { $0.id })
            let incoming = Array(resp.messages.reversed()).filter { !existingIds.contains($0.id) }
            guard !incoming.isEmpty else { return }
            messages.append(contentsOf: incoming)
            if let newestId = resp.messages.first?.id {
                try? await ATProtocolClient.shared.updateRead(
                    convoId: conversation.id,
                    messageId: newestId
                )
            }
        } catch {
            // Background 30s poll — a transient failure is expected and will be
            // retried on the next tick. Don't interrupt the user with a banner here;
            // load/send/delete failures (which ARE surfaced) cover user-initiated actions.
        }
    }

    private func startPolling() {
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await pollNewMessages()
            }
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        // Resign focus first so iOS commits any pending IME/autocorrect state
        // before we clear the binding — without this, a focused multiline
        // TextField can visually restore its text after a programmatic clear.
        isInputFocused = false
        messageText = ""
        isSending = true

        let tempId = "sending-\(UUID().uuidString)"
        let optimistic = ChatMessage(
            messageId: tempId,
            rev: "",
            text: text,
            sender: ChatMessage.MessageSender(did: myDid),
            sentAt: ISO8601DateFormatter().string(from: Date()),
            facets: nil
        )
        messages.append(optimistic)

        Task {
            do {
                let confirmed = try await ATProtocolClient.shared.sendMessage(
                    convoId: conversation.id,
                    text: text
                )
                // Replace the optimistic placeholder with the server-confirmed message
                if let idx = messages.firstIndex(where: { $0.id == tempId }) {
                    messages[idx] = confirmed
                }
                chatError = nil
                Haptics.light()
            } catch {
                // Roll back: remove placeholder and restore typed text
                messages.removeAll { $0.id == tempId }
                messageText = text
                chatError = "Message failed to send. Try again."
                Haptics.error()
            }
            isSending = false
        }
    }

    private func deleteMessage(_ msg: ChatMessage) async {
        do {
            try await ATProtocolClient.shared.deleteMessageForSelf(
                convoId: conversation.id,
                messageId: msg.id
            )
            messages.removeAll { $0.id == msg.id }
        } catch {
            chatError = "Couldn't delete message. Try again."
        }
        messageToDelete = nil
    }

    private func leaveConversation() async {
        do {
            try await ATProtocolClient.shared.leaveConvo(convoId: conversation.id)
            onLeave?()
            dismiss()
        } catch {
            chatError = "Couldn't leave conversation. Try again."
        }
    }

    private func sendTapback(_ emoji: String) {
        let tempId = "sending-\(UUID().uuidString)"
        let optimistic = ChatMessage(
            messageId: tempId,
            rev: "",
            text: emoji,
            sender: ChatMessage.MessageSender(did: myDid),
            sentAt: ISO8601DateFormatter().string(from: Date()),
            facets: nil
        )
        messages.append(optimistic)
        Task {
            do {
                let confirmed = try await ATProtocolClient.shared.sendMessage(
                    convoId: conversation.id,
                    text: emoji
                )
                if let idx = messages.firstIndex(where: { $0.id == tempId }) {
                    messages[idx] = confirmed
                }
                Haptics.light()
            } catch {
                messages.removeAll { $0.id == tempId }
                chatError = "Reaction failed to send. Try again."
                Haptics.error()
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: ChatMessage
    let isOwn: Bool
    let showAvatar: Bool
    let senderAvatarURL: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            // Avatar placeholder column for incoming messages
            if !isOwn {
                if showAvatar {
                    AvatarView(url: senderAvatarURL, size: 28)
                } else {
                    Color.clear.frame(width: 28)
                }
            }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 3) {
                if message.isDeleted {
                    Text("Message deleted")
                        .font(.inter(14))
                        .italic()
                        .foregroundStyle(Color.nbTextTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.nbBorder.opacity(0.3))
                        .nbBorder()
                } else {
                    Text(message.text ?? "")
                        .font(.system(size: 15))    // system font for emoji fallback
                        .foregroundStyle(isOwn ? Color.white : Color.nbBlack)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isOwn ? Color.nbAccent : Color.nbMessageBubble)
                        .nbBorder()
                        .nbShadow(size: 2)
                }

                if message.messageId.hasPrefix("sending-") {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Sending...")
                            .font(.inter(10))
                            .foregroundStyle(Color.nbTextTertiary)
                    }
                } else if let sentAt = message.sentAt {
                    Text(timeLabel(sentAt))
                        .font(.inter(10))
                        .foregroundStyle(Color.nbTextTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
        }
        .padding(isOwn ? .leading : .trailing, 56)
        .padding(.vertical, 1)
    }

    private func timeLabel(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - New Conversation

struct NewConversationView: View {
    let myDid: String
    let onSelect: (Conversation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var actors: [ActorProfile] = []
    @State private var isSearching = false
    @State private var isStarting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NBTextField(
                    placeholder: "Search by handle...",
                    text: $searchQuery,
                    label: "Find People"
                )
                .padding(16)
                .onChange(of: searchQuery) { _, q in
                    errorMessage = nil
                    if q.count >= 2 { Task { await searchActors() } }
                    else { actors = [] }
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.inter(13))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                if isSearching || isStarting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    List(actors) { actor in
                        Button {
                            Task { await startConvo(with: actor) }
                        } label: {
                            HStack {
                                ActorRowView(actor: actor)
                                Spacer(minLength: 8)
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.nbAccent)
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .nbNavBar(title: "NEW MESSAGE", leading: { NBBackButton() })
        }
    }

    private func searchActors() async {
        isSearching = true
        defer { isSearching = false }
        do {
            let resp = try await ATProtocolClient.shared.searchActors(q: searchQuery)
            actors = resp.actors
        } catch {
            errorMessage = "Search failed. Try again."
        }
    }

    private func startConvo(with actor: ActorProfile) async {
        isStarting = true
        errorMessage = nil
        defer { isStarting = false }
        do {
            // Pass only the recipient's DID. The server infers the requester
            // from the Bearer token and adds them automatically. Passing myDid
            // explicitly causes a duplicate-member error on the server.
            let resp = try await ATProtocolClient.shared.getConvoForMembers(
                dids: [actor.did]
            )
            onSelect(resp.convo)
            dismiss()
        } catch {
            errorMessage = "Could not start conversation. Check that this account accepts messages and try again."
        }
    }
}
