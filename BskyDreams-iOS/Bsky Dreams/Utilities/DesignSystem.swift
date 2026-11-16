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
        // Accent-tinted paper (§13): the page takes a faint wash of the person's accent,
        // so the app's ground is theirs (and white cards stand off it).
        Color(UIColor { traits in
            let hex = UserDefaults.standard.string(forKey: "nb_accent_color_hex") ?? "#0047FF"
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(Color(hex: hex)).getRed(&r, green: &g, blue: &b, alpha: &a)
            if traits.userInterfaceStyle == .dark {
                let base: (CGFloat, CGFloat, CGFloat) = (0.05, 0.07, 0.11)
                let t: CGFloat = 0.07
                return UIColor(red: base.0 + (r - base.0) * t, green: base.1 + (g - base.1) * t,
                               blue: base.2 + (b - base.2) * t, alpha: 1)
            }
            let t: CGFloat = 0.06
            return UIColor(red: 1 - (1 - r) * t, green: 1 - (1 - g) * t, blue: 1 - (1 - b) * t, alpha: 1)
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
    /// Editorial-native type (iOS-DESIGN §12): San Francisco text styles, so everything
    /// scales with Dynamic Type the way the system does. `syne` keeps the old call sites
    /// and becomes SF Expanded: the wide, confident labels the brand had, in the system
    /// face. `inter` becomes plain SF.
    static func syne(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        // Syne is the brand's voice (§13): labels, headings, buttons, the masthead. It
        // scales with the nearest text style so Dynamic Type still works.
        .custom("Syne-Bold", size: size, relativeTo: nbTextStyle(for: size)).weight(weight)
    }

    /// Body and UI text: SF at the nearest text style (see `syne`).
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(nbTextStyle(for: size), design: .default, weight: weight)
    }

    /// The system text style closest to a point size, so a literal size still tracks
    /// Dynamic Type.
    static func nbTextStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: .caption2
        case ..<12.5: .caption
        case ..<14:   .footnote
        case ..<15.5: .subheadline
        case ..<16.5: .callout
        case ..<18.5: .body
        case ..<21:   .title3
        case ..<24:   .title2
        case ..<31:   .title
        default:      .largeTitle
        }
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
    /// The Bsky Dreams signature lift (§13): the old hard offset shadow, kept as the
    /// brand's mark but rounded and tinted with the person's accent instead of black.
    func nbShadow(size: CGFloat = 3) -> some View {
        modifier(NBSignatureLift(offset: max(3, size)))
    }

    /// A soft container edge (§12): continuous rounded corners that clip what's inside,
    /// and a hairline. A color passed in (an accent for "selected", coral for an error)
    /// tints the hairline.
    func nbBorder(_ color: Color? = nil, width: CGFloat = 2) -> some View {
        let shape = RoundedRectangle(cornerRadius: NBMetrics.corner, style: .continuous)
        return self
            .clipShape(shape)
            .overlay(shape.strokeBorder(color.map { $0.opacity(0.45) } ?? Color.nbBorder, lineWidth: 1))
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

/// See `nbShadow`. Light: accent at 22%; dark: accent at 38% (it has to read on navy).
struct NBSignatureLift: ViewModifier {
    let offset: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: NBMetrics.corner, style: .continuous)
                .fill(Color.nbAccent.opacity(colorScheme == .dark ? 0.38 : 0.22))
                .offset(x: offset, y: offset)
        )
    }
}

