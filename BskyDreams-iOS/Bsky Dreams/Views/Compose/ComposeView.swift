import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import UserNotifications

/// Transfers a video file from the Photos library to a temporary location on disk,
/// preserving the original file extension (mp4, mov, etc.).
struct VideoFileTransferable: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mp4" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return VideoFileTransferable(url: dest)
        }
    }
}

struct ComposeView: View {
    var replyTo: PostView? = nil
    var quotePost: PostView? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var auth

    @State private var text: String
    @State private var images: [ComposeImage]

    init(replyTo: PostView? = nil, quotePost: PostView? = nil,
         initialText: String = "", initialImages: [ComposeImage] = [],
         initialVideo: ComposeVideo? = nil) {
        self.replyTo = replyTo
        self.quotePost = quotePost
        _text = State(initialValue: initialText)
        _images = State(initialValue: initialImages)
        _composeVideo = State(initialValue: initialVideo)
    }
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedVideoItem: PhotosPickerItem? = nil
    @State private var composeVideo: ComposeVideo? = nil
    @State private var linkEmbed: ExternalCard? = nil
    @State private var linkURL = ""
    @State private var showLinkInput = false
    @State private var isPosting = false
    @State private var isUploadingVideo = false
    @State private var errorMessage: String?
    @State private var showAltTextSheet: ComposeImage? = nil
    @State private var showGifPicker = false
    @State private var gifEmbed: ExternalCard? = nil
    @FocusState private var isTextFocused: Bool

