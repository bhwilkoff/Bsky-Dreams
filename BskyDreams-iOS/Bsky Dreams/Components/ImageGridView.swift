import SwiftUI
import AVKit
import AVFoundation
import Photos
import WebKit

struct ImageGridView: View {
    let images: [EmbedImage]
    @State private var lightboxIndex: Int? = nil

    var body: some View {
        Group {
            switch images.count {
            case 1:
                singleImage(images[0], index: 0)
            case 2:
                HStack(spacing: 2) {
                    gridImage(images[0], index: 0, height: 180)
                    gridImage(images[1], index: 1, height: 180)
                }
                .frame(maxWidth: .infinity)
                .clipped() // belt-and-suspenders: clip the container too
            case 3:
                // Left: tall image; right column: two stacked images
                HStack(spacing: 2) {
                    gridImage(images[0], index: 0, height: 180)
                    VStack(spacing: 2) {
                        gridImage(images[1], index: 1, height: 89)
                        gridImage(images[2], index: 2, height: 89)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .clipped()
            default: // 4+
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        gridImage(images[0], index: 0, height: 130)
                        gridImage(images[1], index: 1, height: 130)
                    }
                    HStack(spacing: 2) {
                        gridImage(images[2], index: 2, height: 130)
                        gridImage(images[3], index: 3, height: 130)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }
        }
        .nbBorder()
        .fullScreenCover(item: Binding(
            get: { lightboxIndex.map { LightboxItem(index: $0) } },
            set: { lightboxIndex = $0?.index }
        )) { item in
            LightboxView(images: images, startIndex: item.index)
        }
    }

    private func singleImage(_ img: EmbedImage, index: Int) -> some View {
        RetryAsyncImage(url: URL(string: img.fullsize), contentMode: .fit)
            .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 480)
            .clipped()
            .onTapGesture { lightboxIndex = index }
    }

    /// Use AsyncImage directly (no RetryAsyncImage wrapper) so .frame() and .clipped() are
    /// applied directly to AsyncImage — matching GalleryCardView's proven approach.
    /// The wrapper's animation layer can interfere with clipping of wide landscape images.
    /// Both maxWidth AND height in a single .frame() call is required before .clipped()
    /// so scaledToFill knows to fill both dimensions. See DECISIONS.md.
    private func gridImage(_ img: EmbedImage, index: Int, height: CGFloat) -> some View {
        AsyncImage(url: URL(string: img.thumb)) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            default: Color.nbBorder.opacity(0.3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        .clipped()
        .onTapGesture { lightboxIndex = index }
    }

    struct LightboxItem: Identifiable {
        var id: Int { index }
        let index: Int
    }
}

// MARK: - Lightbox
//
// Gesture architecture:
//   • Manual HStack carousel with direction-locked outer DragGesture.
//     At first movement > 10pt, locked to .horizontal (paging) or .vertical (dismiss).
//   • Per-page ZoomScrollImage (UIScrollView subclass) — pinch-to-zoom anchored at
//     pinch centroid, pan when zoomed, both handled natively by UIScrollView.
//   • At minimumZoomScale, ZoomScrollView.gestureRecognizerShouldBegin returns false
//     for its panGestureRecognizer — passes all touches to SwiftUI DragGesture.
//   • isZoomed flag blocks outer DragGesture while current page is zoomed.
//   • zoomResets dictionary: changing a page's UUID triggers zoom reset in updateUIView.

struct LightboxView: View {
    let images: [EmbedImage]
    let startIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var dragOffset: CGSize = .zero
    @State private var dragDir: DragDir = .undecided
    @State private var isSaving = false
    @State private var saveResult: SaveResult? = nil
    @State private var showSettingsAlert = false
    @State private var isZoomed = false
    @State private var zoomResets: [Int: UUID]

    private enum DragDir { case undecided, horizontal, vertical }
    enum SaveResult: Equatable { case success, failure }

    init(images: [EmbedImage], startIndex: Int) {
        self.images = images
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
        var resets = [Int: UUID]()
        for i in images.indices { resets[i] = UUID() }
        _zoomResets = State(initialValue: resets)
    }

    private var backgroundOpacity: Double {
        dragDir == .vertical
            ? max(0.2, 1.0 - abs(Double(dragOffset.height)) / 300.0)
            : 1.0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black.opacity(backgroundOpacity).ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar.padding(.top, 8)

                    ZStack {
                        HStack(spacing: 0) {
                            ForEach(Array(images.enumerated()), id: \.offset) { i, img in
                                ZoomScrollImage(
                                    url: URL(string: img.fullsize),
                                    resetID: zoomResets[i] ?? UUID(),
                                    onZoomChange: { zoomed in
                                        if i == currentIndex { isZoomed = zoomed }
                                    }
                                )
                                .frame(width: geo.size.width)
                            }
                        }
                        .offset(
                            x: -CGFloat(currentIndex) * geo.size.width
                                + (dragDir == .horizontal ? dragOffset.width : 0),
                            y: dragDir == .vertical ? dragOffset.height : 0
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    bottomBar
                }
            }
            .gesture(pagingGesture(pageWidth: geo.size.width))
        }
        .alert("Photos Access Required", isPresented: $showSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To save images, allow Bsky Dreams to add to your photo library in Settings.")
        }
        .onChange(of: currentIndex) { _, _ in isZoomed = false }
    }

    // MARK: Paging / dismiss gesture

    private func pagingGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isZoomed else { return }
                if dragDir == .undecided {
                    let ax = abs(value.translation.width)
                    let ay = abs(value.translation.height)
                    guard max(ax, ay) > 10 else { return }
                    dragDir = ax > ay ? .horizontal : .vertical
                }
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isZoomed else {
                    dragDir = .undecided; dragOffset = .zero; return
                }
                let dir = dragDir
                dragDir = .undecided

                switch dir {
                case .horizontal:
                    let threshold = pageWidth * 0.3
                    let vel = value.predictedEndTranslation.width
                    if (value.translation.width < -threshold || vel < -(pageWidth * 0.6))
                        && currentIndex < images.count - 1 {
                        withAnimation(.spring(duration: 0.3)) {
                            zoomResets[currentIndex] = UUID()
                            currentIndex += 1
                            dragOffset = .zero
                        }
                    } else if (value.translation.width > threshold || vel > (pageWidth * 0.6))
                        && currentIndex > 0 {
                        withAnimation(.spring(duration: 0.3)) {
                            zoomResets[currentIndex] = UUID()
                            currentIndex -= 1
                            dragOffset = .zero
                        }
                    } else {
                        withAnimation(.spring(duration: 0.25)) { dragOffset = .zero }
                    }
                case .vertical:
                    if abs(value.translation.height) > 100
                        || abs(value.predictedEndTranslation.height) > 200 {
                        dismiss()
                    } else {
                        withAnimation(.spring()) { dragOffset = .zero }
                    }
                default:
                    withAnimation(.spring(duration: 0.25)) { dragOffset = .zero }
                }
            }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack {
            Button {
                Task { await saveCurrentImage() }
            } label: {
                Group {
                    if isSaving {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else if saveResult == .success {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if saveResult == .failure {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    } else {
                        Image(systemName: "arrow.down.to.line").foregroundStyle(.white)
                    }
                }
                .font(.system(size: 18))
                .frame(width: 44, height: 44)
            }
            .disabled(isSaving)
            .padding(.leading, 8)

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.2), in: Circle())
            }
            .padding(.trailing, 12)
        }
    }

    // MARK: Bottom bar — alt text + page dots

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if let alt = images[safe: currentIndex]?.alt, !alt.isEmpty {
                // allowsHitTesting must NOT be false — it blocks scroll events
                ScrollView {
                    Text(alt)
                        .font(.inter(12))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .frame(maxHeight: 80)
                .background(.ultraThinMaterial)
            }

            if images.count > 1 {
                HStack {
                    Spacer()
                    HStack(spacing: 7) {
                        ForEach(0..<images.count, id: \.self) { i in
                            Circle()
                                .fill(i == currentIndex ? Color.white : Color.white.opacity(0.35))
                                .frame(
                                    width: i == currentIndex ? 8 : 6,
                                    height: i == currentIndex ? 8 : 6
                                )
                                .animation(.spring(duration: 0.2), value: currentIndex)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
            } else {
                Spacer().frame(height: 16)
            }
        }
    }

    // MARK: Save image

    @MainActor
    private func saveCurrentImage() async {
        guard let urlStr = images[safe: currentIndex]?.fullsize,
              let url = URL(string: urlStr) else { return }
        isSaving = true
        defer { isSaving = false }

        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if currentStatus == .denied || currentStatus == .restricted {
            showSettingsAlert = true
            return
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            if status == .denied { showSettingsAlert = true } else {
                saveResult = .failure
                try? await Task.sleep(for: .seconds(2))
                saveResult = nil
            }
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else {
                saveResult = .failure
                try? await Task.sleep(for: .seconds(2))
                saveResult = nil
                return
            }
            // Bluesky CDN serves WebP — PHAssetChangeRequest.creationRequestForAsset(from:)
            // fails on WebP (PHPhotosErrorDomain 3302). Convert to JPEG first.
            guard let jpegData = uiImage.jpegData(compressionQuality: 0.95) else {
                saveResult = .failure
                try? await Task.sleep(for: .seconds(2))
                saveResult = nil
                return
            }
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: jpegData, options: nil)
            }
            saveResult = .success
            try? await Task.sleep(for: .seconds(2))
            saveResult = nil
        } catch {
            saveResult = .failure
            try? await Task.sleep(for: .seconds(2))
            saveResult = nil
        }
    }
}