enum NBMetrics {
    /// The one corner radius for containers (§12).
    static let corner: CGFloat = 14
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
            // A filled capsule, the system's prominent shape (§12).
            configuration.label
                .font(.headline)
                .foregroundStyle(Color.nbLabel(on: color))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(color, in: Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

/// Retired Memphis stripes (§12): call sites now get a calm brand-colored field.
struct DiagonalStripeBackground: View {
    var color: Color = .clear
    var stripeColor: Color = .clear
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NBContentField(url: nil, tone: colorScheme == .dark ? .deep : .pale)
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
    // Storm breaker (owner, 2026-11-10: "constant vibration", cause not yet reproduced).
    // More than `stormLimit` haptics inside a second is never intentional, so the rest
    // are dropped for a few seconds and what fired them is appended to
    // Documents/haptic-storm.log for diagnosis. Haptics are main-thread UI calls.
    nonisolated(unsafe) private static var recent: [Date] = []
    nonisolated(unsafe) private static var mutedUntil: Date = .distantPast
    private static let stormLimit = 6

    private static func allow(_ kind: String) -> Bool {
        let now = Date()
        if now < mutedUntil { return false }
        recent = recent.filter { now.timeIntervalSince($0) < 1 } + [now]
        guard recent.count > stormLimit else { return true }
        mutedUntil = now.addingTimeInterval(5)
        recent.removeAll()
        recordStorm(kind)
        return false
    }

    private static func recordStorm(_ kind: String) {
        let stack = Thread.callStackSymbols.prefix(14).joined(separator: "\n")
        let entry = "=== \(Date()) haptic storm (\(kind)) ===\n\(stack)\n\n"
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = entry.data(using: .utf8) else { return }
        let url = dir.appendingPathComponent("haptic-storm.log")
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(data); try? h.close()
        } else {
            try? data.write(to: url)
        }
    }

    static func selection() {
        guard allow("selection") else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func light()  { impact(.light) }
    static func medium() { impact(.medium) }
    static func heavy()  { impact(.heavy) }
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard allow("impact") else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() { notify(.success) }
    static func warning() { notify(.warning) }
    static func error()   { notify(.error) }
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard allow("notify") else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Universal feature-state primitives
//
// Every list / grid / sheet should resolve four states beyond the happy path:
// loading, empty, error, offline. These are the canonical neubrutalist renderings —
// never hand-roll per view, so the app stays consistent.

/// Empty state: a brand-voiced `ContentUnavailableView` with an optional productive
/// next action (e.g. "No posts yet. Pull down to refresh."). Prefer giving users a way
/// forward over a dead-end "No items".
struct NBEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        // The system's empty state (§12), in sentence case, 
        ContentUnavailableView {
            Label(title.nbSentenceCase, systemImage: icon)
        } description: {
            if let message { Text(message) }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.nbAccent)
            }
        }
    }
}

extension String {
    /// "NO POSTS FOUND" → "No posts found"; mixed-case strings are left alone.
    var nbSentenceCase: String {
        guard self == uppercased(), contains(where: \.isLetter) else { return self }
        let lower = lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
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
            Text("You're offline. Showing what was already here.")
                .font(.inter(12, weight: .medium))
        }
        .foregroundStyle(Color.nbBlack)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.nbLime.opacity(0.85))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You're offline. Showing what was already here.")
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
                    .foregroundStyle(Color.nbLinkColor)
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
    /// `scale` is the view's `displayScale` — never `UIScreen.main.scale`, which is
    /// ambiguous on a two-display device (iPhone Duo) and slated for deprecation.
    static func load(_ url: URL, maxPixel: CGFloat?, scale: CGFloat) async -> UIImage? {
        if let hit = cached(url) { return hit }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return await Task.detached(priority: .utility) { () -> UIImage? in
            let image: UIImage?
            if let maxPixel, let downsampled = NBImageLoader.downsample(data, maxPixel: maxPixel * scale) {
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
    /// `maxPixel` is in PIXELS (callers multiply by screen scale). ImageIO is thread-safe.
    nonisolated private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
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
    @Environment(\.displayScale) private var displayScale

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
        if let img = await NBImageLoader.load(url, maxPixel: maxPixelSize, scale: displayScale) {
            guard target == url else { return }   // parameter changed mid-flight (fast scroll)
            phase = .success(Image(uiImage: img))
        } else {
            guard target == url else { return }
            phase = .failure
        }
    }
}

// MARK: - Dynamic Type for system-font text
//
// `Font.system(size:)` is a FIXED point size — it ignores the user's text-size
// setting. Post bodies, names and chat use the system font for emoji/Unicode
// coverage (see RichTextView), so they need this: a @ScaledMetric-backed size
// that tracks Dynamic Type live. Icons in fixed-size controls stay fixed.
private struct NBScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    /// System font at `size` pt (at the default text size) that scales with Dynamic Type.
    func scaledSystemFont(_ size: CGFloat, weight: Font.Weight = .regular,
                          relativeTo style: Font.TextStyle = .body) -> some View {
        modifier(NBScaledSystemFont(size: size, weight: weight, relativeTo: style))
    }
}

