import SwiftUI
import PhotosUI

struct ComposeView: View {
    var replyTo: PostView? = nil
    var quotePost: PostView? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var auth

    @State private var text = ""
    @State private var images: [ComposeImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var linkEmbed: ExternalCard? = nil
    @State private var linkURL = ""
    @State private var showLinkInput = false
    @State private var isPosting = false
    @State private var errorMessage: String?
    @State private var showAltTextSheet: ComposeImage? = nil

    private let maxLength = 300
    private var remaining: Int { maxLength - text.count }
    private var canPost: Bool { !text.isEmpty && remaining >= 0 && !isPosting }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Reply context
                    if let reply = replyTo {
                        replyContext(reply)
                    }

                    // Quote context
                    if let quote = quotePost {
                        QuotedPostView(post: quote)
                    }

                    // Text input
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("What's happening?")
                                .font(.inter(16))
                                .foregroundStyle(Color.nbBlack.opacity(0.3))
                                .padding(.top, 4)
                        }
                        TextEditor(text: $text)
                            .font(.inter(16))
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                    }
                    .padding(.horizontal, 4)

                    // Image grid preview
                    if !images.isEmpty {
                        imagePreview
                    }

                    // Link embed
                    if let link = linkEmbed {
                        linkPreviewCard(link)
                    } else if showLinkInput {
                        linkInputField
                    }

                    // Error
                    if let err = errorMessage {
                        Text(err)
                            .font(.inter(13))
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            .navigationTitle(replyTo != nil ? "Reply" : "New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.nbBlack)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        characterCounter
                        Button(action: post) {
                            Text(isPosting ? "Posting..." : "POST")
                                .font(.syne(14, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Color.nbBlack)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(canPost ? Color.nbAccent : Color.nbBorder)
                                .nbBorder()
                                .nbShadow(size: 3)
                                .offset(x: -2, y: -2)
                        }
                        .disabled(!canPost)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    composeToolbar
                }
            }
        }
        .onChange(of: selectedItems) { _, items in
            Task { await loadImages(from: items) }
        }
        .sheet(item: $showAltTextSheet) { img in
            AltTextSheet(image: img) { updatedImg in
                if let idx = images.firstIndex(where: { $0.id == updatedImg.id }) {
                    images[idx] = updatedImg
                }
            }
        }
    }

    private var characterCounter: some View {
        ZStack {
            Circle()
                .stroke(Color.nbBorder, lineWidth: 2)
                .frame(width: 28, height: 28)
            Circle()
                .trim(from: 0, to: CGFloat(text.count) / CGFloat(maxLength))
                .stroke(remaining < 20 ? Color.red : Color.nbAccent, lineWidth: 2)
                .frame(width: 28, height: 28)
                .rotationEffect(.degrees(-90))
            if remaining <= 20 {
                Text("\(remaining)")
                    .font(.inter(10, weight: .bold))
                    .foregroundStyle(remaining < 0 ? .red : Color.nbBlack)
            }
        }
    }

    private var composeToolbar: some View {
        HStack {
            // Photo picker
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 4 - images.count,
                matching: .images
            ) {
                Image(systemName: "photo")
                    .foregroundStyle(images.count >= 4 ? Color.nbBorder : Color.nbBlue)
            }
            .disabled(images.count >= 4)

            Button {
                showLinkInput.toggle()
            } label: {
                Image(systemName: "link")
                    .foregroundStyle(Color.nbBlue)
            }

            Spacer()
        }
    }

    private var imagePreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(images) { img in
                    ZStack(alignment: .topTrailing) {
                        if let uiImage = img.uiImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                                .nbBorder()
                                .onTapGesture { showAltTextSheet = img }
                        }
                        Button {
                            images.removeAll { $0.id == img.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white)
                                .background(Color.nbBlack)
                                .clipShape(.circle)
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
        }
    }

    private var linkInputField: some View {
        HStack {
            TextField("https://...", text: $linkURL)
                .font(.inter(14))
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.nbWhite)
                .nbBorder()

            Button("Add") {
                Task { await fetchLinkPreview() }
            }
            .font(.inter(14, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.nbAccent)
            .nbBorder()
        }
    }

    private func linkPreviewCard(_ link: ExternalCard) -> some View {
        HStack(alignment: .top) {
            LinkCardView(card: link)
            Button {
                linkEmbed = nil
                showLinkInput = false
                linkURL = ""
            } label: {
                Image(systemName: "xmark")
                    .padding(8)
                    .background(Color.nbBorder)
                    .nbBorder()
            }
        }
    }

    private func replyContext(_ post: PostView) -> some View {
        HStack(alignment: .top, spacing: 8) {
            AvatarView(url: post.author.avatar, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to @\(post.author.handle)")
                    .font(.inter(12))
                    .foregroundStyle(Color.nbBlack.opacity(0.5))
                Text(post.record.text)
                    .font(.inter(13))
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(Color.nbBorder.opacity(0.2))
        .nbBorder()
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let img = ComposeImage(imageData: data)
                images.append(img)
            }
        }
        selectedItems = []
    }

    private func fetchLinkPreview() async {
        guard let url = URL(string: linkURL) else { return }
        let title = url.host ?? url.absoluteString
        linkEmbed = ExternalCard(uri: linkURL, title: title, description: "", thumb: nil)
        showLinkInput = false
    }

    private func post() {
        guard let did = auth.session?.did else { return }
        isPosting = true
        errorMessage = nil

        Task {
            do {
                // Upload images first
                var blobRefs: [BlobRef] = []
                var altTexts: [String] = []
                for img in images {
                    let resp = try await ATProtocolClient.shared.uploadBlob(
                        data: img.imageData,
                        mimeType: "image/jpeg"
                    )
                    blobRefs.append(resp.blob)
                    altTexts.append(img.altText)
                }

                // Detect facets in text
                let facets = buildFacets(from: text)

                // Create reply ref
                let replyRef: PostReplyRef? = replyTo.map { parent in
                    // Find root - if parent has a reply, use its root; otherwise parent IS root
                    let root = parent.record.reply?.root ?? StrongRef(uri: parent.uri, cid: parent.cid)
                    return PostReplyRef(
                        root: root,
                        parent: StrongRef(uri: parent.uri, cid: parent.cid)
                    )
                }

                _ = try await ATProtocolClient.shared.createPost(
                    text: text,
                    did: did,
                    reply: replyRef,
                    images: blobRefs,
                    imageAlts: altTexts,
                    linkEmbed: blobRefs.isEmpty ? linkEmbed : nil,
                    quoteUri: quotePost?.uri,
                    quoteCid: quotePost?.cid,
                    facets: facets
                )

                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isPosting = false
            }
        }
    }

    private func buildFacets(from text: String) -> [[String: Any]] {
        var facets: [[String: Any]] = []
        let utf8 = Array(text.utf8)

        // Detect URLs
        let types: NSTextCheckingResult.CheckingType = [.link]
        if let detector = try? NSDataDetector(types: types.rawValue) {
            let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                guard let range = Range(match.range, in: text), let url = match.url else { continue }
                let preSlice = String(text[text.startIndex..<range.lowerBound])
                let byteStart = Array(preSlice.utf8).count
                let matchSlice = String(text[range])
                let byteEnd = byteStart + Array(matchSlice.utf8).count
                facets.append([
                    "index": ["byteStart": byteStart, "byteEnd": byteEnd],
                    "features": [["$type": "app.bsky.richtext.facet#link", "uri": url.absoluteString]]
                ])
            }
        }

        return facets
    }
}

// MARK: - Alt Text Sheet

struct AltTextSheet: View {
    @State var image: ComposeImage
    let onSave: (ComposeImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let ui = image.uiImage {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .nbBorder()
                }

                NBTextField(
                    placeholder: "Describe this image for screen readers...",
                    text: $image.altText,
                    label: "Alt Text"
                )

                Spacer()
            }
            .padding(16)
            .navigationTitle("Add Alt Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(image)
                        dismiss()
                    }
                    .font(.inter(15, weight: .semibold))
                }
            }
        }
    }
}
