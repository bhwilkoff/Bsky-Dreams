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
                // Three equal-width columns at uniform height
                HStack(spacing: 2) {
                    gridImage(images[0], index: 0, height: 140)
                    gridImage(images[1], index: 1, height: 140)
                    gridImage(images[2], index: 2, height: 140)
                }
                .frame(maxWidth: .infinity)
                .clipped()
            default: // 4+
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        gridImage(images[0], index: 0, height: 140)
                        gridImage(images[1], index: 1, height: 140)
                    }
                    HStack(spacing: 2) {
                        gridImage(images[2], index: 2, height: 140)
                        gridImage(images[3], index: 3, height: 140)
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
// Gesture architecture (v4 — TabView + UIScrollView zoom + UIKit dismiss):
//   • TabView with .page style handles horizontal paging natively.
//   • ZoomScrollImage (UIViewRepresentable) wraps ZoomScrollView (UIScrollView)
//     for UIKit-native pinch-to-zoom anchored at the pinch centroid.
//   • ZoomScrollView.gestureRecognizerShouldBegin returns false for the built-in
//     panGestureRecognizer at minimum zoom — passes touches to TabView for paging.
//   • Vertical dismiss: UIPanGestureRecognizer with DismissGestureDelegate, only
//     activates when |vy| > |vx| * 1.5 and always fires simultaneously.
//   • Chrome: .overlay(alignment: .top/.bottom) — sized to content only,
//     never blocks the image interaction area.
//   • Smooth animated dismiss: dismissOffset animates to ±900pt, then dismiss().

struct LightboxView: View {
    let images: [EmbedImage]
    let startIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPage: Int
    @State private var isZoomed: Bool = false
    @State private var dismissOffset: CGFloat = 0
    @State private var isDismissGesture: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveResult: SaveResult? = nil
    @State private var showSettingsAlert: Bool = false
    @State private var zoomResets: [Int: UUID] = [:]

    enum SaveResult: Equatable { case success, failure }

    init(images: [EmbedImage], startIndex: Int) {
        self.images = images
        self.startIndex = startIndex
        _selectedPage = State(initialValue: startIndex)
    }

    private var backgroundOpacity: Double {
        isDismissGesture ? max(0, 1.0 - abs(Double(dismissOffset)) / 300.0) : 1.0
    }

    var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()

            TabView(selection: $selectedPage) {
                ForEach(Array(images.enumerated()), id: \.offset) { i, img in
                    ZoomScrollImage(
                        url: URL(string: img.fullsize),
                        resetID: zoomResets[i] ?? UUID(),
                        onZoomChange: { zoomed in
                            if i == selectedPage { isZoomed = zoomed }
                        },
                        onDismissChanged: { offset in
                            isDismissGesture = true
                            dismissOffset = offset
                        },
                        onDismissEnded: { translation, velocityY in
                            if abs(translation) > 80 || abs(velocityY) > 600 {
                                performDismiss(goingUp: translation < 0)
                            } else {
                                isDismissGesture = false
                                withAnimation(.spring(duration: 0.3)) { dismissOffset = 0 }
                            }
                        },
                        onDismissCancelled: {
                            isDismissGesture = false
                            withAnimation(.spring(duration: 0.3)) { dismissOffset = 0 }
                        }
                    )
                    .offset(y: dismissOffset)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            // safeAreaInset reserves space for bottomChrome so the image content
            // is always constrained ABOVE it — the alt text never overlaps the photo.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomChrome
                    .background(Color.black.opacity(backgroundOpacity))
            }
        }
        .overlay(alignment: .top) { headerBar }
        .onChange(of: selectedPage) { old, _ in
            isZoomed = false
            dismissOffset = 0
            isDismissGesture = false
            zoomResets[old] = UUID()
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
    }

    private func performDismiss(goingUp: Bool) {
        isDismissGesture = true
        withAnimation(.easeOut(duration: 0.25)) {
            dismissOffset = goingUp ? -900 : 900
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.26))
            dismiss()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 0) {
            Button {
                Task { await saveCurrentImage() }
            } label: {
                Group {
                    if isSaving {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    } else if saveResult == .success {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if saveResult == .failure {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    } else {
                        Image(systemName: "arrow.down.to.line")
                            .foregroundStyle(.white)
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
        .padding(.top, 8)
    }

    private var bottomChrome: some View {
        VStack(spacing: 0) {
            // Alt text — always at bottom, never overlapping the image
            if let alt = images[safe: selectedPage]?.alt, !alt.isEmpty {
                Divider().background(Color.white.opacity(0.15))
                ScrollView {
                    Text(alt)
                        .font(.inter(12))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .frame(maxHeight: 80)
            }

            // Dot indicator — centered, each dot tappable
            if images.count > 1 {
                HStack(spacing: 7) {
                    ForEach(0..<images.count, id: \.self) { i in
                        Circle()
                            .fill(i == selectedPage
                                  ? Color.white
                                  : Color.white.opacity(0.35))
                            .frame(
                                width: i == selectedPage ? 8 : 6,
                                height: i == selectedPage ? 8 : 6
                            )
                            .animation(.spring(duration: 0.2), value: selectedPage)
                            .onTapGesture { selectedPage = i }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: Save image

    @MainActor
    private func saveCurrentImage() async {
        guard let urlStr = images[safe: selectedPage]?.fullsize,
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
            // Bluesky CDN serves WebP — PHAssetCreationRequest fails on WebP
            // (PHPhotosErrorDomain 3302). Convert to JPEG first.
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

// MARK: - ZoomScrollImage (UIViewRepresentable)

/// UIKit-backed zoomable image page.
/// UIScrollView handles pinch-to-zoom anchored at the pinch centroid via viewForZooming.
/// A single-touch UIPanGestureRecognizer handles vertical swipe-to-dismiss without
/// conflicting with two-finger pinch, zoom pan, or TabView horizontal paging.
struct ZoomScrollImage: UIViewRepresentable {
    let url: URL?
    let resetID: UUID
    let onZoomChange: (Bool) -> Void
    var onDismissChanged: ((CGFloat) -> Void)? = nil
    var onDismissEnded: ((CGFloat, CGFloat) -> Void)? = nil
    var onDismissCancelled: (() -> Void)? = nil

    func makeUIView(context: Context) -> ZoomScrollView {
        let sv = ZoomScrollView()
        sv.onZoomChange = onZoomChange
        sv.onDismissChanged = onDismissChanged
        sv.onDismissEnded = onDismissEnded
        sv.onDismissCancelled = onDismissCancelled
        return sv
    }

    func updateUIView(_ sv: ZoomScrollView, context: Context) {
        sv.onZoomChange = onZoomChange
        sv.onDismissChanged = onDismissChanged
        sv.onDismissEnded = onDismissEnded
        sv.onDismissCancelled = onDismissCancelled

        if sv.lastURL != url {
            // URL changed — full reload: clear image then fetch.
            sv.lastURL = url
            sv.lastResetID = resetID
            sv.clearAndResetZoom()
            guard let url = url else { return }
            Task.detached(priority: .userInitiated) {
                guard let data = try? Data(contentsOf: url),
                      let img = UIImage(data: data) else { return }
                await MainActor.run { sv.setImage(img) }
            }
        } else if sv.lastResetID != resetID {
            // resetID changed (navigated away and back) — reset zoom only, keep image.
            // Keeping the image prevents a flash while the old page swipes out.
            sv.lastResetID = resetID
            sv.resetZoomOnly()
        }
    }
}

// MARK: - ZoomScrollView

final class ZoomScrollView: UIScrollView {
    var onZoomChange: ((Bool) -> Void)?
    var onDismissChanged: ((CGFloat) -> Void)?
    var onDismissEnded: ((CGFloat, CGFloat) -> Void)?
    var onDismissCancelled: (() -> Void)?

    var lastURL: URL? = nil
    var lastResetID: UUID = UUID()

    private let imageView = UIImageView()
    private var dismissDelegate: DismissGestureDelegate?
    /// True during an active pinch gesture. Prevents layoutSubviews from
    /// resetting zoomScale to 1 while UIKit is mid-zoom.
    private var isActivelyZooming = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        delegate = self
        minimumZoomScale = 1.0
        maximumZoomScale = 5.0
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear
        bouncesZoom = true

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let delegate = DismissGestureDelegate()
        delegate.scrollView = self          // lets delegate check zoom state
        dismissDelegate = delegate
        let dismissPan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        dismissPan.delegate = delegate
        dismissPan.maximumNumberOfTouches = 1   // never fires during two-finger pinch
        addGestureRecognizer(dismissPan)
    }

    func setImage(_ image: UIImage) {
        imageView.image = image
        fitImageToView()
    }

    /// Full reset: clears the image and snaps zoom to 1. Use for URL changes.
    func clearAndResetZoom() {
        isActivelyZooming = false
        imageView.image = nil
        if zoomScale != 1.0 { setZoomScale(1.0, animated: false) }
        fitImageToView()
        onZoomChange?(false)
    }

    /// Zoom-only reset: keeps the loaded image, just snaps zoom back to 1.
    /// Avoids a blank-frame flash when the old page is still visible during swipe.
    func resetZoomOnly() {
        guard zoomScale > minimumZoomScale + 0.01 else { return }
        isActivelyZooming = false
        setZoomScale(minimumZoomScale, animated: false)
        onZoomChange?(false)
    }

    private func fitImageToView() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let size = imageView.image?.size ?? CGSize(width: bounds.width, height: bounds.height)
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fittedSize = CGSize(width: size.width * scale, height: size.height * scale)
        // (0,0) origin required: UIScrollView zoom anchors at viewForZooming's origin.
        imageView.frame = CGRect(origin: .zero, size: fittedSize)
        contentSize = fittedSize
        updateCentering()
    }

    /// Centers the image via contentInset — does not touch imageView.frame or transform,
    /// so it is safe to call at any zoom level.
    private func updateCentering() {
        let offsetX = max((bounds.width - contentSize.width) / 2, 0)
        let offsetY = max((bounds.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // UIScrollView calls layoutSubviews on every zoom frame. Calling fitImageToView
        // (which resets zoomScale = 1) mid-pinch would instantly snap zoom back to 1.
        // Guard: only refit when not actively zooming AND already at minimum scale.
        if !isActivelyZooming && zoomScale <= minimumZoomScale + 0.01 {
            fitImageToView()
        } else {
            updateCentering()
        }
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale + 0.01 {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let point = recognizer.location(in: imageView)
            let newScale: CGFloat = 2.5
            let zoomWidth = imageView.bounds.width / newScale
            let zoomHeight = imageView.bounds.height / newScale
            let zoomRect = CGRect(
                x: point.x - zoomWidth / 2,
                y: point.y - zoomHeight / 2,
                width: zoomWidth,
                height: zoomHeight
            )
            zoom(to: zoomRect, animated: true)
        }
    }

    @objc private func handleDismissPan(_ recognizer: UIPanGestureRecognizer) {
        // Secondary guard: should not fire while zoomed (DismissGestureDelegate
        // handles the primary check at gesture-begin time).
        guard zoomScale <= minimumZoomScale + 0.01 else {
            recognizer.isEnabled = false
            recognizer.isEnabled = true
            return
        }
        let t = recognizer.translation(in: self)
        let v = recognizer.velocity(in: self)
        switch recognizer.state {
        case .changed: onDismissChanged?(t.y)
        case .ended:   onDismissEnded?(t.y, v.y)
        case .cancelled, .failed: onDismissCancelled?()
        default: break
        }
    }

    /// At minimum zoom, suppress the built-in panGestureRecognizer so horizontal
    /// swipes pass to TabView's UIScrollView for page navigation.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === panGestureRecognizer && zoomScale <= minimumZoomScale + 0.01 {
            return false
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

extension ZoomScrollView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        isActivelyZooming = true
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateCentering()
        onZoomChange?(scrollView.zoomScale > scrollView.minimumZoomScale + 0.01)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        isActivelyZooming = false
        // bouncesZoom = true already snaps to minimumZoomScale automatically;
        // no need to call setZoomScale here — that would cause a redundant layout cycle.
        onZoomChange?(scale > minimumZoomScale + 0.01)
        updateCentering()
    }
}

// MARK: - DismissGestureDelegate

/// Begins only for clearly vertical single-finger pans (|vy| > |vx| * 1.5)
/// and only when the image is not zoomed. Always fires simultaneously with other recognizers.
private final class DismissGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var scrollView: ZoomScrollView?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Never dismiss while zoomed in — user is panning around the image.
        if let sv = scrollView, sv.zoomScale > sv.minimumZoomScale + 0.01 { return false }
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
              let view = pan.view else { return false }
        let vel = pan.velocity(in: view)
        return abs(vel.y) > abs(vel.x) * 1.5
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }
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
        ZStack(alignment: .bottomTrailing) {
            if isPlaying, let player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)

                // Fullscreen button — presents AVPlayerViewController natively via UIKit
                Button {
                    presentFullscreen(player: player)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
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
        // Prevent SwiftUI animation propagation into AVPlayerViewController.
        // Without this, animated layout changes (e.g. inline reply opening in ThreadView)
        // crash because AVKit doesn't support CoreAnimation implicit frame animations.
        .transaction { $0.animation = nil }
        .nbBorder()
        .onDisappear {
            player?.pause()
            player = nil
            isPlaying = false
        }
    }

    private func startPlaying() {
        guard let playlist = video.playlist, let url = URL(string: playlist) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let p = AVPlayer(url: url)
        p.play()
        player = p
        isPlaying = true
    }

    /// Present the native AVPlayerViewController directly via UIKit.
    /// Reuses the existing AVPlayer so playback continues from the current position.
    /// Dismissal is handled entirely by AVKit — no intermediate SwiftUI layer.
    private func presentFullscreen(player: AVPlayer) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }

        // Capture current position before the handoff
        let currentTime = player.currentTime()

        // Hide the inline SwiftUI VideoPlayer so it releases the AVPlayer.
        // Two controllers attached to the same AVPlayer causes the pause.
        isPlaying = false
        self.player = nil

        // Create a fresh player from the same URL at the same position
        guard let playlist = video.playlist, let url = URL(string: playlist) else { return }
        let fsPlayer = AVPlayer(url: url)
        let vc = AVPlayerViewController()
        vc.player = fsPlayer
        vc.allowsPictureInPicturePlayback = true

        top.present(vc, animated: true) {
            fsPlayer.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                fsPlayer.play()
            }
        }
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
