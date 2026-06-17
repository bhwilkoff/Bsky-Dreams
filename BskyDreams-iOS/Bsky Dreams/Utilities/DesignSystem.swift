import SwiftUI
import UIKit
import ImageIO

// MARK: - Neubrutalist + Memphis Design System
// Mirrors the web app's visual identity exactly

extension Color {
    /// Dynamic accent — reads from UserDefaults so it reflects the user's setting at runtime.
    static var nbAccent: Color {
        let hex = UserDefaults.standard.string(forKey: "nb_accent_color_hex") ?? "#0047FF"
        return Color(hex: hex)
    }

    /// Accent tuned for legibility AS A FOREGROUND (links, bordered-button tint, icons).
    /// The default accent #0047FF is too dark to read on the dark navy surfaces, so in
    /// dark mode it is lightened ~28%. Light mode is the accent unchanged. Use this for
    /// accent-colored text/icons; keep `nbAccent` for fills (buttons, shadows) where the
    /// background is bright and near-black text sits on top.
    static var nbAccentLegible: Color {
        Color(UIColor { traits in
            let hex = UserDefaults.standard.string(forKey: "nb_accent_color_hex") ?? "#0047FF"
            let base = UIColor(Color(hex: hex))
            return traits.userInterfaceStyle == .dark ? base.nbLightened(by: 0.28) : base
        })
    }
    static let nbBlue    = Color(hex: "#0047FF")  // Electric blue — links, mentions
    static let nbLime    = Color(hex: "#B8E04A")  // Lime — active channels, indicators

    /// Adaptive near-black: #0A0A0A in light mode, #F0F4F8 (near-white) in dark mode.
    /// Using near-white (not slate-blue) in dark mode so that all opacity-based text
    /// (e.g. .opacity(0.5)) blends to WCAG AA contrast on dark card surfaces.
    static var nbBlack: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.94, green: 0.957, blue: 0.973, alpha: 1)  // #F0F4F8 near-white
                : UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)    // #0A0A0A near-black
        })
    }

    /// Card surface: white in light mode, #1A2840 in dark mode.
    /// Intentionally lighter than nbBackground so cards visually lift off the page.
    static var nbWhite: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.10, green: 0.16, blue: 0.25, alpha: 1)  // #1A2840 card surface
                : UIColor.white
        })
    }

    /// Page/scroll background — distinct from card surface in dark mode.
    /// Light: barely off-white (#FAFAFA) — invisible change from plain white.
    /// Dark: deep navy-black (#0D1421) — the "floor" that cards float above.
    /// Apply this to ScrollView, List, and outer ZStack backgrounds.
    static var nbBackground: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.05, green: 0.08, blue: 0.13, alpha: 1)  // #0D1421 deep navy-black
                : UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)  // #FAFAFA barely off-white
        })
    }

    /// Secondary text — concrete values replacing `.nbBlack.opacity(0.5)` for WCAG compliance.
    /// Light: #5A5A5A (6.3:1 on white). Dark: #8BA0B5 (4.6:1 on #1A2840).
    static var nbTextSecondary: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.545, green: 0.627, blue: 0.710, alpha: 1)  // #8BA0B5
                : UIColor(red: 0.353, green: 0.353, blue: 0.353, alpha: 1)  // #5A5A5A
        })
    }

    /// Tertiary text — hints, placeholders, timestamps. Replaces `.nbBlack.opacity(0.4)`.
    /// Light: #7A7A7A (4.5:1 on white). Dark: #6D8499 (4.5:1 on #1A2840).
    static var nbTextTertiary: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.427, green: 0.518, blue: 0.600, alpha: 1)  // #6D8499
                : UIColor(red: 0.478, green: 0.478, blue: 0.478, alpha: 1)  // #7A7A7A
        })
    }

    /// Adaptive divider/separator: #E0E0E0 in light, #405570 in dark (more visible than before).
    static var nbBorder: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.251, green: 0.333, blue: 0.439, alpha: 1)  // #405570 visible slate
                : UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1)     // #E0E0E0
        })
    }

    /// Hard shadow — always near-black in light mode.
    /// In dark mode this is used by NeubrutalistButtonStyle only; card shadows use nbAccent via NBShadowModifier.
    static var nbShadowColor: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.25, green: 0.35, blue: 0.47, alpha: 1)  // #405578 for button shadows
                : UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)  // #0A0A0A
        })
    }

    /// Link text in post bodies. Light: #0047FF (nbBlue). Dark: #5DB8D0 (muted teal — readable on #1A2840).
    static var nbLinkColor: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.365, green: 0.722, blue: 0.816, alpha: 1)  // #5DB8D0 muted teal
                : UIColor(red: 0.00,  green: 0.278, blue: 1.00,  alpha: 1)  // #0047FF electric blue
        })
    }

    /// Received DM message bubble background.
    /// Light: #E8EEF4 (light blue-gray). Dark: #243040 (navy-gray — distinct from card and background).
    static var nbMessageBubble: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.141, green: 0.188, blue: 0.251, alpha: 1)  // #243040
                : UIColor(red: 0.910, green: 0.933, blue: 0.957, alpha: 1)  // #E8EEF4
        })
    }

    /// Analytics heatmap zero-count cell.
    /// Light: #EBEDF0 (subtle light gray). Dark: #1E2D40 (visible dark cell distinct from card).
    static var nbHeatmapZero: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.118, green: 0.176, blue: 0.251, alpha: 1)  // #1E2D40
                : UIColor(red: 0.922, green: 0.929, blue: 0.941, alpha: 1)  // #EBEDF0
        })
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography

