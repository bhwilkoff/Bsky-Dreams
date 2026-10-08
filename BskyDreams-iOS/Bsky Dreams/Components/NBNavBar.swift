import SwiftUI

// MARK: - Environment Key for Sidebar Toggle

private struct SidebarToggleKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var toggleSidebar: () -> Void {
        get { self[SidebarToggleKey.self] }
        set { self[SidebarToggleKey.self] = newValue }
    }
}

// MARK: - NBNavBar

/// Neubrutalist navigation bar. Use via the `.nbNavBar(...)` View extension.
/// Title is absolutely centered; leading/trailing buttons float over it in an HStack.
struct NBNavBar<Leading: View, Trailing: View>: View {
    var title: String
    var leading: Leading
    var trailing: Trailing

    /// Measured widths of the side items. Both sides reserve the LARGER one so the
    /// title stays truly centered and can never run under a wide trailing button
    /// (MARK READ is ~90pt; the old fixed 56pt margin let NOTIFICATIONS overlap it).
    @State private var leadingWidth: CGFloat = 36
    @State private var trailingWidth: CGFloat = 36
    private var side: CGFloat { max(leadingWidth, trailingWidth) }

    var body: some View {
        HStack(spacing: 8) {
            leading
                .padding(.leading, NBWindowControls.leadingInset)   // iPad window controls
                .fixedSize()   // measure the NATURAL width, not the frame below (feedback loop)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { leadingWidth = $0 }
                .frame(width: side, alignment: .leading)

            Text(title)
                .font(.syne(14, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.nbBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
                .opacity(title.isEmpty ? 0 : 1)

            trailing
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trailingWidth = $0 }
                .frame(width: side, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 56)
        // Chrome caps at the largest STANDARD size; content (posts, names) scales fully.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .background(Color.nbWhite)
        .overlay(alignment: .bottom) {
            Color.nbBorder.frame(height: 1)
        }
    }
}

// MARK: Convenience inits

extension NBNavBar where Leading == EmptyView, Trailing == EmptyView {
    init(title: String = "") {
        self.title = title
        self.leading = EmptyView()
        self.trailing = EmptyView()
    }
}

extension NBNavBar where Trailing == EmptyView {
    init(title: String = "", @ViewBuilder leading: () -> Leading) {
        self.title = title
        self.leading = leading()
        self.trailing = EmptyView()
    }
}

extension NBNavBar where Leading == EmptyView {
    init(title: String = "", @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.leading = EmptyView()
        self.trailing = trailing()
    }
}

extension NBNavBar {
    init(title: String = "", @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.leading = leading()
        self.trailing = trailing()
    }
}

// MARK: - View Extension

extension View {
    /// Hides the system navigation bar and inserts an NBNavBar into the safe area top.
    func nbNavBar<L: View, T: View>(
        title: String = "",
        @ViewBuilder leading: () -> L,
        @ViewBuilder trailing: () -> T
    ) -> some View {
        self
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                NBNavBar(title: title, leading: leading, trailing: trailing)
            }
    }

    func nbNavBar(title: String = "") -> some View {
        nbNavBar(title: title, leading: { EmptyView() }, trailing: { EmptyView() })
    }

    func nbNavBar<L: View>(title: String = "", @ViewBuilder leading: () -> L) -> some View {
        nbNavBar(title: title, leading: leading, trailing: { EmptyView() })
    }

    func nbNavBar<T: View>(title: String = "", @ViewBuilder trailing: () -> T) -> some View {
        nbNavBar(title: title, leading: { EmptyView() }, trailing: trailing)
    }
}

// MARK: - Reusable NB Buttons

/// Neubrutalist hamburger menu button. Reads toggleSidebar from environment.
struct NBHamburger: View {
    @Environment(\.toggleSidebar) private var toggleSidebar

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.nbBlack)
            .frame(width: 36, height: 36)
            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
            .contentShape(Rectangle())
            .onTapGesture { toggleSidebar() }
            .accessibilityLabel("Open sidebar")
            .accessibilityAddTraits(.isButton)
    }
}

/// Neubrutalist back button. Calls dismiss() from environment.
struct NBBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Image(systemName: "chevron.left")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.nbBlack)
            .frame(width: 36, height: 36)
            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
            .accessibilityLabel("Back")
            .accessibilityAddTraits(.isButton)
    }
}
