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
    @State private var requests: [Conversation] = []
    @State private var showRequests = false

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
            } else if conversations.isEmpty && requests.isEmpty {
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
        .task { await loadRequests() }
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
        .sheet(isPresented: $showRequests) {
            RequestsInboxView(
                requests: requests,
                myDid: myDid,
                onAccept: { convo in
                    requests.removeAll { $0.id == convo.id }
                    await loadConversations()
                },
                onDecline: { convo in
                    requests.removeAll { $0.id == convo.id }
                }
            )
        }
    }

    private var convoList: some View {
        List {
            if !requests.isEmpty {
                Button { showRequests = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.nbAccent)
                            .frame(width: 48, height: 48)
                            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Requests")
                                .font(.inter(15, weight: .semibold))
                                .foregroundStyle(Color.nbBlack)
                            Text("\(requests.count) message \(requests.count == 1 ? "request" : "requests")")
                                .font(.inter(13))
                                .foregroundStyle(Color.nbTextSecondary)
                        }
                        Spacer()
                        Text("\(requests.count)")
                            .font(.inter(11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.nbAccent)
                            .clipShape(.capsule)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.nbTextTertiary)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

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

    private func loadRequests() async {
        do {
            let resp = try await ATProtocolClient.shared.listConvoRequests()
            requests = resp.requests
        } catch {
            // Non-critical secondary load; the main conversation list and its
            // error surface remain authoritative. Leave requests empty on failure.
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
    private var isGroup: Bool { conversation.isGroup }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if isGroup {
                    groupAvatarStack
                } else {
                    AvatarView(url: other?.avatar, size: 48)
                }
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
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(isGroup ? conversation.title(myDid: myDid) : (other?.name ?? "Unknown"))
                        .font(.inter(15, weight: conversation.unreadCount > 0 ? .semibold : .regular))
                        .foregroundStyle(Color.nbBlack)
                        .lineLimit(1)
                    Spacer()
                    if let sentAt = conversation.lastMessage?.sentAt {
                        Text(relativeTime(sentAt))
                            .font(.inter(12))
                            .foregroundStyle(Color.nbTextTertiary)
                    }
                }

                if isGroup {
                    Text("\(conversation.memberCount) members")
                        .font(.inter(11, weight: .semibold))
                        .foregroundStyle(Color.nbTextTertiary)
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

    /// Up to 3 overlapping member avatars for a group row.
    private var groupAvatarStack: some View {
        let avatars = conversation.otherMembers(myDid: myDid).prefix(3)
        return ZStack {
            ForEach(Array(avatars.enumerated()), id: \.element.did) { item in
                AvatarView(url: item.element.avatar, size: 30)
                    .overlay(Circle().strokeBorder(Color.nbWhite, lineWidth: 2))
                    .offset(
                        x: CGFloat(item.offset) * 9 - 9,
                        y: CGFloat(item.offset) * 7 - 7
                    )
            }
        }
        .frame(width: 48, height: 48)
    }

    private func relativeTime(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return "" }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Chat View

private let reactionEmojis = ["👍", "❤️", "😂", "😮", "😢", "🔥"]

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
    @State private var showGroupSheet = false
    // Mutable local copy of the convo so add/remove/invite-link updates (which return
    // `{ convo }`) reflect immediately in the header and group sheet.
    @State private var liveConvo: Conversation? = nil
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var convo: Conversation { liveConvo ?? conversation }
    private var isGroup: Bool { convo.isGroup }
    private var other: ActorProfile? { convo.otherMembers(myDid: myDid).first }
    private var canSend: Bool { !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending }

    /// Resolve a sender DID to a display name from the convo's members.
    private func nameFor(_ did: String?) -> String {
        guard let did else { return "someone" }
        if did == myDid { return "You" }
        return convo.members.first { $0.did == did }?.name ?? "someone"
    }

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
            title: isGroup ? (convo.groupName ?? "Group") : (other?.name ?? "Chat"),
            leading: { NBBackButton() },
            trailing: {
                if isGroup {
                    Image(systemName: "person.2")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.nbBlack)
                        .frame(width: 36, height: 36)
                        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                        .contentShape(Rectangle())
                        .onTapGesture { showGroupSheet = true }
                        .accessibilityLabel("Group details")
                        .accessibilityAddTraits(.isButton)
                } else {
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
            }
        )
        .task { await loadInitialMessages() }
        .onAppear { startPolling() }
        .onDisappear { pollingTask?.cancel() }
        .sheet(isPresented: $showGroupSheet) {
            GroupSheetView(
                convo: convo,
                myDid: myDid,
                onConvoUpdated: { updated in liveConvo = updated },
                onLeft: {
                    onLeave?()
                    dismiss()
                }
            )
        }
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

                        if msg.isSystem {
                            systemPill(msg)
                                .id(msg.id)
                        } else {
                            // Show avatar only on the last bubble in an incoming group
                            let nextSenderDid = idx < messages.count - 1 ? messages[idx + 1].sender?.did : nil
                            let lastInGroup = nextSenderDid != msg.sender?.did
                            VStack(alignment: isOwn ? .trailing : .leading, spacing: 2) {
                                MessageBubbleView(
                                    message: msg,
                                    isOwn: isOwn,
                                    showAvatar: !isOwn && lastInGroup,
                                    senderAvatarURL: senderAvatar(for: msg),
                                    senderName: isGroup && !isOwn && lastInGroup ? nameFor(msg.sender?.did) : nil
                                )
                                if let reactions = msg.reactions, !reactions.isEmpty, !msg.isDeleted {
                                    reactionPills(msg, reactions: reactions, isOwn: isOwn)
                                }
                            }
                            .id(msg.id)
                            .contextMenu {
                                // Emoji reactions on the message itself
                                if !msg.isDeleted {
                                    ForEach(reactionEmojis, id: \.self) { emoji in
                                        Button(emoji) { toggleReaction(msg, emoji) }
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

    // MARK: - System & Reaction Views

    /// A centered, muted pill describing a group event (member added, renamed, …).
    private func systemPill(_ msg: ChatMessage) -> some View {
        Text(msg.system?.summary(nameFor: { nameFor($0) }) ?? "Conversation updated")
            .font(.inter(11, weight: .semibold))
            .foregroundStyle(Color.nbTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.nbMessageBubble)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }

    /// Reactions grouped by emoji → pills showing emoji + count. Pills containing
    /// my own DID are highlighted, and tapping one toggles my reaction.
    private func reactionPills(_ msg: ChatMessage, reactions: [MessageReaction], isOwn: Bool) -> some View {
        // Preserve first-seen order of emoji values.
        var order: [String] = []
        var grouped: [String: [MessageReaction]] = [:]
        for r in reactions {
            if grouped[r.value] == nil { order.append(r.value) }
            grouped[r.value, default: []].append(r)
        }
        return HStack(spacing: 4) {
            ForEach(order, id: \.self) { value in
                let group = grouped[value] ?? []
                let mine = group.contains { $0.sender.did == myDid }
                Button {
                    toggleReaction(msg, value)
                } label: {
                    HStack(spacing: 3) {
                        Text(value).font(.system(size: 12))
                        Text("\(group.count)")
                            .font(.inter(11, weight: .bold))
                            .foregroundStyle(mine ? Color.nbWhite : Color.nbBlack)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(mine ? Color.nbAccent : Color.nbMessageBubble)
                    .overlay(Capsule().strokeBorder(Color.nbBlack, lineWidth: 1.5))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        // Align pills under the bubble: incoming bubbles have a ~34pt avatar gutter.
        .padding(.leading, isOwn ? 0 : 34)
        .padding(.bottom, 2)
    }

    /// Avatar URL for a message's sender (group convos resolve per-sender).
    private func senderAvatar(for msg: ChatMessage) -> String? {
        if isGroup {
            return convo.members.first { $0.did == msg.sender?.did }?.avatar
        }
        return other?.avatar
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
            } catch let apiErr as APIError {
                if case .responseUnreadable = apiErr {
                    // The server accepted the message (HTTP 200) but we couldn't parse the
                    // echoed message. The send SUCCEEDED — keep the optimistic bubble (the
                    // 30s poll reconciles it with the real message). Do NOT show a failure.
                    chatError = nil
                    Haptics.light()
                } else {
                    rollbackSend(tempId: tempId, text: text, error: apiErr)
                }
            } catch {
                rollbackSend(tempId: tempId, text: text, error: error)
            }
            isSending = false
        }
    }

    /// Remove the optimistic bubble, restore the typed text, and surface the real reason.
    private func rollbackSend(tempId: String, text: String, error: Error) {
        messages.removeAll { $0.id == tempId }
        messageText = text
        chatError = "Couldn't send: \(error.localizedDescription)"
        Haptics.error()
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

    /// Add my reaction, or remove it if I've already reacted with this emoji.
    /// Replaces the message in `messages` with the server-returned updated message.
    private func toggleReaction(_ msg: ChatMessage, _ emoji: String) {
        let alreadyMine = msg.reactions?.contains {
            $0.value == emoji && $0.sender.did == myDid
        } ?? false
        Haptics.light()
        Task {
            do {
                let updated = alreadyMine
                    ? try await ATProtocolClient.shared.removeReaction(
                        convoId: conversation.id, messageId: msg.id, value: emoji)
                    : try await ATProtocolClient.shared.addReaction(
                        convoId: conversation.id, messageId: msg.id, value: emoji)
                if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                    messages[idx] = updated
                }
                chatError = nil
            } catch {
                chatError = "Couldn't update reaction. Try again."
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
    var senderName: String? = nil

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
                // Sender name above the bubble in group chats.
                if let senderName {
                    Text(senderName)
                        .font(.inter(11, weight: .semibold))
                        .foregroundStyle(Color.nbTextSecondary)
                        .padding(.leading, 2)
                }
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
//
// Multi-select: pick one person → 1:1 (getConvoForMembers); pick 2+ → name the
// group → createGroup. Also supports joining an existing group via an invite link.

struct NewConversationView: View {
    let myDid: String
    let onSelect: (Conversation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var actors: [ActorProfile] = []
    @State private var selected: [ActorProfile] = []
    @State private var groupName = ""
    @State private var joinLinkText = ""
    @State private var isSearching = false
    @State private var isStarting = false
    @State private var isJoining = false
    @State private var joinStatus: String?
    @State private var errorMessage: String?

    private var isGroup: Bool { selected.count >= 2 }
    private var canStart: Bool {
        guard !isStarting else { return false }
        if selected.isEmpty { return false }
        if isGroup { return !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !selected.isEmpty { selectedChips }

                        if isGroup {
                            NBTextField(
                                placeholder: "Group name...",
                                text: $groupName,
                                label: "Group Name"
                            )
                        }

                        NBTextField(
                            placeholder: "Search by handle...",
                            text: $searchQuery,
                            label: "Find People"
                        )
                        .onChange(of: searchQuery) { _, q in
                            errorMessage = nil
                            if q.count >= 2 { Task { await searchActors() } }
                            else { actors = [] }
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.inter(13))
                                .foregroundStyle(.red)
                        }

                        if isSearching {
                            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
                        } else {
                            ForEach(actors) { actor in
                                actorRow(actor)
                            }
                        }

                        joinLinkSection
                            .padding(.top, 8)
                    }
                    .padding(16)
                }

                if !selected.isEmpty {
                    Button {
                        Task { await startOrCreate() }
                    } label: {
                        HStack(spacing: 8) {
                            if isStarting { ProgressView().tint(.white) }
                            Text(isGroup ? "Create Group" : "Start Conversation")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .nbButton()
                    .disabled(!canStart)
                    .opacity(canStart ? 1 : 0.5)
                    .padding(16)
                    .background(Color.nbWhite)
                    .overlay(alignment: .top) { Divider() }
                }
            }
            .nbNavBar(title: "NEW MESSAGE", leading: { NBBackButton() })
        }
    }

    private var selectedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selected) { actor in
                    HStack(spacing: 6) {
                        AvatarView(url: actor.avatar, size: 22)
                        Text(actor.name)
                            .font(.inter(13, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.nbTextSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.nbMessageBubble)
                    .nbBorder()
                    .contentShape(Rectangle())
                    .onTapGesture { selected.removeAll { $0.did == actor.did } }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func actorRow(_ actor: ActorProfile) -> some View {
        let isSelected = selected.contains { $0.did == actor.did }
        return Button {
            if isSelected {
                selected.removeAll { $0.did == actor.did }
            } else {
                selected.append(actor)
            }
        } label: {
            HStack {
                ActorRowView(actor: actor)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.nbAccent : Color.nbTextTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var joinLinkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("JOIN VIA INVITE LINK")
                .font(.syne(11, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.nbBlack)
            HStack(spacing: 8) {
                TextField("Paste link or code...", text: $joinLinkText)
                    .font(.inter(15))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Color.nbWhite)
                    .nbBorder()
                Button {
                    Task { await joinViaLink() }
                } label: {
                    if isJoining { ProgressView() }
                    else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.nbWhite)
                    }
                }
                .frame(width: 44, height: 44)
                .background(Color.nbAccent)
                .nbBorder()
                .disabled(joinLinkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isJoining)
                .opacity(joinLinkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            if let joinStatus {
                Text(joinStatus)
                    .font(.inter(13))
                    .foregroundStyle(Color.nbTextSecondary)
            }
        }
    }

    private func searchActors() async {
        isSearching = true
        defer { isSearching = false }
        do {
            let resp = try await ATProtocolClient.shared.searchActors(q: searchQuery)
            actors = resp.actors.filter { $0.did != myDid }
        } catch {
            errorMessage = "Search failed. Try again."
        }
    }

    private func startOrCreate() async {
        isStarting = true
        errorMessage = nil
        defer { isStarting = false }
        do {
            let convo: Conversation
            if isGroup {
                // The server adds the creator automatically — pass only the others.
                let resp = try await ATProtocolClient.shared.createGroup(
                    name: groupName.trimmingCharacters(in: .whitespacesAndNewlines),
                    memberDids: selected.map { $0.did }
                )
                convo = resp.convo
            } else {
                // 1:1 — pass only the recipient's DID; the server infers the requester.
                let resp = try await ATProtocolClient.shared.getConvoForMembers(
                    dids: [selected[0].did]
                )
                convo = resp.convo
            }
            onSelect(convo)
            dismiss()
        } catch {
            errorMessage = isGroup
                ? "Couldn't create the group. Try again."
                : "Could not start conversation. Check that this account accepts messages and try again."
        }
    }

    /// Extract a join code from a pasted bsky.app/messages/join/<code> URL or raw code.
    private func extractJoinCode(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.host != nil {
            // Last non-empty path component is the code.
            let comps = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            if let last = comps.last { return last }
        }
        return trimmed
    }

    private func joinViaLink() async {
        let code = extractJoinCode(joinLinkText)
        guard !code.isEmpty else { return }
        isJoining = true
        joinStatus = nil
        errorMessage = nil
        defer { isJoining = false }
        do {
            let resp = try await ATProtocolClient.shared.requestJoinGroup(code: code)
            if resp.status == "joined", let convo = resp.convo {
                onSelect(convo)
                dismiss()
            } else {
                joinStatus = "Request sent. You'll join once an admin approves."
                joinLinkText = ""
            }
        } catch {
            errorMessage = "Couldn't join with that link. Check the code and try again."
        }
    }
}

// MARK: - Requests Inbox

struct RequestsInboxView: View {
    let requests: [Conversation]
    let myDid: String
    let onAccept: (Conversation) async -> Void
    let onDecline: (Conversation) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localRequests: [Conversation] = []
    @State private var processingId: String? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if localRequests.isEmpty {
                    NBEmptyState(
                        icon: "tray",
                        title: "NO REQUESTS",
                        message: "Message requests from people you don't follow show up here."
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        if let errorMessage {
                            NBErrorBanner(message: errorMessage, onDismiss: { self.errorMessage = nil })
                                .padding(.top, 8)
                        }
                        List {
                            ForEach(localRequests) { convo in
                                requestRow(convo)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        .listStyle(.plain)
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .nbNavBar(title: "REQUESTS", leading: { NBBackButton() })
        }
        .onAppear { localRequests = requests }
    }

    private func requestRow(_ convo: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ConversationRowView(conversation: convo, myDid: myDid)
            HStack(spacing: 10) {
                Button {
                    Task { await accept(convo) }
                } label: {
                    Text("Accept").frame(maxWidth: .infinity)
                }
                .nbButton()
                .disabled(processingId == convo.id)

                Button {
                    Task { await decline(convo) }
                } label: {
                    Text("Decline")
                        .font(.syne(13, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color.nbBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.nbWhite)
                        .nbBorder()
                }
                .buttonStyle(.plain)
                .disabled(processingId == convo.id)
            }
        }
        .padding(.vertical, 4)
    }

    private func accept(_ convo: Conversation) async {
        processingId = convo.id
        defer { processingId = nil }
        do {
            try await ATProtocolClient.shared.acceptConvo(convoId: convo.id)
            localRequests.removeAll { $0.id == convo.id }
            await onAccept(convo)
            Haptics.light()
            if localRequests.isEmpty { dismiss() }
        } catch {
            errorMessage = "Couldn't accept this request. Try again."
        }
    }

    private func decline(_ convo: Conversation) async {
        processingId = convo.id
        defer { processingId = nil }
        do {
            try await ATProtocolClient.shared.leaveConvo(convoId: convo.id)
            localRequests.removeAll { $0.id == convo.id }
            await onDecline(convo)
            if localRequests.isEmpty { dismiss() }
        } catch {
            errorMessage = "Couldn't decline this request. Try again."
        }
    }
}

// MARK: - Group Sheet
//
// Members list, add/remove people, invite link, and leave. Add/remove return
// `{ convo }`; we push the updated convo back up via `onConvoUpdated` so the
// chat header and member list stay in sync without a refetch.

struct GroupSheetView: View {
    let convo: Conversation
    let myDid: String
    let onConvoUpdated: (Conversation) -> Void
    let onLeft: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var members: [ActorProfile] = []
    @State private var joinLink: JoinLinkView? = nil
    @State private var showAddPeople = false
    @State private var isCreatingLink = false
    @State private var showLeaveConfirm = false
    @State private var memberToRemove: ActorProfile? = nil
    @State private var errorMessage: String? = nil

    private var convoId: String { convo.id }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let errorMessage {
                    NBErrorBanner(message: errorMessage, onDismiss: { self.errorMessage = nil })
                        .padding(.top, 8)
                }
                List {
                    Section {
                        Button { showAddPeople = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.nbAccent)
                                    .frame(width: 36, height: 36)
                                    .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                                Text("Add People")
                                    .font(.inter(15, weight: .semibold))
                                    .foregroundStyle(Color.nbBlack)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } header: {
                        sectionHeader("\(members.count) MEMBERS")
                    }

                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            AvatarView(url: member.avatar, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.did == myDid ? "\(member.name) (You)" : member.name)
                                    .font(.inter(15, weight: .semibold))
                                    .foregroundStyle(Color.nbBlack)
                                Text("@\(member.handle)")
                                    .font(.inter(13))
                                    .foregroundStyle(Color.nbTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing) {
                            if member.did != myDid {
                                Button(role: .destructive) {
                                    memberToRemove = member
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
                            }
                        }
                    }

                    Section {
                        inviteLinkSection
                    } header: {
                        sectionHeader("INVITE LINK")
                    }

                    Section {
                        Button { showLeaveConfirm = true } label: {
                            Text("Leave Group")
                                .font(.syne(13, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.nbWhite)
                                .nbBorder()
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollIndicators(.hidden)
            }
            .nbNavBar(title: convo.groupName ?? "GROUP", leading: { NBBackButton() })
        }
        .onAppear {
            members = convo.members
            joinLink = convo.joinLink
        }
        .sheet(isPresented: $showAddPeople) {
            AddPeopleView(myDid: myDid, existingDids: Set(members.map { $0.did })) { dids in
                await addMembers(dids)
            }
        }
        .confirmationDialog(
            "Remove member?",
            isPresented: Binding(get: { memberToRemove != nil }, set: { if !$0 { memberToRemove = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let m = memberToRemove { Task { await removeMember(m) } }
            }
            Button("Cancel", role: .cancel) { memberToRemove = nil }
        } message: {
            Text("They will no longer be able to see or send messages in this group.")
        }
        .confirmationDialog("Leave Group?", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Leave", role: .destructive) { Task { await leaveGroup() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will no longer receive messages in this group.")
        }
    }

    @ViewBuilder
    private var inviteLinkSection: some View {
        if let link = joinLink, link.isEnabled {
            VStack(alignment: .leading, spacing: 10) {
                Text(link.shareURL)
                    .font(.inter(13))
                    .foregroundStyle(Color.nbBlue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.nbMessageBubble)
                    .nbBorder()
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = link.shareURL
                        Haptics.light()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.syne(13, weight: .bold))
                            .foregroundStyle(Color.nbBlack)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.nbWhite)
                            .nbBorder()
                    }
                    .buttonStyle(.plain)
                    if let url = URL(string: link.shareURL) {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.syne(13, weight: .bold))
                                .foregroundStyle(Color.nbWhite)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.nbAccent)
                                .nbBorder()
                        }
                    }
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            Button { Task { await createLink() } } label: {
                HStack(spacing: 8) {
                    if isCreatingLink { ProgressView().tint(.white) }
                    Text("Create Invite Link")
                }
                .frame(maxWidth: .infinity)
            }
            .nbButton()
            .disabled(isCreatingLink)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.syne(11, weight: .bold))
            .tracking(1)
            .foregroundStyle(Color.nbBlack)
            .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func addMembers(_ dids: [String]) async {
        guard !dids.isEmpty else { return }
        do {
            let resp = try await ATProtocolClient.shared.addGroupMembers(convoId: convoId, dids: dids)
            members = resp.convo.members
            joinLink = resp.convo.joinLink ?? joinLink
            onConvoUpdated(resp.convo)
            Haptics.light()
        } catch {
            errorMessage = "Couldn't add people. Try again."
        }
    }

    private func removeMember(_ member: ActorProfile) async {
        memberToRemove = nil
        do {
            let resp = try await ATProtocolClient.shared.removeGroupMembers(convoId: convoId, dids: [member.did])
            members = resp.convo.members
            onConvoUpdated(resp.convo)
        } catch {
            errorMessage = "Couldn't remove \(member.name). Try again."
        }
    }

    private func createLink() async {
        isCreatingLink = true
        defer { isCreatingLink = false }
        do {
            let resp = try await ATProtocolClient.shared.createJoinLink(convoId: convoId)
            joinLink = resp.joinLink
            Haptics.light()
        } catch {
            errorMessage = "Couldn't create an invite link. Try again."
        }
    }

    private func leaveGroup() async {
        do {
            try await ATProtocolClient.shared.leaveConvo(convoId: convoId)
            dismiss()
            onLeft()
        } catch {
            errorMessage = "Couldn't leave the group. Try again."
        }
    }
}

// MARK: - Add People (group member search)

struct AddPeopleView: View {
    let myDid: String
    let existingDids: Set<String>
    let onAdd: ([String]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var actors: [ActorProfile] = []
    @State private var selected: [ActorProfile] = []
    @State private var isSearching = false
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !selected.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selected) { actor in
                                        HStack(spacing: 6) {
                                            AvatarView(url: actor.avatar, size: 22)
                                            Text(actor.name)
                                                .font(.inter(13, weight: .semibold))
                                                .lineLimit(1)
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(Color.nbTextSecondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Color.nbMessageBubble)
                                        .nbBorder()
                                        .contentShape(Rectangle())
                                        .onTapGesture { selected.removeAll { $0.did == actor.did } }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }

                        NBTextField(
                            placeholder: "Search by handle...",
                            text: $searchQuery,
                            label: "Add People"
                        )
                        .onChange(of: searchQuery) { _, q in
                            errorMessage = nil
                            if q.count >= 2 { Task { await searchActors() } }
                            else { actors = [] }
                        }

                        if let err = errorMessage {
                            Text(err).font(.inter(13)).foregroundStyle(.red)
                        }

                        if isSearching {
                            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
                        } else {
                            ForEach(actors) { actor in
                                actorRow(actor)
                            }
                        }
                    }
                    .padding(16)
                }

                if !selected.isEmpty {
                    Button {
                        Task {
                            isAdding = true
                            await onAdd(selected.map { $0.did })
                            isAdding = false
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isAdding { ProgressView().tint(.white) }
                            Text("Add \(selected.count) to Group")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .nbButton()
                    .disabled(isAdding)
                    .padding(16)
                    .background(Color.nbWhite)
                    .overlay(alignment: .top) { Divider() }
                }
            }
            .nbNavBar(title: "ADD PEOPLE", leading: { NBBackButton() })
        }
    }

    private func actorRow(_ actor: ActorProfile) -> some View {
        let alreadyMember = existingDids.contains(actor.did)
        let isSelected = selected.contains { $0.did == actor.did }
        return Button {
            guard !alreadyMember else { return }
            if isSelected { selected.removeAll { $0.did == actor.did } }
            else { selected.append(actor) }
        } label: {
            HStack {
                ActorRowView(actor: actor)
                Spacer(minLength: 8)
                if alreadyMember {
                    Text("In group")
                        .font(.inter(11, weight: .semibold))
                        .foregroundStyle(Color.nbTextTertiary)
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Color.nbAccent : Color.nbTextTertiary)
                }
            }
            .contentShape(Rectangle())
            .opacity(alreadyMember ? 0.5 : 1)
        }
        .buttonStyle(.plain)
    }

    private func searchActors() async {
        isSearching = true
        defer { isSearching = false }
        do {
            let resp = try await ATProtocolClient.shared.searchActors(q: searchQuery)
            actors = resp.actors.filter { $0.did != myDid }
        } catch {
            errorMessage = "Search failed. Try again."
        }
    }
}