// MARK: - iPad window controls
//
// On iPadOS 26+ the app's window draws its controls (close/minimize/zoom) in the
// window's top-LEADING corner, over our custom nav bars' leading button — measured
// ~63pt on the iPad Pro 12.9 (device run 2026-10-08). The iPhone-only app runs in
// compatibility mode there, so this keys on iPad hardware, not the idiom.
enum NBWindowControls {
    static let leadingInset: CGFloat = AppDelegate.isIPadHardware ? 56 : 0
}

// MARK: - Offline banner as a modifier
//
// One line per screen instead of hand-placing NBOfflineBanner in each layout branch
// (loading/empty/error/content). Pinned under the nav bar as a top safe-area inset,
// so scrolling content is never covered. Rule §2 (offline state) + §8.2.
private struct NBOfflineInset: ViewModifier {
    @Environment(NetworkMonitor.self) private var network
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            if network.isOffline { NBOfflineBanner() }
        }
    }
}

extension View {
    /// Shows the lime offline banner above this screen's content while offline.
    func nbOfflineBanner() -> some View { modifier(NBOfflineInset()) }
}

// MARK: - Legible label on a fill
extension Color {
    /// Near-black OR white, whichever contrasts more with `fill`. Black on the iOS
    /// DEFAULT accent #0047FF is ~3.35:1 (fails AA); white is ~6.3:1. Lime/coral/teal
    /// accents keep black. Use for any text/icon sitting on an accent-colored fill.
    static func nbLabel(on fill: Color) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(fill).getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let lum = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        let onWhite = 1.05 / (lum + 0.05), onBlack = (lum + 0.05) / 0.053
        return onWhite >= onBlack ? .white : Color(red: 0.04, green: 0.04, blue: 0.04)
    }
}

// MARK: - iPhone Duo: art under the vertical strip (iOS-DESIGN §10)
//
// On the iPhone Duo (iOS 27.1 SDK) the status bar and system bars sit in a strip down
// the trailing edge. Full-bleed art that reaches that edge continues under the strip
// instead of stopping short of it. No-op before iOS 26, so older phones draw exactly
// what they drew before. (Same helper as Archive Watch's `extendsUnderBars()`.)
extension View {
    @ViewBuilder
    func nbExtendsUnderBars() -> some View {
        if #available(iOS 26, *) {
            backgroundExtensionEffect()
        } else {
            self
        }
    }
}

// MARK: - Compact counts (iOS-DESIGN §10.9)
//
// Engagement counts render as 398 · 1.2K · 12K · 1.3M so they never wrap or push the
// action row apart in a narrow column (open Duo: ~335pt per column). VoiceOver keeps
// the exact number via `accessibilityValue`.
func nbCompactCount(_ n: Int) -> String {
    func short(_ v: Double, _ unit: String) -> String {
        let s = v < 10 ? String(format: "%.1f", v) : String(format: "%.0f", v.rounded(.down))
        return (s.hasSuffix(".0") ? String(s.dropLast(2)) : s) + unit
    }
    if n >= 1_000_000 { return short(Double(n) / 1_000_000, "M") }
    if n >= 1_000 { return short(Double(n) / 1_000, "K") }
    return "\(n)"
}

// MARK: - Readable column width (iOS-DESIGN §10.9)
//
// Posts read badly at ~860pt (the open Duo's landscape column with the sidebar hidden):
// lines get long and images huge. Reading lists cap at a comfortable width and centre;
// phone-width columns are unaffected (they are narrower than the cap).
extension View {
    func nbReadableWidth(_ maxWidth: CGFloat = 680) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}