    private let maxLength = 300
    private var remaining: Int { maxLength - text.count }
    private var canPost: Bool { (!text.isEmpty || !images.isEmpty || gifEmbed != nil || composeVideo != nil) && remaining >= 0 && !isPosting }

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
                            .focused($isTextFocused)
                    }
                    .padding(.horizontal, 4)

                    // Image grid preview
                    if !images.isEmpty {
                        imagePreview
                    }

                    // Video preview
                    if let vid = composeVideo {
                        videoPreview(vid)
                    }

                    // GIF embed preview
                    if let gif = gifEmbed {
                        HStack(alignment: .top) {
                            AnimatedGifView(url: gif.uri, contentMode: .scaleAspectFit)
                                .frame(maxWidth: .infinity, maxHeight: 160)
                                .nbBorder()

                            Button {
                                gifEmbed = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .padding(8)
                                    .background(Color.nbBorder)
                                    .nbBorder()
                            }
                        }
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
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    composeToolbar
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                composeHeader
            }
            .onAppear {
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    isTextFocused = true
                }
            }
        }
        .onChange(of: selectedItems) { _, items in
            Task { await loadImages(from: items) }
        }
        .onChange(of: selectedVideoItem) { _, item in
            guard let item else { return }
            Task { await loadVideo(from: item) }
        }
        .onChange(of: text) { _, newText in
            // Auto-detect first URL in text and immediately fetch the link card
            if linkEmbed == nil, !showLinkInput {
                if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
                   let match = detector.firstMatch(in: newText, range: NSRange(newText.startIndex..., in: newText)),
                   Range(match.range, in: newText) != nil,
                   let url = match.url {
                    let urlStr = url.absoluteString
                    if urlStr.hasPrefix("http") {
                        linkURL = urlStr
                        showLinkInput = true
                        // Auto-fetch the preview — user doesn't need to tap the fetch button
                        Task { await fetchLinkPreview() }
                    }
                }
            }
        }
        .sheet(item: $showAltTextSheet) { img in
            AltTextSheet(image: img) { updatedImg in
                if let idx = images.firstIndex(where: { $0.id == updatedImg.id }) {
                    images[idx] = updatedImg
                }
            }
        }
        .sheet(isPresented: $showGifPicker) {
            GifPickerView { gifUrl, thumbUrl in
                gifEmbed = ExternalCard(uri: gifUrl, title: "GIF", description: "", thumb: thumbUrl.isEmpty ? nil : thumbUrl)
                showGifPicker = false
            }
        }
    }

    private var composeHeader: some View {
        HStack(spacing: 12) {
            Text("Cancel")
                .font(.inter(16))
                .foregroundStyle(Color.nbBlack)
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
                .accessibilityLabel("Cancel")
                .accessibilityAddTraits(.isButton)

            Spacer()

            Text(replyTo != nil ? "REPLY" : "NEW POST")
                .font(.syne(14, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.nbBlack)

            Spacer()

            characterCounter

            Text(isUploadingVideo ? "Processing..." : isPosting ? "Posting..." : "POST")
                .font(.syne(13, weight: .bold))
                .tracking(1)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(canPost ? Color.nbAccent : Color.nbBlue.opacity(0.4))
                .overlay(Rectangle().strokeBorder(Color.nbBlack.opacity(canPost ? 1 : 0.3), lineWidth: 2))
                .contentShape(Rectangle())
                .onTapGesture { if canPost && !isPosting { post() } }
                .accessibilityLabel(isPosting ? "Posting" : "POST")
                .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Color.nbWhite)
        .overlay(alignment: .bottom) {
            Color.nbBorder.frame(height: 1)
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
            // Photo picker — disabled when a video is attached
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 4 - images.count,
                matching: .images
            ) {
                Image(systemName: "photo")
                    .foregroundStyle((images.count >= 4 || composeVideo != nil) ? Color.nbBorder : Color.nbBlue)
            }
            .disabled(images.count >= 4 || composeVideo != nil)

            // Video picker — disabled when images are attached
            PhotosPicker(
                selection: $selectedVideoItem,
                matching: .videos
            ) {
                Image(systemName: "film")
                    .foregroundStyle((!images.isEmpty || composeVideo != nil) ? Color.nbBorder : Color.nbBlue)
            }
            .disabled(!images.isEmpty || composeVideo != nil)

            Button {
                showLinkInput.toggle()
            } label: {
                Image(systemName: "link")
                    .foregroundStyle(Color.nbBlue)
            }

            Button {
                showGifPicker = true
            } label: {
                Text("GIF")
                    .font(.syne(11, weight: .bold))
                    .foregroundStyle(Color.nbBlue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .overlay(Rectangle().strokeBorder(Color.nbBlue, lineWidth: 1.5))
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

    private func videoPreview(_ vid: ComposeVideo) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                if let thumb = vid.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.nbBorder)
                        .frame(width: 80, height: 80)
                }
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
            .nbBorder()

            VStack(alignment: .leading, spacing: 4) {
                Text("VIDEO")
                    .font(.syne(11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Color.nbBlack.opacity(0.5))
                Text(ByteCountFormatter.string(fromByteCount: Int64(vid.videoData.count), countStyle: .file))
                    .font(.inter(12))
            }

            Spacer()

            Button {
                composeVideo = nil
            } label: {
                Image(systemName: "xmark")
                    .padding(8)
                    .background(Color.nbBorder)
                    .nbBorder()
            }
        }
    }

    /// Resize image data to stay within AT Protocol's 1 MB blob limit.
    /// Step 1: Scale pixel dimensions to at most 2048px on the long side (handles high-res
    /// 12–48MP camera photos that quality reduction alone can't bring under the limit).
    /// Step 2: Progressively reduce JPEG quality until the result fits.
    /// Step 3: If still too large, halve dimensions repeatedly until it fits.
    private func resizeImageData(_ data: Data, maxBytes: Int = 950_000) -> Data {
        guard let image = UIImage(data: data) else { return data }

        // Step 1 — cap the long side at 2048px (Social-network–quality ceiling)
        let maxDimension: CGFloat = 2048
        let imgScale = image.scale
        let pixelW = image.size.width * imgScale
        let pixelH = image.size.height * imgScale
        let longSide = max(pixelW, pixelH)

        let working: UIImage
        if longSide > maxDimension {
            let factor = maxDimension / longSide
            let newSize = CGSize(width: image.size.width * factor,
                                 height: image.size.height * factor)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            working = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            working = image
        }

        // Step 2 — quality sweep: start at 0.85, step down by 0.10
        var quality: CGFloat = 0.85
        while quality >= 0.05 {
            if let compressed = working.jpegData(compressionQuality: quality),
               compressed.count <= maxBytes {
                return compressed
            }
            quality -= 0.10
        }

        // Step 3 — dimension reduction loop (quality sweep insufficient for very large images)
        var shrinkFactor: CGFloat = 0.7
        while shrinkFactor >= 0.25 {
            let newSize = CGSize(width: working.size.width * shrinkFactor,
                                 height: working.size.height * shrinkFactor)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let smaller = renderer.image { _ in working.draw(in: CGRect(origin: .zero, size: newSize)) }
            if let compressed = smaller.jpegData(compressionQuality: 0.75),
               compressed.count <= maxBytes {
                return compressed
            }
            shrinkFactor -= 0.15
        }

        return working.jpegData(compressionQuality: 0.4) ?? data
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let resized = resizeImageData(data)
                let img = ComposeImage(imageData: resized)
                images.append(img)
            }
        }
        selectedItems = []
    }

    private func loadVideo(from item: PhotosPickerItem) async {
        guard let transferable = try? await item.loadTransferable(type: VideoFileTransferable.self) else {
            errorMessage = "Could not load video — try a different file"
            selectedVideoItem = nil
            return
        }
        let url = transferable.url
        let maxVideoBytes = 50 * 1024 * 1024  // AT Protocol 50 MB limit
        guard let data = try? Data(contentsOf: url), data.count <= maxVideoBytes else {
            errorMessage = "Video must be under 50 MB"
            selectedVideoItem = nil
            return
        }

        // Generate thumbnail at 0 seconds
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let thumbnail = (try? await generator.image(at: .zero).image).map { UIImage(cgImage: $0) }

        let mimeType: String
        switch url.pathExtension.lowercased() {
        case "mov": mimeType = "video/quicktime"
        default: mimeType = "video/mp4"
        }

        composeVideo = ComposeVideo(videoData: data, thumbnail: thumbnail, mimeType: mimeType)
        selectedVideoItem = nil
    }

    private func fetchLinkPreview() async {
        let rawURL = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = rawURL.hasPrefix("http") ? rawURL : "https://\(rawURL)"
        guard let url = URL(string: urlString) else { return }

        // Fetch and parse OG tags
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            // Fallback: plain URL embed with hostname
            linkEmbed = ExternalCard(uri: urlString, title: url.host ?? urlString, description: "", thumb: nil)
            showLinkInput = false
            return
        }

        let ogTitle = ogMeta(html, property: "og:title") ?? pageTitle(html) ?? url.host ?? urlString
        let ogDesc = ogMeta(html, property: "og:description") ?? ogMeta(html, name: "description") ?? ""
        let ogImage = ogMeta(html, property: "og:image")

        linkEmbed = ExternalCard(uri: urlString, title: ogTitle, description: ogDesc, thumb: ogImage)
        showLinkInput = false
    }

    private func ogMeta(_ html: String, property: String) -> String? {
        // <meta property="og:title" content="..."> or reversed attribute order
        let patterns = [
            "property=[\"']\(property)[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "content=[\"']([^\"']+)[\"'][^>]+property=[\"']\(property)[\"']"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range]).htmlDecoded
            }
        }
        return nil
    }

    private func ogMeta(_ html: String, name: String) -> String? {
        let patterns = [
            "name=[\"']\(name)[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "content=[\"']([^\"']+)[\"'][^>]+name=[\"']\(name)[\"']"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range]).htmlDecoded
            }
        }
        return nil
    }

    private func pageTitle(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<title[^>]*>([^<]+)</title>", options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range]).htmlDecoded
    }

    private func post() {
        guard let did = auth.session?.did else { return }

        // Capture all state before dismissing
        let capturedText = text
        let capturedImages = images
        let capturedVideo = composeVideo
        let capturedGifEmbed = gifEmbed
        let capturedLinkEmbed = linkEmbed
        let capturedQuotePost = quotePost

        let facets = buildFacets(from: capturedText)
        let replyRef: PostReplyRef? = replyTo.map { parent in
            let root = parent.record.reply?.root ?? StrongRef(uri: parent.uri, cid: parent.cid)
            return PostReplyRef(root: root, parent: StrongRef(uri: parent.uri, cid: parent.cid))
        }

        // Dismiss immediately — upload continues in background
        dismiss()

        Task {
            do {
                var uploadedBlobs: [UploadedBlob] = []
                var altTexts: [String] = []
                for img in capturedImages {
                    let resp = try await ATProtocolClient.shared.uploadBlob(data: img.imageData, mimeType: "image/jpeg")
                    uploadedBlobs.append(resp.blob)
                    altTexts.append(img.altText)
                }

                var uploadedVideo: UploadedBlob? = nil
                var videoAlt = ""
                if let vid = capturedVideo {
                    uploadedVideo = try await ATProtocolClient.shared.uploadVideoAndWait(data: vid.videoData, mimeType: vid.mimeType, did: did)
                    videoAlt = vid.altText
                }

                var effectiveLinkEmbed: ExternalCard? = (uploadedBlobs.isEmpty && uploadedVideo == nil) ? (capturedGifEmbed ?? capturedLinkEmbed) : nil
                if var embed = effectiveLinkEmbed, let thumbURLStr = embed.thumb,
                   let thumbURL = URL(string: thumbURLStr), embed.uploadedThumb == nil {
                    if let (thumbData, _) = try? await URLSession.shared.data(from: thumbURL) {
                        let thumbResp = try? await ATProtocolClient.shared.uploadBlob(data: thumbData, mimeType: "image/jpeg")
                        embed.uploadedThumb = thumbResp?.blob
                    }
                    effectiveLinkEmbed = embed
                }

                _ = try await ATProtocolClient.shared.createPost(
                    text: capturedText,
                    did: did,
                    reply: replyRef,
                    images: uploadedBlobs,
                    imageAlts: altTexts,
                    video: uploadedVideo,
                    videoAlt: videoAlt,
                    linkEmbed: effectiveLinkEmbed,
                    quoteUri: capturedQuotePost?.uri,
                    quoteCid: capturedQuotePost?.cid,
                    facets: facets
                )
            } catch {
                // Sheet is already dismissed — notify the user via a local notification
                let content = UNMutableNotificationContent()
                content.title = "Post failed"
                content.body = error.localizedDescription
                content.sound = .default
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }

    private func buildFacets(from text: String) -> [[String: Any]] {
        var facets: [[String: Any]] = []

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

// MARK: - GIF Picker (Klipy)

private let klipyKey = "g1rqkiKBPyzWEydf5K3syROxIGAFxusrnd6yD5Dj2TT8C8U3k9dtTD7qlClmHdNz"

struct GifPickerView: View {
    let onSelect: (String, String) -> Void  // (gifUrl, thumbUrl)

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var gifs: [KlipyGif] = []
    @State private var isLoading = false
    @State private var trendingGifs: [KlipyGif] = []

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar — "Search KLIPY" placeholder required by Klipy branding guidelines
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.nbBlack.opacity(0.4))
                    TextField("Search KLIPY", text: $query)
                        .font(.inter(14))
                        .submitLabel(.search)
                        .onSubmit { Task { await searchGifs() } }
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.nbBlack.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.nbWhite)
                .nbBorder()
                .padding(12)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if (gifs.isEmpty ? trendingGifs : gifs).isEmpty {
                    VStack(spacing: 8) {
                        Text(query.isEmpty ? "Loading trending GIFs…" : "No results for \"\(query)\"")
                            .font(.inter(14))
                            .foregroundStyle(Color.nbBlack.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(gifs.isEmpty ? trendingGifs : gifs) { gif in
                                GifThumbnailView(gif: gif) {
                                    onSelect(gif.gifUrl, gif.thumbUrl)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)

                        // "Powered by KLIPY" logo — required attribution per Klipy branding guidelines
                        HStack {
                            Spacer()
                            Image("klipy-powered-by")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 20)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                }
            }
            .navigationTitle("GIF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await loadTrending() }
        .onChange(of: query) { _, newVal in if newVal.isEmpty { gifs = [] } }
    }

    private func loadTrending() async {
        isLoading = true
        guard let url = URL(string: "https://api.klipy.com/api/v1/\(klipyKey)/gifs/trending?per_page=24") else {
            isLoading = false; return
        }
        if let items = await fetchItems(from: url) {
            trendingGifs = items
        }
        isLoading = false
    }

    private func searchGifs() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let url = URL(string: "https://api.klipy.com/api/v1/\(klipyKey)/gifs/search?q=\(encoded)&per_page=24"),
           let items = await fetchItems(from: url) {
            gifs = items
        }
        isLoading = false
    }

    private func fetchItems(from url: URL) async -> [KlipyGif]? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let response = try? JSONDecoder().decode(KlipyResponse.self, from: data) else { return nil }
        return response.data.data.compactMap { KlipyGif(item: $0) }
    }
}

struct GifThumbnailView: View {
    let gif: KlipyGif
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            AnimatedGifView(url: gif.thumbUrl, placeholderUrl: gif.thumbJpgUrl)
                .frame(width: (UIScreen.main.bounds.width - 32) / 3, height: 90)
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    // Klipy watermark — required on each GIF card per branding guidelines
                    Image("klipy-watermark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 16)
                        .padding(4)
                }
                .nbBorder()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Animated GIF renderer
//
// AsyncImage only renders the first frame of a GIF. This view uses CGImageSource
// to decode all frames + per-frame delays, then drives animation via a Timer.
// UIKit UIImageView.animatedImage is not used because it requires all frames up front
// with a single uniform duration — many GIFs have variable per-frame delays.

struct AnimatedGifView: UIViewRepresentable {
    let url: String
    var placeholderUrl: String = ""
    var contentMode: UIView.ContentMode = .scaleAspectFill

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = contentMode
        iv.clipsToBounds = true
        return iv
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.contentMode = contentMode
        guard let gifURL = URL(string: url) else { return }
        context.coordinator.load(gifURL, placeholderUrl: placeholderUrl, into: uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var currentUrl: URL?
        private var timer: Timer?
        private var frames: [UIImage] = []
        private var delays: [Double] = []
        private var frameIndex = 0
        private weak var imageView: UIImageView?

        func load(_ url: URL, placeholderUrl: String, into imageView: UIImageView) {
            guard url != currentUrl else { return }
            currentUrl = url
            self.imageView = imageView
            stopAnimation()

            // Show static JPEG placeholder immediately while GIF loads
            if !placeholderUrl.isEmpty, let pUrl = URL(string: placeholderUrl) {
                Task {
                    if let (data, _) = try? await URLSession.shared.data(from: pUrl),
                       let img = UIImage(data: data) {
                        await MainActor.run { imageView.image = img }
                    }
                }
            }

            Task { [weak self] in
                guard let self else { return }
                guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
                let (frames, delays) = Self.decode(data: data)
                guard !frames.isEmpty else {
                    // Not an animated GIF — just show as a static image
                    await MainActor.run { imageView.image = UIImage(data: data) }
                    return
                }
                await MainActor.run {
                    self.frames = frames
                    self.delays = delays
                    self.frameIndex = 0
                    imageView.image = frames[0]
                    self.scheduleTimer()
                }
            }
        }

        private func scheduleTimer() {
            guard frames.count > 1 else { return }
            let delay = delays[frameIndex]
            timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self, let iv = self.imageView else { return }
                self.frameIndex = (self.frameIndex + 1) % self.frames.count
                iv.image = self.frames[self.frameIndex]
                self.scheduleTimer()
            }
        }

        private func stopAnimation() {
            timer?.invalidate()
            timer = nil
            frames = []
            delays = []
            frameIndex = 0
        }

        private static func decode(data: Data) -> ([UIImage], [Double]) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return ([], []) }
            let count = CGImageSourceGetCount(source)
            guard count > 1 else { return ([], []) }  // single frame = not animated
            var images: [UIImage] = []
            var delays: [Double] = []
            for i in 0..<count {
                guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
                images.append(UIImage(cgImage: cgImage))
                let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any]
                let gifProps = props?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
                let delay = gifProps?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                          ?? gifProps?[kCGImagePropertyGIFDelayTime as String] as? Double
                          ?? 0.1
                delays.append(max(delay, 0.02))  // clamp to 20ms minimum (browser standard)
            }
            return (images, delays)
        }
    }
}