extension Font {
    /// Syne Bold — headings, nav labels, buttons.
    /// `relativeTo: .body` makes the custom font scale with Dynamic Type so the
    /// whole app respects the user's text-size setting (Accessibility). Without
    /// `relativeTo:`, a custom font is a fixed point size and ignores Dynamic Type.
    static func syne(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("Syne-Bold", size: size, relativeTo: .body).weight(weight)
    }

    /// Inter — body text. Scales with Dynamic Type (see `syne`).
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size, relativeTo: .body).weight(weight)
    }
}

// MARK: - Shadow

/// ViewModifier that provides the Neubrutalist hard block shadow.
/// Light mode: always near-black (nbShadowColor) — classic Neubrutalist hard shadow.
/// Dark mode: accent-colored at 65% opacity — every card casts a shadow in the user's chosen
/// accent color, creating the playful Memphis+Neubrutalism hybrid the design calls for.
struct NBShadowModifier: ViewModifier {
    var size: CGFloat = 3
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shadowColor = colorScheme == .dark
            ? Color.nbAccent.opacity(0.65)
            : Color.nbShadowColor
        return content.background(shadowColor.offset(x: size, y: size))
    }
}

extension View {
    func nbShadow(size: CGFloat = 3) -> some View {
        modifier(NBShadowModifier(size: size))
    }

    func nbBorder(_ color: Color = .nbBlack, width: CGFloat = 2) -> some View {
        self.overlay(
            Rectangle()
                .strokeBorder(color, lineWidth: width)
        )
    }

    /// Neubrutalist card styling
    func nbCard() -> some View {
        self
            .background(Color.nbWhite)
            .nbBorder()
            .nbShadow()
    }

    /// Lift-on-hover effect (used in buttons)
    func nbButton() -> some View {
        self
            .buttonStyle(NeubrutalistButtonStyle())
    }
}

// MARK: - Button Style

struct NeubrutalistButtonStyle: ButtonStyle {
    var color: Color = .nbAccent

    func makeBody(configuration: Configuration) -> some View {
        NBButtonBody(configuration: configuration, color: color)
    }