// MARK: - Design language 2 (learned from Stream, iOS-DESIGN §11)
//
// What the Stream redesign taught, shared by every surface:
// - READING TYPE: post text is reading, not UI. It takes the person's reading typeface
//   (Editorial = New York, Modern = SF; system fonts so emoji render) and grows in wide
//   columns, where 15pt reads like a footnote.
// - COLOR FROM CONTENT: a slow mesh of colors sampled from the thing itself (an avatar,
//   an image) instead of a flat fill. Calm, specific, kind to an OLED left on.
// - GLASS FOR WHAT FLOATS: controls over content use Liquid Glass (iOS 26+), with a
//   material fallback. Content keeps its neubrutalist frames.
// - LINES ARRIVE: important text can reveal line by line (a TextRenderer), never for
//   lists people scroll.

// MARK: Reading type

private struct NBReadingSerifKey: EnvironmentKey { static let defaultValue = true }
private struct NBColumnWidthKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }

extension EnvironmentValues {
    /// Editorial (New York) reading type when true; Modern (SF) when false. Set at the
    /// root from Settings → Reading.
    var nbReadingSerif: Bool {
        get { self[NBReadingSerifKey.self] }
        set { self[NBReadingSerifKey.self] = newValue }
    }
    /// The measured width of the column a view sits in (0 = unknown). Reading type grows
    /// with it.
    var nbColumnWidth: CGFloat {
        get { self[NBColumnWidthKey.self] }
        set { self[NBColumnWidthKey.self] = newValue }
    }
}

/// The reading size for a column: phone-width columns keep the base; the open Duo's wide
/// columns (One Column, landscape) step up so lines aren't tiny and endless.
func nbReadingBump(forColumn width: CGFloat) -> CGFloat {
    if width >= 760 { return 4 }
    if width >= 560 { return 2 }
    return 0
}

private struct NBReadingFont: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    @Environment(\.nbReadingSerif) private var serif
    @Environment(\.nbColumnWidth) private var columnWidth
    let base: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        let size = (base + nbReadingBump(forColumn: columnWidth)) * scale
        content
            .font(.system(size: size, weight: weight, design: serif ? .serif : .default))
            .lineSpacing(size * (serif ? 0.24 : 0.3))
    }
}

private struct NBColumnWidthReader: ViewModifier {
    @State private var width: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .environment(\.nbColumnWidth, width)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

extension View {
    /// Post text: the reading typeface, scaled with Dynamic Type and the column's width.
    func nbReadingFont(_ base: CGFloat = 16, weight: Font.Weight = .regular) -> some View {
        modifier(NBReadingFont(base: base, weight: weight))
    }
    /// Measures this column and hands its width to the reading type inside it.
    func nbColumnWidthReader() -> some View { modifier(NBColumnWidthReader()) }
}

/// A reading Font at an exact size (headlines, pull quotes) in the reading typeface.
func nbReadingFace(_ size: CGFloat, weight: Font.Weight = .regular, serif: Bool) -> Font {
    .system(size: size, weight: weight, design: serif ? .serif : .default)
}

func nbReadingUIFont(_ size: CGFloat, weight: UIFont.Weight, serif: Bool) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    guard serif, let d = base.fontDescriptor.withDesign(.serif) else { return base }
    return UIFont(descriptor: d, size: size)
}

/// The largest size at which `text` fits `box` (binary search on UIKit's measurement).
func nbFittedFontSize(_ text: String, box: CGSize, weight: UIFont.Weight, serif: Bool,
                      range: ClosedRange<CGFloat>, lineSpacing: CGFloat) -> CGFloat {
    guard box.width > 40, box.height > 30, !text.isEmpty, range.lowerBound < range.upperBound else {
        return range.lowerBound
    }
    func fits(_ size: CGFloat) -> Bool {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = size * lineSpacing
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: box.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: nbReadingUIFont(size, weight: weight, serif: serif), .paragraphStyle: para],
            context: nil)
        return ceil(rect.height) <= box.height * 0.94
    }
    if fits(range.upperBound) { return range.upperBound }
    var lo = range.lowerBound, hi = range.upperBound
    for _ in 0..<10 {
        let mid = (lo + hi) / 2
        if fits(mid) { lo = mid } else { hi = mid }
    }
    return floor(lo)
}

// MARK: Lines arrive

