import SwiftUI

// MARK: - Navigation chrome = the SYSTEM navigation bar (iOS-DESIGN §1.5, §10)
//
// Every screen's bar is Apple's own navigation bar: a title, the system back button, and
// toolbar items that are each a `Label` (title + symbol). That is what lets iPhone Duo
// move them into its vertical bar beside the status bar, and what every other iPhone
// expects. `nbNavBar(...)` keeps its old call shape so screens didn't change; it no longer
// draws a custom bar. (Owner, 2026-11-10: use Apple's built-in Duo elements, no custom
// interfaces in their place.)

// MARK: - Environment

private struct SidebarToggleKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}
private struct NavColumnKey: EnvironmentKey {
    static let defaultValue: AppStore.NavColumn = .primary
}
private struct CloseDetailPaneKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}
private struct IsPushedKey: EnvironmentKey {
    static let defaultValue = false
}
private struct EmbedPostKey: EnvironmentKey {
    static let defaultValue: PostView? = nil
}
private struct PlayingPostKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// Legacy: the drawer is gone (the system TabView/sidebar replaced it). Kept so old
    /// call sites compile; does nothing.
    var toggleSidebar: () -> Void {
        get { self[SidebarToggleKey.self] }
        set { self[SidebarToggleKey.self] = newValue }
    }
    /// Which column a view sits in — opens and pushes stay in that column.
    var navColumn: AppStore.NavColumn {
        get { self[NavColumnKey.self] }
        set { self[NavColumnKey.self] = newValue }
    }
    /// Closes the Duo detail pane. Set only inside the pane; nil everywhere else.
    var closeDetailPane: (() -> Void)? {
        get { self[CloseDetailPaneKey.self] }
        set { self[CloseDetailPaneKey.self] = newValue }
    }
    /// True for a screen pushed onto a stack (it has the system back button). False for
    /// a stack's root — a tab, the Duo detail pane, or a sheet.
    var nbIsPushed: Bool {
        get { self[IsPushedKey.self] }
        set { self[IsPushedKey.self] = newValue }
    }
    /// The post whose embed is being drawn — lets a link card open the article WITH
    /// that post's discussion beside it on the open Duo (iOS-DESIGN §10.12).
    var embedPost: PostView? {
        get { self[EmbedPostKey.self] }
        set { self[EmbedPostKey.self] = newValue }
    }
    /// URI of the post whose media is already playing beside this view (TV's companion
    /// conversation, §10.13) — its card skips the embed instead of showing it twice.
    var playingPostURI: String? {
        get { self[PlayingPostKey.self] }
        set { self[PlayingPostKey.self] = newValue }
    }
}

// MARK: - nbNavBar → system navigation bar

extension View {
    /// The screen's system navigation bar. `leading` / `trailing` become toolbar items;
    /// `NBHamburger` and `NBBackButton` are markers, not views: the system provides
    /// navigation (tab bar / sidebar, back button), and a root that needs one gets Close.
    func nbNavBar<L: View, T: View>(
        title: String = "",
        @ViewBuilder leading: () -> L,
        @ViewBuilder trailing: () -> T
    ) -> some View {
        let leadingView = leading()
        let trailingView = trailing()
        let isBack = ObjectIdentifier(L.self) == ObjectIdentifier(NBBackButton.self)
        let isMarker = isBack
            || ObjectIdentifier(L.self) == ObjectIdentifier(NBHamburger.self)
            || ObjectIdentifier(L.self) == ObjectIdentifier(EmptyView.self)
        let hasTrailing = ObjectIdentifier(T.self) != ObjectIdentifier(EmptyView.self)
        return self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .modifier(NBRootCloseItem(enabled: isBack))
            .toolbar {
                if !isMarker {
                    ToolbarItem(placement: .topBarLeading) { leadingView }
                }
                if hasTrailing {
                    ToolbarItem(placement: .topBarTrailing) { trailingView }
                }
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

/// A screen that would have shown a back button but is a stack ROOT (a sheet, a full-
/// screen cover, the Duo detail pane) has no system back button, so it gets a system
/// Close item. Pushed screens get Apple's back button and nothing from us.
private struct NBRootCloseItem: ViewModifier {
    let enabled: Bool
    @Environment(\.nbIsPushed) private var isPushed
    @Environment(\.closeDetailPane) private var closeDetailPane
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.toolbar {
            if enabled && !isPushed {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeDetailPane != nil ? "Close Conversation" : "Close", systemImage: "xmark") {
                        if let closeDetailPane {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { closeDetailPane() }
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Markers (kept so call sites compile)

/// Marker for "this screen is a tab root". Navigation is the system tab bar / sidebar.
struct NBHamburger: View {
    var body: some View { EmptyView() }
}

/// Marker for "this screen goes back". Pushed: the system back button. Root: Close.
struct NBBackButton: View {
    var body: some View { EmptyView() }
}

// MARK: - Second-column view picker (open iPhone Duo, §10.3)

/// The right column's leading toolbar item: a system menu to pick which view the column
/// shows, or close it. A `Label`, so it moves into the vertical bar with the rest.
struct NBColumnMenu: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Menu {
            Section("Right Column") {
                ForEach(AppStore.AppTab.columnChoices, id: \.self) { tab in
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
            Label("Right Column", systemImage: "rectangle.split.2x1")
        }
    }
}