    /// Inner view so we can read @Environment(\.colorScheme) for shadow color.
    private struct NBButtonBody: View {
        let configuration: ButtonStyle.Configuration
        let color: Color
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            let isPressed = configuration.isPressed
            // Larger travel (4px total: -3 resting → +1 pressed) makes the mechanical
            // "click" feel more dramatic and unmistakably Neubrutalist.
            let offset: CGFloat = isPressed ? 1 : -3
            let shadowSize: CGFloat = isPressed ? 1 : 4
            // Buttons always have a bright accent background, so text is always near-black
            // regardless of color scheme — never near-white on lime/yellow buttons.
            let shadowColor = colorScheme == .dark
                ? Color.nbBlack.opacity(0.35)  // soft white glow on dark bg
                : Color.nbShadowColor
            return configuration.label
                .font(.syne(14))
                .foregroundStyle(Color(red: 0.04, green: 0.04, blue: 0.04))  // always #0A0A0A
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(color)
                .nbBorder()
                .background(shadowColor.offset(x: shadowSize, y: shadowSize))
                .offset(x: offset, y: offset)
                .animation(.easeOut(duration: 0.08), value: isPressed)
        }
    }
}

struct NeubrutalistIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(
                x: configuration.isPressed ? 1 : 0,
                y: configuration.isPressed ? 1 : 0
            )
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Memphis diagonal stripe pattern (for sidebar header, banners, empty states)

struct DiagonalStripeBackground: View {
    var color: Color = .nbAccent.opacity(0.08)
    var stripeColor: Color = .nbAccent.opacity(0.15)
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // In dark mode, use near-white stripes (nbBlack = #F0F4F8) at higher opacity
        // so the Memphis pattern reads clearly against the deep navy card surface.
        // In light mode, use the passed-in accent-tinted colors unchanged.
        let effectiveBase   = colorScheme == .dark ? Color.nbBlack.opacity(0.06)  : color
        let effectiveStripe = colorScheme == .dark ? Color.nbBlack.opacity(0.14)  : stripeColor

        GeometryReader { geo in
            ZStack {
                effectiveBase
                Canvas { context, size in
                    let spacing: CGFloat = 12
                    var x = -size.height
                    while x < size.width + size.height {
                        let path = Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                            p.addLine(to: CGPoint(x: x + size.height + spacing, y: size.height))
                            p.addLine(to: CGPoint(x: x + spacing, y: 0))
                            p.closeSubpath()
                        }
                        context.fill(path, with: .color(effectiveStripe))
                        x += spacing * 2
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

// MARK: - UIColor lighten helper

extension UIColor {
    /// Returns a copy lightened toward white by `amount` (0…1). Used for dark-mode
    /// accent legibility (see `Color.nbAccentLegible`).
    func nbLightened(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return self }
        let t = max(0, min(1, amount))
        return UIColor(red: r + (1 - r) * t,
                       green: g + (1 - g) * t,
                       blue: b + (1 - b) * t,
                       alpha: a)
    }
}

// MARK: - Haptics

/// Intentional, semantic haptics. Match the *type* of generator to the *type* of event
/// so feedback feels deliberate rather than buzzy:
///   • `.selection` — stepping through peers (image paging, tab/segment change)
///   • `.light/.medium/.heavy` — a discrete action, weight scaled to consequence
///   • `.success/.warning/.error` — an outcome (post sent, hit a limit, request failed)
/// All calls are no-ops if the user has reduced/!supported haptics; UIKit handles that.
enum Haptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func light()  { impact(.light) }
    static func medium() { impact(.medium) }
    static func heavy()  { impact(.heavy) }
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() { notify(.success) }
    static func warning() { notify(.warning) }
    static func error()   { notify(.error) }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Universal feature-state primitives
//
// Every list / grid / sheet should resolve four states beyond the happy path:
// loading, empty, error, offline. These are the canonical neubrutalist renderings —
// never hand-roll per view, so the app stays consistent.

/// Empty state: a brand-voiced `ContentUnavailableView` with an optional productive
/// next action (e.g. "No posts yet — pull to refresh"). Prefer giving users a way
/// forward over a dead-end "No items".
struct NBEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Color.nbAccentLegible)
            VStack(spacing: 6) {
                Text(title)
                    .font(.syne(20))
                    .foregroundStyle(Color.nbBlack)
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .font(.inter(14))
                        .foregroundStyle(Color.nbTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(NeubrutalistButtonStyle())
                    .accessibilityHint("Double tap to \(actionTitle.lowercased())")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
    }
}

/// Error banner: distinct from hints — coral/red, shown ABOVE the content/action,
/// never as a navigation interruption. Optional retry closure.
struct NBErrorBanner: View {
    let message: String
    var retry: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: "#FF5C35"))
                .accessibilityHidden(true)
            Text(message)
                .font(.inter(13))
                .foregroundStyle(Color.nbBlack)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let retry {
                Button("Retry", action: retry)
                    .font(.syne(12))
                    .foregroundStyle(Color.nbAccentLegible)
                    .accessibilityLabel("Retry")
            }
            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.nbTextSecondary)
                }
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(12)
        .background(Color(hex: "#FF5C35").opacity(0.12))
        .nbBorder(Color(hex: "#FF5C35"), width: 2)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }
}