/// Lines arrive one after another, blurring into focus as they rise (iOS 18 TextRenderer).
struct NBLineReveal: TextRenderer, Animatable {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let lines = Array(layout)
        let n = Double(max(lines.count, 1))
        for (i, line) in lines.enumerated() {
            let start = (Double(i) / n) * 0.55
            let p = min(1, max(0, (progress - start) / 0.45))
            var c = ctx
            c.opacity = p
            if p < 1 {
                c.addFilter(.blur(radius: (1 - p) * 10))
                c.translateBy(x: 0, y: (1 - p) * 14)
            }
            c.draw(line)
        }
    }
}

/// Content dissolves through a soft blur, drifting a little in the direction of travel.
struct NBBlurDissolve: ViewModifier {
    let amount: Double   // 0 = identity, 1 = fully out
    var dx: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .blur(radius: 22 * amount)
            .opacity(1 - amount)
            .scaleEffect(1 + 0.02 * amount)
            .offset(x: dx * amount)
    }
}

extension AnyTransition {
    /// Blur in, blur out.
    static var nbBlurDissolve: AnyTransition {
        .modifier(active: NBBlurDissolve(amount: 1), identity: NBBlurDissolve(amount: 0))
    }
}

// MARK: Color from content

/// Nine colors (a 3×3 grid) sampled from an image: the thing's own palette.
func nbPaletteColors(from image: UIImage) -> [UIColor]? {
    guard let cg = image.cgImage else { return nil }
    let w = 3, h = 3
    var data = [UInt8](repeating: 0, count: w * h * 4)
    let ok = data.withUnsafeMutableBytes { buf -> Bool in
        guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return true
    }
    guard ok else { return nil }
    return (0..<(w * h)).map { i in
        UIColor(red: CGFloat(data[i * 4]) / 255, green: CGFloat(data[i * 4 + 1]) / 255,
                blue: CGFloat(data[i * 4 + 2]) / 255, alpha: 1)
    }
}

enum NBFieldTone { case deep, pale }

/// A sampled color calmed for a background: deep and saturated (white text stays
/// legible) or pale (ink stays legible).
func nbToned(_ c: UIColor, _ tone: NBFieldTone) -> Color {
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    switch tone {
    case .pale: return Color(hue: h, saturation: s * 0.25, brightness: 0.93 + b * 0.05)
    case .deep: return Color(hue: h, saturation: min(1, s * 1.1 + 0.08), brightness: 0.12 + b * 0.24)
    }
}

/// Sampled palettes by image URL, computed once.
@MainActor
enum NBPaletteCache {
    private static var cache: [URL: [UIColor]] = [:]

    static func cached(_ url: URL) -> [UIColor]? { cache[url] }

    static func colors(for url: URL, maxPixel: CGFloat = 120, scale: CGFloat = 2) async -> [UIColor]? {
        if let hit = cache[url] { return hit }
        guard let image = await NBImageLoader.load(url, maxPixel: maxPixel, scale: scale),
              let colors = nbPaletteColors(from: image) else { return nil }
        cache[url] = colors
        return colors
    }
}

/// A slow, drifting mesh of colors: calm motion for a screen left on (Reduce Motion: still).
struct NBAmbientField: View {
    let colors: [Color]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            mesh(0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { ctx in
                mesh(ctx.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func mesh(_ t: Double) -> some View {
        let s = Float(sin(t * 0.13)) * 0.14
        let c = Float(cos(t * 0.09)) * 0.14
        let filled = colors.count >= 9 ? Array(colors.prefix(9)) : Array(repeating: colors.first ?? .black, count: 9)
        return MeshGradient(width: 3, height: 3, points: [
            [0, 0], [0.5 + c * 0.5, 0], [1, 0],
            [0, 0.5 + s * 0.6], [0.5 + s, 0.5 + c], [1, 0.5 - c * 0.6],
            [0, 1], [0.5 - s * 0.5, 1], [1, 1],
        ], colors: filled)
    }
}

/// An ambient field drawn from an image (an avatar, a banner, a photo). Shows the
/// brand's colors until the image's own have been sampled.
struct NBContentField: View {
    let url: URL?
    var tone: NBFieldTone = .deep
    @State private var sampled: [UIColor]? = nil
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        NBAmbientField(colors: (sampled ?? NBContentField.brand).map { nbToned($0, tone) })
            .task(id: url) {
                guard let url else { return }
                if let hit = NBPaletteCache.cached(url) { sampled = hit; return }
                if let colors = await NBPaletteCache.colors(for: url, scale: displayScale) {
                    withAnimation(.easeInOut(duration: 0.8)) { sampled = colors }
                }
            }
    }

    static let brand: [UIColor] = {
        let a = UIColor(red: 0, green: 0.28, blue: 1, alpha: 1)          // #0047FF
        let b = UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1)    // #AF52DE
        let c = UIColor(red: 1, green: 0.36, blue: 0.21, alpha: 1)       // #FF5C35
        let d = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)     // #34C759
        return [a, b, a, c, a, b, d, a, c]
    }()
}

