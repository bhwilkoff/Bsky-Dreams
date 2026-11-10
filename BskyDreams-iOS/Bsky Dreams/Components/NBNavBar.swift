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

// MARK: - iPhone Duo layout environment (iOS-DESIGN §10)

private struct SidebarIsColumnKey: EnvironmentKey {
    static let defaultValue = false
}
private struct NavColumnKey: EnvironmentKey {
    static let defaultValue: AppStore.NavColumn = .primary
}
private struct BarCornerClearanceKey: EnvironmentKey {
    static let defaultValue = false
}
private struct CloseDetailPaneKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// True on the open iPhone Duo when the sidebar is (or can be) a column beside the
    /// content: the hamburger then shows/hides that column instead of opening a drawer.
    var sidebarIsColumn: Bool {
        get { self[SidebarIsColumnKey.self] }
        set { self[SidebarIsColumnKey.self] = newValue }
    }
    /// Which column a view sits in — opens and pushes stay in that column.
    var navColumn: AppStore.NavColumn {
        get { self[NavColumnKey.self] }
        set { self[NavColumnKey.self] = newValue }
    }
    /// True when the window has (almost) no top safe-area inset — the iPhone Duo with
    /// its status bar in the side strip (inner display in landscape, the closed Duo).
    /// Custom bars then sit at the very top edge, where the display's rounded corners
    /// would clip their corner buttons, so they add clearance (`nbBarCornerClearance`).
    var barCornerClearance: Bool {
        get { self[BarCornerClearanceKey.self] }
        set { self[BarCornerClearanceKey.self] = newValue }
    }
    /// Closes the Duo detail pane. Set only inside the pane; nil everywhere else.
    var closeDetailPane: (() -> Void)? {
        get { self[CloseDetailPaneKey.self] }
        set { self[CloseDetailPaneKey.self] = newValue }
    }
}

// MARK: - Display-corner clearance for custom bars (iOS-DESIGN §10.6)

private struct NBBarCornerClearance: ViewModifier {
    @Environment(\.barCornerClearance) private var clearance
    func body(content: Content) -> some View {
        // Keeps a 36pt corner button inside the display's rounded corner when the bar
        // touches the top edge: ~12pt extra down and ~8pt extra in from each side.
        content
            .padding(.top, clearance ? 12 : 0)
            .padding(.horizontal, clearance ? 8 : 0)
    }
}

extension View {
    func nbBarCornerClearance() -> some View { modifier(NBBarCornerClearance()) }
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
        .nbBarCornerClearance()
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
/// Open iPhone Duo: in the primary column it shows/hides the sidebar column; in the
/// second column it becomes that column's view picker (`NBColumnMenu`).
struct NBHamburger: View {
    @Environment(\.toggleSidebar) private var toggleSidebar
    @Environment(\.sidebarIsColumn) private var sidebarIsColumn
    @Environment(\.navColumn) private var navColumn
    @Environment(AppStore.self) private var store

    var body: some View {
        if navColumn == .secondary {
            NBColumnMenu()
        } else {
            button
        }
    }

    private var button: some View {
        Image(systemName: sidebarIsColumn ? "sidebar.left" : "line.3.horizontal")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.nbBlack)
            .frame(width: 36, height: 36)
            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
            .contentShape(Rectangle())
            .onTapGesture { toggleSidebar() }
            .accessibilityLabel(sidebarIsColumn
                                ? (store.sidebarCollapsed ? "Show sidebar" : "Hide sidebar")
                                : "Open sidebar")
            .accessibilityAddTraits(.isButton)
    }
}

/// The second column's leading control on the open iPhone Duo: pick which view the
/// column shows (any sidebar destination), or close the column.
struct NBColumnMenu: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Menu {
            Section("Right column") {
                ForEach(AppStore.AppTab.allCases, id: \.self) { tab in
                    Button {
                        Haptics.selection()
                        store.openSecondColumn(tab)
                    } label: {
                        Label(tab.label, systemImage: store.secondaryTab == tab ? "checkmark" : tab.icon)
                    }
                }
            }
            Button(role: .destructive) {
                Haptics.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { store.closeSecondColumn() }
            } label: {
                Label("Close Column", systemImage: "xmark.rectangle")
            }
        } label: {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.nbBlack)
                .frame(width: 36, height: 36)
                .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Right column: \(store.secondaryTab?.label ?? "none"). Change view or close")
    }
}

/// At the ROOT of the Duo detail pane there is nothing to go back to, so it becomes
/// a close button that collapses the pane (`isPresented` is false only at a stack root).
struct NBBackButton: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @Environment(\.closeDetailPane) private var closeDetailPane

    private var closesPane: Bool { !isPresented && closeDetailPane != nil }

    var body: some View {
        Image(systemName: closesPane ? "xmark" : "chevron.left")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.nbBlack)
            .frame(width: 36, height: 36)
            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
            .contentShape(Rectangle())
            .onTapGesture {
                if closesPane, let closeDetailPane {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { closeDetailPane() }
                } else {
                    dismiss()
                }
            }
            .accessibilityLabel(closesPane ? "Close conversation" : "Back")
            .accessibilityAddTraits(.isButton)
    }
}