// MARK: - ZoomScrollImage

/// UIViewRepresentable wrapping ZoomScrollView for one image page.
/// UIScrollView handles pinch-to-zoom anchored at the pinch centroid and
/// pan when zoomed. At minimumZoomScale its pan recognizer fails so the
/// outer SwiftUI DragGesture handles paging and dismiss.
struct ZoomScrollImage: UIViewRepresentable {
    let url: URL?
    let resetID: UUID
    let onZoomChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ZoomScrollView {
        let sv = ZoomScrollView()
        sv.onZoomChange = onZoomChange
        context.coordinator.lastResetID = resetID
        if let url {
            context.coordinator.load(url: url, into: sv)
        }
        return sv
    }

    func updateUIView(_ uiView: ZoomScrollView, context: Context) {
        uiView.onZoomChange = onZoomChange
        if context.coordinator.lastResetID != resetID {
            context.coordinator.lastResetID = resetID
            uiView.resetZoom()
        }
    }

    @MainActor
    class Coordinator: NSObject {
        var loadTask: Task<Void, Never>?
        var lastResetID: UUID = UUID()

        func load(url: URL, into sv: ZoomScrollView) {
            loadTask?.cancel()
            sv.showLoading(true)
            loadTask = Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard !Task.isCancelled else { return }
                    // Decode UIImage off the main thread — large/tall images can
                    // take 20–80ms to decompress and would visibly stall the UI.
                    let image = await Task.detached(priority: .userInitiated) {
                        UIImage(data: data)
                    }.value
                    guard !Task.isCancelled else { return }
                    sv.setImage(image)
                } catch {
                    sv.showLoading(false)
                }
            }
        }

        deinit { loadTask?.cancel() }
    }
}

