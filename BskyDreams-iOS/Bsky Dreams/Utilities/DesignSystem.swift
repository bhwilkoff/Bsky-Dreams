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

    /// Adaptive near-black: #0A0A0A in light mode, #CCD9E6 (cool blue-white) in dark mode
    static var nbBlack: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.80, green: 0.85, blue: 0.90, alpha: 1)  // #CCD9E6 cool blue-white
                : UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)  // #0A0A0A near-black
        })
    }

    /// Adaptive white: white in light mode, #142033 (deep navy blue) in dark mode (card/surface backgrounds)
    static var nbWhite: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.13, blue: 0.20, alpha: 1)  // #142033 deep navy
                : UIColor.white
        })
    }

    /// Adaptive border: #E0E0E0 in light mode, #253448 (medium dark navy) in dark mode
    static var nbBorder: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.15, green: 0.20, blue: 0.28, alpha: 1)  // #253448 navy border
                : UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1)  // #E0E0E0
        })
    }

    /// Shadow color — stays visually distinct from the card surface in both modes.
    /// Light: near-black so the offset block reads as a hard shadow.
    /// Dark: medium slate-navy (#3D5166) so the shadow is visible against the deep navy card.
    static var nbShadowColor: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.24, green: 0.32, blue: 0.40, alpha: 1)  // #3D5166 slate
                : UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)  // #0A0A0A
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

extension View {
    func nbShadow(size: CGFloat = 3) -> some View {
        // Use explicit background layering instead of .shadow() to guarantee
        // a purely geometric shadow that cannot follow the view's alpha channel
        // and create content-shaped ghost copies of text/icons.
        // Uses nbShadowColor (always dark) so shadows stay visible in dark mode —
        // nbBlack adapts to near-white in dark mode which would create a glowing halo.
        self.background(
            Color.nbShadowColor.offset(x: size, y: size)
        )
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
        let shadowSize: CGFloat = configuration.isPressed ? 1 : 3
        return configuration.label
            .font(.syne(14))
            .foregroundStyle(Color.nbBlack)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color)
            .nbBorder()
            .background(Color.nbShadowColor.offset(x: shadowSize, y: shadowSize))
            .offset(
                x: configuration.isPressed ? 1 : -2,
                y: configuration.isPressed ? 1 : -2
            )
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
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

// MARK: - Memphis diagonal stripe pattern (for sidebar header)

struct DiagonalStripeBackground: View {
    var color: Color = .nbAccent.opacity(0.08)
    var stripeColor: Color = .nbAccent.opacity(0.15)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                color
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
                        context.fill(path, with: .color(stripeColor))
                        x += spacing * 2
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