// MARK: Glass for what floats

extension View {
    /// Floating controls use the system's Liquid Glass (material before iOS 26).
    @ViewBuilder
    func nbGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

/// Groups glass controls so they blend and morph together (GlassEffectContainer on 26+).
struct NBGlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder let content: Content
    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

/// A round glass control with a VoiceOver label.
struct NBGlassButton: View {
    let label: String
    let systemImage: String
    var size: CGFloat = 52
    var tint: Color = .white
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .nbGlass(in: Circle())
        .accessibilityLabel(label)
    }
}

/// A glass capsule button (title + symbol).
struct NBGlassCapsule: View {
    let title: String
    let systemImage: String
    var tint: Color = .white
    var height: CGFloat = 48
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .padding(.horizontal, 18)
                .frame(height: height)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .nbGlass(in: Capsule())
    }
}

// MARK: Saved posts (app-wide)

/// Posts saved for later, newest first. Device-local (a list of URIs), shared by every
/// post's menu, Stream's Save, the Saved place and Stream's Saved source.
@Observable @MainActor
final class SavedPosts {
    static let shared = SavedPosts()
    /// Same key Stream used, so saves made there carry over.
    private(set) var uris: [String] = UserDefaults.standard.stringArray(forKey: "stream_saved_uris") ?? [] {
        didSet { UserDefaults.standard.set(Array(uris.prefix(500)), forKey: "stream_saved_uris") }
    }

    func contains(_ uri: String) -> Bool { uris.contains(uri) }

    func toggle(_ uri: String) {
        if let i = uris.firstIndex(of: uri) { uris.remove(at: i) } else { uris.insert(uri, at: 0) }
    }

    func remove(_ uri: String) { uris.removeAll { $0 == uri } }
}

// MARK: - Magazine typography (§13)
//
// Bsky Dreams' personality is typographic, the way a magazine has a voice: a Syne KICKER
// (accent rule + small caps: where you are), a Syne HEADLINE (six words or fewer), and a
// serif DECK (one sentence, in Ben's voice). One masthead per screen, at the top of the
// content, scrolling away with it. Counts that matter get big Syne numerals. No
// decoration, no graphics: type, the accent, and space.

/// "— HOME · CONVERSATIONS": an accent rule and the place in Syne small caps.
struct NBKicker: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(Color.nbAccent)
                .frame(width: 18, height: 3)
            Text(text.uppercased())
                .font(.syne(12))
                .tracking(1.6)
                .foregroundStyle(Color.nbAccentLegible)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Kicker, headline, deck: the top of a screen, magazine-style.
struct NBMasthead: View {
    let kicker: String
    let headline: String
    var deck: String? = nil
    /// Told when the masthead scrolls out of (false) or back into (true) view, so the
    /// screen can show its bar title only then: the name is never shown twice (§13.11).
    var onVisibleChange: ((Bool) -> Void)? = nil
    @Environment(\.nbColumnWidth) private var columnWidth
    @Environment(\.nbReadingSerif) private var serif