// MARK: - ZoomScrollView

final class ZoomScrollView: UIScrollView {
    var onZoomChange: ((Bool) -> Void)?

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        return iv
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .large)
        s.color = .white
        s.hidesWhenStopped = true
        return s
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func configure() {
        delegate = self
        minimumZoomScale = 1.0
        maximumZoomScale = 5.0
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        backgroundColor = .clear
        contentInsetAdjustmentBehavior = .never
        bouncesZoom = true
        decelerationRate = .fast

        addSubview(imageView)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func showLoading(_ loading: Bool) {
        if loading { spinner.startAnimating() } else { spinner.stopAnimating() }
    }

    func setImage(_ image: UIImage?) {
        imageView.image = image
        spinner.stopAnimating()
        setZoomScale(1.0, animated: false)
        setNeedsLayout()
        layoutIfNeeded()
    }

    func resetZoom() {
        setZoomScale(1.0, animated: true)
        contentOffset = .zero
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Only resize the imageView at minimum zoom — at other zoom levels UIScrollView
        // owns the imageView via a CGAffineTransform; setting frame would fight the transform.
        if zoomScale <= minimumZoomScale + 0.01 {
            fitImageToView()
        }
        updateCentering()
        bringSubviewToFront(spinner)
    }

    private func fitImageToView() {
        guard let img = imageView.image,
              bounds.width > 0, bounds.height > 0 else {
            contentSize = bounds.size
            return
        }
        let scale = min(bounds.width / img.size.width, bounds.height / img.size.height)
        let fitted = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        // Set frame only when not in active zoom — safe because we guard zoomScale above
        imageView.frame = CGRect(origin: .zero, size: fitted)
        contentSize = fitted
    }

    // Use contentInset to keep the image centered. This is correct during zoom because
    // contentInset does not interfere with UIScrollView's zoom transform on imageView.
    private func updateCentering() {
        let hInset = max(0, (bounds.width  - contentSize.width)  / 2)
        let vInset = max(0, (bounds.height - contentSize.height) / 2)
        contentInset = UIEdgeInsets(top: vInset, left: hInset, bottom: vInset, right: hInset)
    }

    // At minimumZoomScale the image exactly fits — nothing to scroll.
    // Fail the pan recognizer so SwiftUI's DragGesture handles paging / dismiss.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer {
            return zoomScale > minimumZoomScale + 0.01
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

extension ZoomScrollView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateCentering()
        onZoomChange?(zoomScale > minimumZoomScale + 0.01)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        onZoomChange?(scale > minimumZoomScale + 0.01)
        if scale < 1.05 { setZoomScale(minimumZoomScale, animated: true) }
    }
}