/// Offline pill: subtle, persistent indicator that the network is unavailable.
/// Degrade, don't block — cached content stays browsable.
struct NBOfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .bold))
                .accessibilityHidden(true)
            Text("You're offline — showing cached content")
                .font(.inter(12, weight: .medium))
        }
        .foregroundStyle(Color.nbBlack)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.nbLime)
        .overlay(Rectangle().frame(height: 2).foregroundStyle(Color.nbBlack), alignment: .bottom)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline. Showing cached content.")
    }
}

/// Skeleton placeholder block with a subtle shimmer — use to preserve layout while a
/// list's first page loads, instead of a full-screen spinner. Honors Reduce Motion.
struct NBSkeleton: View {
    var height: CGFloat = 14
    var cornerRadius: CGFloat = 0
    @State private var shimmer = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle()
            .fill(Color.nbBorder.opacity(0.5))
            .frame(height: height)
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.nbWhite.opacity(0.45), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .offset(x: shimmer ? 260 : -260)
                .opacity(reduceMotion ? 0 : 1)
            )
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// A skeleton shaped like a feed post card (avatar + lines), for first-load.
struct NBSkeletonPostRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(Color.nbBorder.opacity(0.5)).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 8) {
                NBSkeleton(height: 12).frame(width: 140)
                NBSkeleton(height: 12)
                NBSkeleton(height: 12).frame(maxWidth: .infinity)
                NBSkeleton(height: 12).frame(width: 200)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

// MARK: - First-run hints
//
// Lightweight just-in-time tips shown on a known surface (NOT a launch slide-deck).
// Each hint dismisses permanently per-device. Teach with real UI in context.

/// Persists the set of permanently-dismissed hint IDs. `@Observable` with a STORED
/// Set (not computed) so SwiftUI re-renders when a hint is dismissed.
@Observable
@MainActor
final class HintsManager {
    static let shared = HintsManager()
    private let key = "bskydreams_dismissed_hints"
    var dismissed: Set<String>

    /// Master switch — user can silence all hints from Settings.
    var hintsEnabled: Bool {
        didSet { UserDefaults.standard.set(hintsEnabled, forKey: "bskydreams_hints_enabled") }
    }

    init() {
        let arr = UserDefaults.standard.stringArray(forKey: key) ?? []
        dismissed = Set(arr)
        hintsEnabled = UserDefaults.standard.object(forKey: "bskydreams_hints_enabled") as? Bool ?? true
    }

    func isVisible(_ id: String) -> Bool { hintsEnabled && !dismissed.contains(id) }

    func dismiss(_ id: String) {
        dismissed.insert(id)
        UserDefaults.standard.set(Array(dismissed), forKey: key)
    }

