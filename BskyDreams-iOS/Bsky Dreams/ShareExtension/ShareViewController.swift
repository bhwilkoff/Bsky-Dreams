import UIKit
import UniformTypeIdentifiers

/// Share Extension view controller.
///
/// Saves shared images/videos/URLs to the App Group container (UserDefaults + PendingShare/),
/// then opens the main app via the UIApplication responder chain.
/// The main app receives bskydreams://share via onOpenURL and calls processPendingShare().
///
/// NOTE: extensionContext?.open() returns false from Share Extensions — iOS routes it
/// through the host app (Photos) which can't handle custom URL schemes. Use the responder
/// chain instead. See DECISIONS.md for the full explanation and all rejected approaches.
class ShareViewController: UIViewController {

    private let appGroupID = "group.app.bskydreams.ios"

    // MARK: - UI

    private let spinner = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await processSharedItems() }
    }

    private func setupUI() {
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        statusLabel.text = "Saving…"
        statusLabel.font = UIFont.systemFont(ofSize: 15)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        [spinner, statusLabel].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    // MARK: - Processing

    @MainActor
    private func processSharedItems() async {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem],
              !extensionItems.isEmpty else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID) else {
            setStatus("Setup required — see CLAUDE.md")
            try? await Task.sleep(for: .seconds(2))
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        let shareDir = groupURL.appendingPathComponent("PendingShare", isDirectory: true)
        try? FileManager.default.removeItem(at: shareDir)
        try? FileManager.default.createDirectory(at: shareDir, withIntermediateDirectories: true)

        var urlStrings: [String] = []
        var sharedText: String? = nil
        var imagePaths: [String] = []
        var videoPaths: [String] = []

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    if let data = await loadImageData(from: provider) {
                        let filename = "image_\(UUID().uuidString).jpg"
                        let dest = shareDir.appendingPathComponent(filename)
                        if (try? data.write(to: dest)) != nil {
                            imagePaths.append(filename)
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    if let url = await loadURL(provider, type: UTType.movie.identifier) {
                        let filename = "video_\(UUID().uuidString).mp4"
                        let dest = shareDir.appendingPathComponent(filename)
                        if (try? FileManager.default.copyItem(at: url, to: dest)) != nil {
                            videoPaths.append(filename)
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = await loadURL(provider, type: UTType.url.identifier),
                       url.scheme != "file" {
                        urlStrings.append(url.absoluteString)
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = await loadString(provider, type: UTType.plainText.identifier) {
                        sharedText = text
                    }
                }
            }
        }

        if let defaults = UserDefaults(suiteName: appGroupID) {
            defaults.set(urlStrings, forKey: "pendingShare_urls")
            defaults.set(sharedText, forKey: "pendingShare_text")
            defaults.set(imagePaths, forKey: "pendingShare_imagePaths")
            defaults.set(videoPaths, forKey: "pendingShare_videoPaths")
            defaults.synchronize()
        }

        setStatus("Opening Bsky Dreams…")

        guard let url = URL(string: "bskydreams://share") else {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        openViaResponderChain(url)
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    @MainActor
    private func setStatus(_ text: String) {
        spinner.stopAnimating()
        spinner.isHidden = true
        statusLabel.text = text
    }

    // MARK: - Open main app

    /// Opens the main app by traversing the UIResponder chain to UIApplication.
    ///
    /// UIApplication.shared is restricted in extension processes, but UIApplication IS
    /// present in the responder chain. We call open(_:options:completionHandler:) via
    /// unsafeBitCast of the IMP with nil options — passing any dictionary (Swift [:] or
    /// NSDictionary()) crashes because UIKit casts it to a private _UIOpenURLOptions class
    /// and calls universalLinksOnly on it.
    @discardableResult
    private func openViaResponderChain(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let r = responder {
            if r.responds(to: selector) {
                typealias OpenFunc = @convention(c) (
                    AnyObject, Selector, NSURL,
                    NSDictionary?,
                    ((Bool) -> Void)?
                ) -> Void
                let open = unsafeBitCast(r.method(for: selector), to: OpenFunc.self)
                open(r, selector, url as NSURL, nil, nil)
                return true
            }
            responder = r.next
        }
        return false
    }

    // MARK: - Item loading helpers

    /// Returns JPEG data for a shared image. Converts UIImage/Data/URL to Data inside the
    /// completion handler so we never pass NSSecureCoding (non-Sendable) across task boundaries.
    private func loadImageData(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                var result: Data? = nil
                if let image = item as? UIImage {
                    result = image.jpegData(compressionQuality: 0.85)
                } else if let data = item as? Data, let image = UIImage(data: data) {
                    result = image.jpegData(compressionQuality: 0.85)
                } else if let url = item as? URL,
                          let data = try? Data(contentsOf: url),
                          let image = UIImage(data: data) {
                    result = image.jpegData(compressionQuality: 0.85)
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func loadURL(_ provider: NSItemProvider, type: String) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                continuation.resume(returning: item as? URL)
            }
        }
    }

    private func loadString(_ provider: NSItemProvider, type: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                continuation.resume(returning: item as? String)
            }
        }
    }
}