// MARK: - GIF Embed View (animated)

/// Detects if an external card is an animated GIF and renders it inline.
struct GifEmbedView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        let html = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
        <style>html,body{margin:0;padding:0;background:#000;display:flex;align-items:center;justify-content:center;height:100%;}
        img{max-width:100%;max-height:100%;object-fit:contain;}</style>
        </head>
        <body><img src="\(url.absoluteString)"></body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

func isGifExternalCard(_ card: ExternalCard) -> Bool {
    let uri = card.uri.lowercased()
    if uri.hasSuffix(".gif") { return true }
    if let host = URL(string: card.uri)?.host?.lowercased() {
        let gifHosts = ["media.tenor.com", "c.tenor.com", "media.giphy.com",
                        "media0.giphy.com", "media1.giphy.com", "media2.giphy.com",
                        "media3.giphy.com", "i.giphy.com",
                        "media.klipy.com", "cdn.klipy.com", "i.klipy.com"]
        if gifHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return true }
    }
    return false
}

// MARK: - Link Card (matches web app vertical neubrutalist layout)

struct LinkCardView: View {
    let card: ExternalCard
    @State private var showReader = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Full-width thumbnail (160pt tall) — matches web app's `.post-external-thumb`
            if let thumb = card.thumb, let url = URL(string: thumb) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Color.nbBorder.opacity(0.15)
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 160)
                .clipped()
            }

            // Info section — domain, title, description
            VStack(alignment: .leading, spacing: 3) {
                if let host = URL(string: card.uri)?.host {
                    Text(host.lowercased())
                        .font(.inter(11))
                        .foregroundStyle(Color.nbTextTertiary)
                        .lineLimit(1)
                }

                Text(card.title)
                    .font(.inter(14, weight: .semibold))
                    .foregroundStyle(Color.nbBlack)
                    .lineLimit(2)

                if !card.description.isEmpty {
                    Text(card.description)
                        .font(.inter(12))
                        .foregroundStyle(Color.nbTextSecondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.nbBorder.opacity(0.06))
        }
        .nbBorder()
        .contentShape(Rectangle())
        .onTapGesture { showReader = true }
        .sheet(isPresented: $showReader) {
            ArticleReaderSheet(card: card)
        }
    }
}

// MARK: - YouTube Helpers

