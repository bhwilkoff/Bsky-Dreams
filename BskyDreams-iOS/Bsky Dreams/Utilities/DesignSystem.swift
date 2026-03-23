import SwiftUI
import UIKit

// MARK: - Neubrutalist + Memphis Design System
// Mirrors the web app's visual identity exactly

extension Color {
    /// Dynamic accent — reads from UserDefaults so it reflects the user's setting at runtime.
    static var nbAccent: Color {
        let hex = UserDefaults.standard.string(forKey: "nb_accent_color_hex") ?? "#0047FF"
        return Color(hex: hex)
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
    /// Syne Bold — headings, nav labels, buttons
    static func syne(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom("Syne-Bold", size: size).weight(weight)
    }

    /// Inter — body text
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
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
