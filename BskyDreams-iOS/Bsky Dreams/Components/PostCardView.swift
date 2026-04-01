import SwiftUI
import PhotosUI

// MARK: - Post Card — core reusable component

struct PostCardView: View {
    let post: PostView
    var depth: Int = 0
    var showParentPreview: Bool = true
    var suppressNavigation: Bool = false   // set true when this card IS the current thread root
    var onReply: ((PostView) -> Void)? = nil

    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store

    @State private var isLiked: Bool = false
    @State private var likeCount: Int = 0
    @State private var isReposted: Bool = false
    @State private var repostCount: Int = 0
    @State private var showRepostSheet = false
    @State private var showReportMenu = false
    @State private var showShareSheet = false
    @State private var showReportSheet = false
    @State private var showMuteConfirm = false
    @State private var showBlockConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isMuted = false
    @State private var isBlocked = false

    private var isOwnPost: Bool { post.author.did == auth.session?.did }

    // Depth colors — 8 cycling colors for nested thread replies
    private static let depthColors: [Color] = [
        Color(hex: "#FF5C35"), Color(hex: "#0047FF"), Color(hex: "#B8E04A"),
        Color(hex: "#FF9500"), Color(hex: "#AF52DE"), Color(hex: "#FF2D55"),
        Color(hex: "#5856D6"), Color(hex: "#34C759")
    ]
    private var depthAccent: Color { PostCardView.depthColors[depth % PostCardView.depthColors.count] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Parent preview for replies
            if showParentPreview, let parent = post.reply?.parent?.postView {
                ParentPreviewView(post: parent)
            }

            // Main card
            VStack(alignment: .leading, spacing: 10) {
                // Author header
                authorHeader

                // Post text
                if !post.record.text.isEmpty {
                    RichTextView(text: post.record.text, facets: post.record.facets)
                        .textSelection(.enabled)
                }

                // Embed
                if let embed = post.embed {
                    EmbedView(embed: embed)
                }

                // Action bar
                actionBar
            }
            .padding(12)
            .background(Color.nbWhite)
            .nbBorder()
            .nbShadow()
            .overlay(alignment: .leading) {
                if depth > 0 {
                    Rectangle()
                        .fill(depthAccent)
                        .frame(width: 3)
                }
            }
            .padding(.horizontal, CGFloat(depth) * 12)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !suppressNavigation else { return }
            store.navigationPath.append(PostDestination(uri: post.uri, post: post))
        }
        .confirmationDialog("Repost Options", isPresented: $showRepostSheet) {
            Button(isReposted ? "Undo Repost" : "Repost") { toggleRepost() }
            Button("Quote Post") {
                store.composeQuote = post
                store.showComposeSheet = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showShareSheet) {
            ShareOptionsView(post: post)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(
                title: "Report Post",
                onReport: { reason in
                    Task {
                        try? await ATProtocolClient.shared.reportPost(uri: post.uri, cid: post.cid, reason: reason)
                    }
                }
            )
        }
        .confirmationDialog("Mute @\(post.author.handle)?", isPresented: $showMuteConfirm, titleVisibility: .visible) {
            Button(isMuted ? "Unmute" : "Mute", role: isMuted ? .none : .destructive) { toggleMute() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isMuted ? "You will see their posts again." : "You won't see their posts in your feed.")
        }
        .confirmationDialog("Block @\(post.author.handle)?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("Block", role: .destructive) { performBlock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to interact with you.")
        }
        .confirmationDialog("Delete this post?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deletePost() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .onAppear {
            syncState()
            isMuted = post.author.viewer?.muted == true
            isBlocked = post.author.viewer?.blocked == true
        }
    }

    private var authorHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                store.navigationPath.append(ProfileDestination(actor: post.author.did))
            } label: {
                AvatarView(url: post.author.avatar, size: 40)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                // System font for author names — ensures emoji + full Unicode coverage
                Text(post.author.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.nbBlack)
                    .lineLimit(1)
                Text("@\(post.author.handle)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nbTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Tappable relative time — opens post in bsky.app
            Button {
                let urlStr = "https://bsky.app/profile/\(post.author.handle)/post/\(post.rkey)"
                if let url = URL(string: urlStr) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(post.relativeTime)
                    .font(.inter(11))
                    .foregroundStyle(Color.nbTextSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 28) {
            // Reply
            Button {
                onReply?(post)
            } label: {
                Label("\(post.replyCount ?? 0)", systemImage: "bubble.left")
                    .font(.inter(13))
                    .foregroundStyle(Color.nbTextSecondary)
            }
            .buttonStyle(NeubrutalistIconButtonStyle())

            // Repost
            Button { showRepostSheet = true } label: {
                Label("\(repostCount)", systemImage: "arrow.2.squarepath")
                    .font(.inter(13))
                    .foregroundStyle(isReposted ? Color.nbLime : Color.nbTextSecondary)
            }
            .buttonStyle(NeubrutalistIconButtonStyle())
            .sensoryFeedback(.impact(weight: .light), trigger: isReposted)

            // Like
            Button { toggleLike() } label: {
                Label("\(likeCount)", systemImage: isLiked ? "heart.fill" : "heart")
                    .font(.inter(13))
                    .foregroundStyle(isLiked ? Color.nbAccent : Color.nbTextSecondary)
            }
            .buttonStyle(NeubrutalistIconButtonStyle())
            .sensoryFeedback(.impact(weight: .medium), trigger: isLiked)

            Spacer()

            // "..." menu — share, open in Bluesky, and owner/other-specific actions
            Menu {
                Button { showShareSheet = true } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button {
                    let urlStr = "https://bsky.app/profile/\(post.author.handle)/post/\(post.rkey)"
                    if let url = URL(string: urlStr) { UIApplication.shared.open(url) }
                } label: {
                    Label("Open in Bluesky", systemImage: "arrow.up.right.square")
                }
                Divider()
                if isOwnPost {
                    Button("Delete Post", role: .destructive) { showDeleteConfirm = true }
                } else {
                    Button { showMuteConfirm = true } label: {
                        Label(isMuted ? "Unmute @\(post.author.handle)" : "Mute @\(post.author.handle)",
                              systemImage: isMuted ? "speaker.wave.2" : "speaker.slash")
                    }
                    Button(role: .destructive) { showBlockConfirm = true } label: {
                        Label("Block @\(post.author.handle)", systemImage: "person.slash")
                    }
                    Button("Report Post", role: .destructive) { showReportSheet = true }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nbTextTertiary)
                    .padding(4)
            }
        }
    }

    private func syncState() {
        isLiked = post.viewer?.like != nil
        likeCount = post.likeCount ?? 0
        isReposted = post.viewer?.repost != nil
        repostCount = post.repostCount ?? 0
    }

    private func toggleLike() {
        guard let did = auth.session?.did else { return }
        let wasLiked = isLiked
        let prevCount = likeCount

        // Optimistic update
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1

        Task {
            do {
                if wasLiked, let likeUri = post.viewer?.like {
                    try await ATProtocolClient.shared.unlikePost(likeUri: likeUri, did: did)
                } else {
                    _ = try await ATProtocolClient.shared.likePost(uri: post.uri, cid: post.cid, did: did)
                }
            } catch {
                // Rollback
                isLiked = wasLiked
                likeCount = prevCount
            }
        }
    }

    private func toggleMute() {
        let wasMuted = isMuted
        isMuted.toggle()
        Task {
            do {
                if wasMuted {
                    try await ATProtocolClient.shared.unmuteActor(actor: post.author.did)
                } else {
                    try await ATProtocolClient.shared.muteActor(actor: post.author.did)
                }
            } catch {
                isMuted = wasMuted
            }
        }
    }

    private func performBlock() {
        guard let myDid = auth.session?.did else { return }
        Task {
            do {
                _ = try await ATProtocolClient.shared.blockActor(did: post.author.did, myDid: myDid)
                isBlocked = true
            } catch {}
        }
    }

    private func deletePost() {
        guard let did = auth.session?.did else { return }
        Task {
            try? await ATProtocolClient.shared.deletePost(uri: post.uri, did: did)
        }
    }

    private func toggleRepost() {
        guard let did = auth.session?.did else { return }
        let wasReposted = isReposted
        let prevCount = repostCount

        isReposted.toggle()
        repostCount += isReposted ? 1 : -1

        Task {
            do {
                if wasReposted, let repostUri = post.viewer?.repost {
                    try await ATProtocolClient.shared.unrepost(repostUri: repostUri, did: did)
                } else {
                    _ = try await ATProtocolClient.shared.repost(uri: post.uri, cid: post.cid, did: did)
                }
            } catch {
                isReposted = wasReposted
                repostCount = prevCount
            }
        }
    }
}

// MARK: - Parent Preview

struct ParentPreviewView: View {
    let post: PostView

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(Color.nbBlue.opacity(0.3))
                .frame(width: 2)
                .padding(.leading, 19)

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(post.author.handle)")
                    .font(.inter(12, weight: .semibold))
                    .foregroundStyle(Color.nbBlue)
                Text(post.record.text)
                    .font(.inter(12))
                    .foregroundStyle(Color.nbTextSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .padding(.trailing, 12)
    }
}

// MARK: - Embed View

struct EmbedView: View {
    let embed: Embed

    var body: some View {
        switch embed {
        case .images(let imgs):
            ImageGridView(images: imgs.images)
        case .video(let vid):
            VideoThumbnailView(video: vid)
        case .external(let ext):
            if isGifExternalCard(ext.external), let gifURL = URL(string: ext.external.uri) {
                GifEmbedView(url: gifURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .nbBorder()
                    .onTapGesture {
                        UIApplication.shared.open(gifURL)
                    }
            } else if let ytID = youtubeVideoID(from: ext.external.uri) {
                YouTubeLinkCardView(videoID: ytID, card: ext.external)
            } else {
                LinkCardView(card: ext.external)
            }
        case .record(let rec):
            if case .post(let quoted) = rec.record {
                QuotedPostView(post: quoted)
            }
        case .recordWithMedia(let rwm):
            VStack(spacing: 8) {
                switch rwm.media {
                case .images(let imgs): ImageGridView(images: imgs.images)
                case .video(let vid): VideoThumbnailView(video: vid)
                case .external(let ext):
                    if isGifExternalCard(ext.external), let gifURL = URL(string: ext.external.uri) {
                        GifEmbedView(url: gifURL)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .nbBorder()
                    } else if let ytID = youtubeVideoID(from: ext.external.uri) {
                        YouTubeLinkCardView(videoID: ytID, card: ext.external)
                    } else {
                        LinkCardView(card: ext.external)
                    }
                case .unknown: EmptyView()
                }
                if case .post(let quoted) = rwm.record.record {
                    QuotedPostView(post: quoted)
                }
            }
        case .unknown:
            EmptyView()
        }
    }
}

// MARK: - Navigation Destinations

struct PostDestination: Hashable {
    let uri: String
    let post: PostView?

    init(uri: String, post: PostView? = nil) {
        self.uri = uri
        self.post = post
    }
}

struct ProfileDestination: Hashable {
    let actor: String
}

struct HashtagDestination: Hashable {
    let tag: String
}

// MARK: - Inline Reply Compose

/// Compact reply box that inserts directly below a post card — no modal sheet.
struct InlineReplyView: View {
    let replyTo: PostView
    let onDismiss: () -> Void

    @Environment(AuthManager.self) private var auth
    @Environment(AppStore.self) private var store
    @State private var text = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var images: [ComposeImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showGifPicker = false
    @State private var gifEmbed: ExternalCard? = nil
    @FocusState private var isFocused: Bool

    private var remaining: Int { 300 - text.count }
    private var canPost: Bool { (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty || gifEmbed != nil) && remaining >= 0 && !isPosting }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            replyHeader
            if !images.isEmpty { imagePreviewRow }
            inputRow
            mediaToolbar
            if let err = errorMessage {
                Text(err)
                    .font(.inter(11))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(Color.nbWhite)
        .nbBorder()
        .nbShadow()
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                isFocused = true
            }
        }
        .onChange(of: selectedItems) { _, items in
            Task { await loadImages(from: items) }
        }
        .sheet(isPresented: $showGifPicker) {
            GifPickerView { gifUrl, _ in
                gifEmbed = ExternalCard(uri: gifUrl, title: "GIF", description: "", thumb: nil)
                showGifPicker = false
            }
        }
    }

    private var replyHeader: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.nbAccent)
                .frame(width: 2, height: 16)
                .padding(.leading, 19)
            Text("Replying to @\(replyTo.author.handle)")
                .font(.inter(12))
                .foregroundStyle(Color.nbTextSecondary)
            Spacer()
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.nbTextTertiary)
                    .padding(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var imagePreviewRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(images) { img in
                    ZStack(alignment: .topTrailing) {
                        if let ui = img.uiImage {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipped()
                                .nbBorder()
                        }
                        Button { images.removeAll { $0.id == img.id } } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white)
                                .background(Color.nbBlack)
                                .clipShape(.circle)
                                .font(.system(size: 14))
                        }
                        .offset(x: 3, y: -3)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if auth.session?.handle != nil {
                AvatarView(url: store.currentUserAvatar, size: 30)
            }
            TextField("Write your reply…", text: $text, axis: .vertical)
                .font(.inter(14))
                .foregroundStyle(Color.nbBlack)
                .tint(Color.nbAccent)
                .lineLimit(1...4)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.nbBorder.opacity(0.15))
                .nbBorder(width: 1)
                .focused($isFocused)
            postButtonColumn
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var postButtonColumn: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if remaining < 50 {
                Text("\(remaining)")
                    .font(.inter(10))
                    .foregroundStyle(remaining < 0 ? .red : Color.nbTextSecondary)
            }
            Button(isPosting ? "…" : "POST") {
                Task { await submitReply() }
            }
            .buttonStyle(.plain)
            .font(.syne(12, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(canPost ? Color.nbAccent : Color.nbBorder)
            .nbBorder()
            .nbShadow(size: 2)
            .disabled(!canPost)
        }
    }

    private var mediaToolbar: some View {
        HStack(spacing: 14) {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 4 - images.count,
                matching: .images
            ) {
                Image(systemName: "photo")
                    .font(.system(size: 15))
                    .foregroundStyle(images.count >= 4 ? Color.nbBorder : Color.nbBlue)
            }
            .disabled(images.count >= 4)
            Button { showGifPicker = true } label: {
                Text("GIF")
                    .font(.syne(11, weight: .bold))
                    .foregroundStyle(Color.nbBlue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(Rectangle().strokeBorder(Color.nbBlue, lineWidth: 1.5))
            }
            Spacer()
            if isFocused {
                Button { isFocused = false } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.nbTextSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let resized = ComposeImage.resizeImageData(data)
                images.append(ComposeImage(imageData: resized))
            }
        }
        selectedItems = []
    }

    private func submitReply() async {
        guard let did = auth.session?.did else { return }
        isPosting = true
        errorMessage = nil
        do {
            // Upload images
            var uploadedBlobs: [UploadedBlob] = []
            var altTexts: [String] = []
            for img in images {
                let resp = try await ATProtocolClient.shared.uploadBlob(data: img.imageData, mimeType: "image/jpeg")
                uploadedBlobs.append(resp.blob)
                altTexts.append(img.altText)
            }

            let root = replyTo.record.reply?.root ?? StrongRef(uri: replyTo.uri, cid: replyTo.cid)
            let replyRef = PostReplyRef(
                root: root,
                parent: StrongRef(uri: replyTo.uri, cid: replyTo.cid)
            )
            _ = try await ATProtocolClient.shared.createPost(
                text: text,
                did: did,
                reply: replyRef,
                images: uploadedBlobs,
                imageAlts: altTexts,
                linkEmbed: uploadedBlobs.isEmpty ? gifEmbed : nil
            )
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            isPosting = false
        }
    }
}