    func resetAll() {
        dismissed.removeAll()
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// A dismissible tip banner. Renders nothing once dismissed. Cyan-tinted so it's
/// visually distinct from the coral error banner.
struct HintBanner: View {
    let id: String
    let text: String
    var icon: String = "lightbulb.fill"
    @State private var hints = HintsManager.shared

    var body: some View {
        if hints.isVisible(id) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(Color.nbBlue)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.inter(13))
                    .foregroundStyle(Color.nbBlack)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button {
                    Haptics.light()
                    withAnimation { hints.dismiss(id) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.nbTextSecondary)
                }
                .accessibilityLabel("Dismiss tip")
            }
            .padding(12)
            .background(Color.nbBlue.opacity(0.10))
            .nbBorder(Color.nbBlue, width: 2)
            .padding(.horizontal, 12)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Cached, URL-bound async image
//
// NOTE: this lives here (not a standalone CachedImage.swift) because the project's
// Xcode file-system-synchronized groups intermittently fail to pick up new .swift
// files; co-locating in an already-compiled file is the reliable workaround.
//
// AsyncImage has two problems for a recycling feed/grid: (1) a recycled cell can
// briefly show the PREVIOUS row's image because the displayed image is held in
// @State that survives a parameter change, and (2) it decodes full-resolution
// bitmaps on the main actor. CachedImage fixes both: bound to the current URL via
// `.task(id:)`, consults a shared NSCache synchronously (no spinner flash on a hit),
// decodes/downsamples OFF the main actor, and re-checks the URL after every await.

/// Thread-safe (NSCache is documented thread-safe) shared decoded-image cache.
nonisolated(unsafe) private let nbImageCache: NSCache<NSURL, UIImage> = {
    let c = NSCache<NSURL, UIImage>()
    c.countLimit = 600
    c.totalCostLimit = 60 * 1024 * 1024   // ~60 MB of decoded bitmaps
    return c
}()

enum NBImageLoader {
    /// Synchronous cache peek for the exact URL — lets the view render instantly on a hit.
    static func cached(_ url: URL) -> UIImage? { nbImageCache.object(forKey: url as NSURL) }

    /// Empties the in-memory decoded-image cache and the shared URL response cache.
    /// Exposed to Settings → "Clear Image Cache".
    static func clearCache() {
        nbImageCache.removeAllObjects()
        URLCache.shared.removeAllCachedResponses()
    }

    /// Fetch + decode + downsample off the main actor. Returns a display-ready image.
    /// `maxPixel` caps the longest side (in points) so small cells don't decode huge bitmaps.
    static func load(_ url: URL, maxPixel: CGFloat?) async -> UIImage? {
        if let hit = cached(url) { return hit }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return await Task.detached(priority: .utility) { () -> UIImage? in
            let image: UIImage?
            if let maxPixel, let downsampled = NBImageLoader.downsample(data, maxPixel: maxPixel) {
                image = downsampled
            } else {
                image = UIImage(data: data)?.preparingForDisplay()
            }
            if let image {
                let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
                nbImageCache.setObject(image, forKey: url as NSURL, cost: cost)
            }
            return image
        }.value
    }

    /// ImageIO thumbnail decode — never inflates the full bitmap into memory.
    private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts) else { return nil }
        let scale = UIScreen.main.scale
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel * scale
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

/// Drop-in, URL-bound replacement for `AsyncImage(url:content:)`. Mirrors the phase
/// API so adoption is mostly mechanical.
struct CachedImage<Content: View>: View {
    let url: URL?
    /// Longest side in points to downsample to (avatars ~40, grid cells ~200). nil = full size.
    var maxPixelSize: CGFloat? = nil
    @ViewBuilder let content: (CachedImagePhase) -> Content

    @State private var phase: CachedImagePhase = .empty

    init(url: URL?, maxPixelSize: CGFloat? = nil,
         @ViewBuilder content: @escaping (CachedImagePhase) -> Content) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.content = content
        // Seed synchronously from cache so a cache hit renders on first frame (no flash).
        if let url, let hit = NBImageLoader.cached(url) {
            _phase = State(initialValue: .success(Image(uiImage: hit)))
        }
    }

    var body: some View {
        content(phase)
            .task(id: url) { await reload() }
    }

    private func reload() async {
        guard let url else { phase = .failure; return }
        if case .success = phase, NBImageLoader.cached(url) != nil { return }
        let target = url
        if let img = await NBImageLoader.load(url, maxPixel: maxPixelSize) {
            guard target == url else { return }   // parameter changed mid-flight (fast scroll)
            phase = .success(Image(uiImage: img))
        } else {
            guard target == url else { return }
            phase = .failure
        }
    }
}