struct KlipyGif: Identifiable {
    let id: String       // slug — always a string, unlike the numeric id field
    let title: String
    let gifUrl: String   // sm.gif.url — posted as app.bsky.embed.external
    let thumbUrl: String // xs.gif.url — small animated GIF for grid thumbnails
    let thumbJpgUrl: String // xs.jpg.url — static JPEG placeholder while GIF loads

    init?(item: KlipyItem) {
        guard let slug = item.slug,
              // Prefer sm GIF for the embed; fall back to md or xs
              let gifUrl = item.file?.sm?.gif?.url
                        ?? item.file?.md?.gif?.url
                        ?? item.file?.xs?.gif?.url,
              // xs GIF for animated thumbnails in the grid
              let thumbUrl = item.file?.xs?.gif?.url
                          ?? item.file?.sm?.gif?.url
        else { return nil }
        self.id = slug
        self.title = item.title ?? "GIF"
        self.gifUrl = gifUrl
        self.thumbUrl = thumbUrl
        self.thumbJpgUrl = item.file?.xs?.jpg?.url
                        ?? item.file?.sm?.jpg?.url
                        ?? ""
    }
}

// MARK: - Klipy API models
//
// Actual response structure (verified against live API 2026-03-19):
// { result: true, data: { data: [ item ], current_page, per_page, has_next, meta } }
//
// item: { id: Int64, slug: String, title: String, type: String,
//         file: { hd, md, sm, xs: { gif, jpg, webp, mp4, webm: { url, width, height, size } } }
//         tags: [], blur_preview: String }
//
// NOTE: id is Int64, NOT String. Using slug (String) as the stable identifier.

struct KlipyResponse: Decodable {
    let data: KlipyDataWrapper
}

struct KlipyDataWrapper: Decodable {
    let data: [KlipyItem]
}

struct KlipyItem: Decodable {
    let id: Int64?      // numeric in the API — use slug for identification instead
    let slug: String?
    let title: String?
    let file: KlipyFile?
}

// file: { hd, md, sm, xs } — each size has gif/jpg/webp/mp4/webm sub-objects
struct KlipyFile: Decodable {
    let hd: KlipyFileSize?
    let md: KlipyFileSize?
    let sm: KlipyFileSize?
    let xs: KlipyFileSize?
}

// Each size variant: { gif: { url, width, height, size }, jpg: { ... }, webp: { ... }, ... }
struct KlipyFileSize: Decodable {
    let gif: KlipyFileDirect?
    let jpg: KlipyFileDirect?
    let webp: KlipyFileDirect?
}

struct KlipyFileDirect: Decodable {
    let url: String?
}

// MARK: - HTML Entity Decoding

private extension String {
    var htmlDecoded: String {
        guard let data = self.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil) else { return self }
        return attributed.string
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