func youtubeVideoID(from urlString: String) -> String? {
    guard let url = URL(string: urlString) else { return nil }
    let host = url.host ?? ""
    guard host.contains("youtube.com") || host.contains("youtu.be") else { return nil }
    if host.contains("youtu.be") {
        let id = url.pathComponents.dropFirst().first ?? ""
        return id.isEmpty ? nil : String(id)
    }
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
        if let v = components.queryItems?.first(where: { $0.name == "v" })?.value, !v.isEmpty {
            return v
        }
        if url.pathComponents.contains("shorts"), let id = url.pathComponents.last, !id.isEmpty {
            return id
        }
    }
    return nil
}

/// Link card for YouTube posts — opens YouTube app (or Safari fallback).
/// Never routes through ArticleReaderSheet which is for news/articles only.
struct YouTubeLinkCardView: View {
    let videoID: String
    let card: ExternalCard

    private var thumbnailURL: URL? {
        URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Color.black
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.shadow(.drop(color: .black.opacity(0.5), radius: 4)))
            }

            // Info row
            HStack(spacing: 8) {
                Text("▶")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.title.isEmpty ? "YouTube Video" : card.title)
                        .font(.inter(13, weight: .semibold))
                        .foregroundStyle(Color.nbBlack)
                        .lineLimit(2)
                    Text("youtube.com · Tap to watch")
                        .font(.inter(11))
                        .foregroundStyle(Color.nbTextTertiary)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.nbTextTertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.nbBorder.opacity(0.06))
        }
        .nbBorder()
        .contentShape(Rectangle())
        .onTapGesture { openYouTube() }
    }

    private func openYouTube() {
        let appURL = URL(string: "youtube://watch?v=\(videoID)")!
        let webURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)")!
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else {
            UIApplication.shared.open(webURL)
        }
    }
}

// MARK: - Quoted Post

struct QuotedPostView: View {
    let post: PostView
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AvatarView(url: post.author.avatar, size: 20)
                Text(post.author.name)
                    .font(.inter(13, weight: .semibold))
                Text("@\(post.author.handle)")
                    .font(.inter(12))
                    .foregroundStyle(Color.nbTextSecondary)
            }
            if !post.record.text.isEmpty {
                Text(post.record.text)
                    .font(.inter(13))
                    .lineLimit(3)
            }
            if let images = post.embed?.images, !images.isEmpty {
                quotedImageGrid(images)
            } else if let embed = post.embed, case .video(let vid) = embed {
                quotedVideoThumbnail(vid)
            } else if let card = post.embed?.external, isGifExternalCard(card) {
                // GIF badge
                HStack(spacing: 4) {
                    Text("GIF")
                        .font(.syne(10, weight: .bold))
                        .foregroundStyle(Color.nbBlue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .overlay(Rectangle().strokeBorder(Color.nbBlue, lineWidth: 1))
                }
            } else if let card = post.embed?.external {
                HStack(spacing: 6) {
                    if let host = URL(string: card.uri)?.host {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.nbBlue)
                        Text(host.lowercased())
                            .font(.inter(11))
                            .foregroundStyle(Color.nbBlue)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nbBorder.opacity(0.3))
        .nbBorder()
        .contentShape(Rectangle())
        .onTapGesture {
            store.navigationPath.append(PostDestination(uri: post.uri, post: post))
        }
    }

    @ViewBuilder
    private func quotedVideoThumbnail(_ vid: VideoEmbed) -> some View {
        ZStack {
            if let thumbURL = vid.thumbnail.flatMap({ URL(string: $0) }) {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Color.nbBorder.opacity(0.3)
                    }
                }
            } else {
                Color.nbBorder.opacity(0.3)
            }
            Image(systemName: "play.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .clipped()
        .nbBorder()
    }

    @ViewBuilder
    private func quotedImageGrid(_ images: [EmbedImage]) -> some View {
        if images.count == 1 {
            AsyncImage(url: URL(string: images[0].thumb)) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Color.nbBorder.opacity(0.3)
                }
            }
            // Single combined .frame() constrains both dimensions before .clipped()
            // so scaledToFill fills width AND height (not just height).
            .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100)
            .clipped()
            .nbBorder()
        } else {
            HStack(spacing: 3) {
                ForEach(images.prefix(3)) { img in
                    AsyncImage(url: URL(string: img.thumb)) { phase in
                        switch phase {
                        case .success(let i): i.resizable().scaledToFill()
                        default: Color.nbBorder.opacity(0.3)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
                    .clipped()
                }
            }
            .clipped()
            .nbBorder()
        }
    }
}

