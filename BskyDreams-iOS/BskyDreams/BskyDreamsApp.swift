import SwiftUI
import SwiftData

@main
struct BskyDreamsApp: App {
    @State private var authManager = AuthManager()
    @State private var appStore = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(appStore)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [SeenPost.self, SavedSearch.self, CachedPreferences.self])
    }
}