// MARK: - Share Options (two link choices)

struct ShareOptionsView: View {
    let post: PostView
    @Environment(\.dismiss) private var dismiss
    @State private var showSystemShare = false
    @State private var shareURL: URL?

    private var bskyURL: String { "https://bsky.app/profile/\(post.author.handle)/post/\(post.rkey)" }
    private var dreamsURL: String {
        let encoded = post.uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? post.uri
        return "https://bskydreams.com/?view=post&uri=\(encoded)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Share Post")
                    .font(.syne(18, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)

                Divider().background(Color.nbBlack)

                VStack(spacing: 0) {
                    shareOption(
                        title: "Share Bluesky Link",
                        subtitle: "bsky.app — opens in Bluesky",
                        icon: "cloud",
                        url: bskyURL
                    )

                    Divider().background(Color.nbBorder)

                    shareOption(
                        title: "Share Bsky Dreams Link",
                        subtitle: "bskydreams.com — opens in app or web",
                        icon: "wand.and.stars",
                        url: dreamsURL
                    )
                }
                .padding(12)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showSystemShare) {
            if let url = shareURL {
                ShareSheet(activityItems: [url])
            }
        }
        .presentationDetents([.medium])
    }

    private func shareOption(title: String, subtitle: String, icon: String, url: String) -> some View {
        Button {
            shareURL = URL(string: url)
            showSystemShare = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.nbAccent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.inter(15, weight: .semibold))
                        .foregroundStyle(Color.nbBlack)
                    Text(subtitle)
                        .font(.inter(12))
                        .foregroundStyle(Color.nbTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.nbTextTertiary)
            }
            .padding(14)
            .background(Color.nbWhite)
            .nbBorder()
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

// MARK: - Report Sheet

struct ReportSheet: View {
    let title: String
    let onReport: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let reasons: [(label: String, value: String)] = [
        ("Spam", "com.atproto.moderation.defs#reasonSpam"),
        ("Misleading / Misinformation", "com.atproto.moderation.defs#reasonMisleading"),
        ("Harassment", "com.atproto.moderation.defs#reasonRude"),
        ("Sexual Content", "com.atproto.moderation.defs#reasonSexual"),
        ("Illegal", "com.atproto.moderation.defs#reasonIllegal"),
        ("Other", "com.atproto.moderation.defs#reasonOther"),
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Select a reason")
                    .font(.inter(13))
                    .foregroundStyle(Color.nbTextSecondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                ForEach(reasons, id: \.value) { reason in
                    Button {
                        onReport(reason.value)
                        dismiss()
                    } label: {
                        HStack {
                            Text(reason.label)
                                .font(.inter(15))
                                .foregroundStyle(Color.nbBlack)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.nbTextTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.nbWhite)
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.horizontal, 16)
                }

                Spacer()
            }
            .background(Color.nbBorder.opacity(0.1))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Share Sheet Wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