// MARK: - Video Thumbnail / Inline Player

struct VideoThumbnailView: View {
    let video: VideoEmbed
    @State private var player: AVPlayer? = nil
    @State private var isPlaying = false

    private var hasPlayableURL: Bool { video.playlist != nil }

    var body: some View {
        ZStack {
            if isPlaying, let player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
            } else {
                // Thumbnail with play button overlay
                ZStack {
                    RetryAsyncImage(url: video.thumbnail.flatMap { URL(string: $0) }, contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .clipped()

                    if hasPlayableURL {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.shadow(.drop(radius: 4)))
                    } else {
                        // No playlist — show unavailable indicator
                        VStack(spacing: 6) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Video unavailable")
                                .font(.inter(12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if hasPlayableURL { startPlaying() }
                }
            }
        }
        .nbBorder()
        .onDisappear {
            player?.pause()
            player = nil
            isPlaying = false
        }
    }

    private func startPlaying() {
        guard let playlist = video.playlist, let url = URL(string: playlist) else { return }
        // Override silent switch — explicit user action should always play audio
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let p = AVPlayer(url: url)
        p.play()
        player = p
        isPlaying = true
    }
}

// MARK: - Retry-capable Image loader

/// AsyncImage wrapper with one automatic retry followed by a manual retry button.
/// The single auto-retry fires after 1.5 s (not on scroll) to avoid Task stutter.
struct RetryAsyncImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    @State private var retryCount = 0
    @State private var autoRetried = false

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeIn(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                if contentMode == .fill {
                    image.resizable().scaledToFill()
                } else {
                    image.resizable().scaledToFit()
                }
            case .failure:
                if autoRetried {
                    // Auto-retry already attempted — show manual button
                    Color.nbBorder.opacity(0.2)
                        .overlay(
                            Button {
                                retryCount += 1
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(Color.nbTextTertiary)
                            }
                        )
                } else {
                    // First failure — auto-retry once after a short delay
                    Color.nbBorder.opacity(0.15)
                        .task {
                            try? await Task.sleep(for: .milliseconds(1500))
                            autoRetried = true
                            retryCount += 1
                        }
                }
            case .empty:
                Color.nbBorder.opacity(0.15)
            @unknown default:
                Color.nbBorder
            }
        }
        .id(retryCount)
    }
}

// MARK: - Image Prefetching
//
// Pre-warms URLCache.shared with upcoming feed images so AsyncImage gets a cache hit
// instead of a network request when cells scroll into view. Tasks run at .background
// priority to avoid competing with visible content downloads.

nonisolated func feedItemImageURLs(for post: PostView) -> [URL] {
    var urls: [URL] = []

    if let avatar = post.author.avatar, let url = URL(string: avatar) {
        urls.append(url)
    }

    switch post.embed {
    case .images(let imgs):
        urls += imgs.images.compactMap { URL(string: $0.thumb) }
    case .video(let vid):
        if let thumb = vid.thumbnail, let url = URL(string: thumb) { urls.append(url) }
    case .external(let ext):
        if let thumb = ext.external.thumb, let url = URL(string: thumb) { urls.append(url) }
    case .recordWithMedia(let rwm):
        if case .images(let imgs) = rwm.media {
            urls += imgs.images.compactMap { URL(string: $0.thumb) }
        }
        if case .video(let vid) = rwm.media,
           let thumb = vid.thumbnail, let url = URL(string: thumb) { urls.append(url) }
    default:
        break
    }

    return urls
}

nonisolated func prefetchImageURLs(_ urls: [URL]) {
    let session = URLSession.shared
    for url in urls {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        guard URLCache.shared.cachedResponse(for: request) == nil else { continue }
        let task = session.dataTask(with: request) { _, _, _ in }
        task.priority = URLSessionTask.lowPriority
        task.resume()
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