    var body: some View {
        let wide = columnWidth >= 560
        VStack(alignment: .leading, spacing: 8) {
            NBKicker(text: kicker)
            Text(headline)
                .font(.syne(wide ? 38 : 30))
                .foregroundStyle(Color.nbBlack)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let deck {
                Text(deck)
                    .font(nbReadingFace(wide ? 19 : 17, serif: serif))
                    .foregroundStyle(Color.nbTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .onScrollVisibilityChange(threshold: 0.35) { visible in onVisibleChange?(visible) }
    }
}

/// A count that matters, as a big Syne numeral over a small caps label.
struct NBStat: View {
    let value: Int
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(nbCompactCount(value))
                .font(.syne(26))
                .foregroundStyle(Color.nbBlack)
                .lineLimit(1)
                .fixedSize()
            Text(label.uppercased())
                .font(.syne(10))
                .tracking(1.2)
                .foregroundStyle(Color.nbTextSecondary)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}

extension View {
    /// The accent-tinted paper behind a navigation screen (§13), via the system's
    /// container background so it sits where the system background would.
    func nbPaper() -> some View {
        containerBackground(Color.nbBackground, for: .navigation)
    }
}


extension View {
    /// Lets a content field melt into the paper beside it (§13): a soft wash toward the
    /// paper color over the whole field, and a fade to paper along the edge it shares
    /// with the next column, so two columns read as one spread, not two slabs.
    func nbBlendsIntoPaper(edge: Edge) -> some View {
        let start: UnitPoint, end: UnitPoint
        switch edge {
        case .leading:  start = .leading;  end = UnitPoint(x: 0.38, y: 0.5)
        case .trailing: start = .trailing; end = UnitPoint(x: 0.62, y: 0.5)
        case .top:      start = .top;      end = UnitPoint(x: 0.5, y: 0.38)
        case .bottom:   start = .bottom;   end = UnitPoint(x: 0.5, y: 0.62)
        }
        return self
            .overlay(Color.nbBackground.opacity(0.28))
            .overlay(LinearGradient(colors: [Color.nbBackground, Color.nbBackground.opacity(0)],
                                    startPoint: start, endPoint: end))
    }
}

// MARK: - Rules (§13.9)
//
// Two rules, because they mean two different things. Both come from the brand's accent
// rule (the kicker's dash), and neither is a default system line.
// - The COLUMN GUTTER separates two independent views: a 1pt accent rule that fades in
//   and out along its length, capped by a solid accent dash (the kicker's dash, upright).
// - The LIST RULE separates items in one sequence: a quiet dotted rule, like a table of
//   contents, inset to where the text starts. Unread items carry the accent dash instead
//   of a tinted background.

/// Between two columns (vertical) or two stacked panes (horizontal).
struct NBColumnGutter: View {
    var stacked: Bool = false
    var body: some View {
        let fade = LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .black, location: 0.12),
            .init(color: .black, location: 0.6),
            .init(color: .clear, location: 1),
        ], startPoint: stacked ? .leading : .top, endPoint: stacked ? .trailing : .bottom)
        ZStack(alignment: stacked ? .leading : .top) {
            Rectangle()
                .fill(Color.nbAccent.opacity(0.35))
                .frame(width: stacked ? nil : 1, height: stacked ? 1 : nil)
                .mask(fade)
            // The cap: the kicker's dash, stood upright, where the gutter begins.
            Capsule()
                .fill(Color.nbAccent)
                .frame(width: stacked ? 18 : 3, height: stacked ? 3 : 18)
                // Level with the masthead kicker's dash, so the two read as one mark.
                .padding(stacked ? .leading : .top, stacked ? 24 : 129)
        }
        .frame(width: stacked ? nil : 3, height: stacked ? 3 : nil)
        .frame(maxWidth: stacked ? .infinity : nil, maxHeight: stacked ? nil : .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Between items in a list: a dotted rule.
struct NBListRule: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 1))
                p.addLine(to: CGPoint(x: geo.size.width, y: 1))
            }
            .stroke(Color.nbTextTertiary.opacity(0.55),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.5, 5]))
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}

/// An unread item's mark: the accent dash at its leading edge.
struct NBUnreadMark: View {
    var body: some View {
        Capsule()
            .fill(Color.nbAccent)
            .frame(width: 3, height: 18)
            .accessibilityHidden(true)
    }
}
