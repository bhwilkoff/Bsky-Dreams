import SwiftUI

// MARK: - Neubrutalist + Memphis Design System
// Mirrors the web app's visual identity exactly

extension Color {
    static let nbAccent  = Color(hex: "#FF5C35")  // Neon coral — buttons, active states
    static let nbBlue    = Color(hex: "#0047FF")  // Electric blue — links, mentions
    static let nbLime    = Color(hex: "#B8E04A")  // Lime — active channels, indicators
    static let nbBlack   = Color(hex: "#0A0A0A")  // Near-black — borders, shadows
    static let nbWhite   = Color.white
    static let nbBorder  = Color(hex: "#E0E0E0")  // Light separator

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
        self.shadow(color: .nbBlack, radius: 0, x: size, y: size)
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
        configuration.label
            .font(.syne(14))
            .foregroundStyle(Color.nbBlack)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color)
            .nbBorder()
            .offset(
                x: configuration.isPressed ? 1 : -2,
                y: configuration.isPressed ? 1 : -2
            )
            .shadow(
                color: .nbBlack,
                radius: 0,
                x: configuration.isPressed ? 1 : 3,
                y: configuration.isPressed ? 1 : 3
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
