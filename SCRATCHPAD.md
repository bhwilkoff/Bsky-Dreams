# Project Scratchpad — Bsky Dreams

## Current Date: 2026-06-17

---

## Feature Parity Status

✅ Complete on both | 🌐 Web only | 📱 iOS only | ⏳ Planned | ❌ Deferred

| Feature | Web | iOS | Notes |
|---|---|---|---|
| Auth (app password, session persistence) | ✅ | ✅ | Web: localStorage; iOS: Keychain |
| JWT refresh on foreground | ✅ | ✅ | Web: visibilitychange; iOS: cold-start + willEnterForeground |
| Home feed (Following + Discover tabs) | ✅ | ✅ | |
| Feed infinite scroll + PTR | ✅ | ✅ | |
| Seen-post deduplication (bypass flag) | ✅ | ✅ | Web: localStorage Map; iOS: SwiftData |
| Compose (rich text, images, video, GIF, link preview) | ✅ | ✅ | |
| Share Extension (save image → App Group → open app) | 📱 | ✅ | iOS only; web is browser-native |
| Post settings (threadgate / postgate) | ✅ | ✅ | |
| @mention autocomplete in compose | ✅ | ✅ | |
| Conversation view (depth-colored nesting, depth ≥ 4 → continue) | ✅ | ✅ | |
| Inline reply compose (in-feed) | ✅ | ✅ | |
| Quote post via repost sheet | ✅ | ✅ | |
| Profile view (feed, follow/unfollow, report) | ✅ | ✅ | |
| Profile interaction graph (frequent conversations) | ✅ | ⏳ | |
| Search (posts + actors, advanced filters) | ✅ | ✅ | |
| Search: saved channels | ✅ | ✅ | |
| Search: channel rename/delete | ✅ | ✅ | |
| Notifications (type-coded, unread badge) | ✅ | ✅ | |
| Notification tap → navigate to relevant post/profile | ✅ | ✅ | |
| Direct messages (conversation list, chat) | ✅ | ✅ | |
| DMs: new conversation (handle search) | ✅ | ✅ | |
| Group DMs (create, members, requests, invite links) | ✅ | ✅ | 2026-06-17; `chat.bsky.group.*`; up to 50; text-only (Bluesky limit) |
| Message reactions (emoji, add/remove) | ✅ | ✅ | 2026-06-17; `chat.bsky.convo.addReaction/removeReaction` |
| Communities (Reddit-style topic spaces) | ⏳ | ⏳ | Announced, NO lexicon yet — watch atproto changelog (own top-level surface when it ships) |
| Gallery (image posts, card layout, like/repost, lightbox) | ✅ | ✅ | iOS: tap image → lightbox; tap metadata → conversation |
| Lightbox: image download button | ✅ | ✅ | Web: added 2026-03-23 (fetch→blob→anchor download) |
| Dark mode (color scheme toggle) | ✅ | ✅ | Web: added 2026-03-23 (html[data-theme="dark"], localStorage persistence, Settings toggle) |
| TV (TikTok-style video feed, topic selector) | ✅ | ✅ | |
| TV: 2× speed on hold | ✅ | ✅ | |
| TV: adult content filter | ✅ | ✅ | |
| TV: trending video feed source | ✅ | ✅ | `thevids` official Bluesky feed added as third source |
| Stream (full-screen post slideshow) | ✅ | ✅ | Web: any orientation; iOS: landscape via fullScreenCover |
| Stream: conversation overlay | 🌐 | ✅ | iOS: ThreadView in fullScreenCover; web: navigates to thread |
| Reader (article cards, Direct/Readable/Archive modes) | ✅ | ✅ | |
| Reader: verified news feed source | ✅ | ✅ | `verified-news` feed merged with timeline + discover |
| Reader: seen-post filtering | ✅ | ✅ | Posts seen in home feed are filtered from Reader |
| Reader: Open in Safari via share sheet | 📱 | ✅ | Custom UIActivity; web is browser-native |
| Gallery: follow-pics + trending art sources | ✅ | ✅ | `followpics` + `art-new` feeds merged with timeline + discover |
| Hybrid feeds (multi-source merging + trending score) | ✅ | ✅ | Both Following and Discover merge 3 feeds; Gallery merges 4 |
| NSFW filtering in all feed views | ✅ | ✅ | Label-based; Search retains user toggle |
| Inline video fullscreen | 📱 | ✅ | AVPlayerViewController via UIKit presentation |
| Smart App Banner + App Store links | 🌐 | — | Web auth screen + settings link to iOS App Store |
| Analytics dashboard (post stats, heatmap) | ✅ | ⏳ | iOS view exists, content TBD |
| Network Constellation (D3 graph) | ✅ | ✅ | iOS: full physics sim, all 4 gestures working (2026-03-18) |
| Timeline scrubber (horizontal, time-offset) | ✅ | ✅ | iOS: full implementation (2026-03-19); sidebar tab, zoom levels, lane layout, profile button |
| Settings (accent color, default feed, clear history) | ✅ | ✅ | |
| Cross-device seen-posts sync via AT Protocol repo | ✅ | ✅ | Collection: app.bsky-dreams.seen / rkey: recent |
| Deep-link / URL routing (bsky.app URL import) | ✅ | ✅ | Web: ?view= params; iOS: NavigationPath |
| Text Shot Builder (M17) | ⏳ | ⏳ | Canvas-based PNG export |
| Post Collections + Export (M18) | ⏳ | ⏳ | Bookmark → named collections |
| RSS/News Contextual Sidebar (M23) | ⏳ | ⏳ | |
| Fact-checking (M27a) | ❌ | ❌ | Paid API required |
| Political bias detection (M27b) | ❌ | ❌ | Paid API or static dataset |
| AI content detection (M27c) | ❌ | ❌ | Paid API required |

---

## Web App Status

**All milestones through M-Reader complete.** App is fully functional for daily Bluesky use at https://bskydreams.com.

### Completed (summary)

- **M1–M12, M19–M21, M28–M36, M38–M51**: Auth, feed, search, compose, threads, profiles, notifications, TV, gallery, routing, prefs sync, settings
- **M13**: Horizontal timeline scrubber in search
- **M14**: Network Constellation (D3.js force graph, search-seeded)
- **M15**: Profile interaction graph (frequent conversations)
- **M16**: Direct messages (chat.bsky.convo.* API, 30s polling)
- **M22**: Analytics dashboard (Canvas API charts, post heatmap)
- **M-Reader**: Article reader (Direct / Readable / Archive modes, three-proxy CORS chain, seen tracking, infinite scroll)
- **Parity (2026-03-23)**: Lightbox download button; Dark mode
- **Stream (2026-03-31)**: Full-screen post slideshow (setup screen + player, no landscape requirement, keyboard/touch nav, Wake Lock API)
- **Hybrid feeds (2026-04-01)**: Discover merges 3 feeds (whats-hot + hot-classic + with-friends); Following merges 3 feeds (timeline + best-of-follows + for-you); Gallery merges 4; Reader merges 3 (+ verified-news); TV merges 3 (+ thevids). NSFW filtering on all.
- **App Store promotion (2026-03-31)**: Smart App Banner meta tag; auth footer + settings link to iOS App Store; GitHub repo link removed from UI
- **Sidebar (2026-03-31)**: Reordered to match iOS (Post, Home, Search, Notifications, Messages, Gallery, TV, Stream, Reader, Analytics, Constellation, Timeline); icons updated to match iOS SF Symbols

### Next for Web

- **M17**: Text Shot Builder — Canvas-based editor: background, font, alignment → PNG attached to compose
- **M18**: Post Collections + Export — Bookmark posts → named collections → export as image strip or JSON
- **M23**: RSS/News Contextual Sidebar — CORS-friendly RSS feeds (BBC, Reuters, AP, NPR) → keyword-matched "In the news" panel in search

---

## iOS App Status

**All primary views implemented.** App is live on the App Store (v1.26).
App Store: https://apps.apple.com/us/app/bsky-dreams/id6760909675

### Completed

- Auth: Keychain session, JWT refresh on cold start + foreground, proactive 1-hour refresh window
- Feed: Following + Discover tabs, infinite scroll, PTR, seen-post dedup (SwiftData)
- Compose: rich text (byte-accurate facets), images (up to 4), GIF picker, link preview, post settings, @mention autocomplete; inline reply; quote post
- Conversation view: depth-colored left border, depth ≥ 4 → "Continue this conversation →", NavigationPath routing; all "Thread" labels renamed to "Conversation"; ancestor posts no longer dimmed (removed `.opacity(0.8)`)
- Profile: feed, follow/unfollow, report
- Search: neubrutalist toggle buttons (not segmented controls), advanced filters (author, date range, language), hide adult content, saved channels with rename/delete via contextMenu; channel tap from sidebar triggers search even when SearchView is already visible (`onAppear` checks `pendingChannelQuery`)
- Notifications: type-coded rows, unread badge, tap navigation (follow→profile, like/repost→subject post, reply/mention/quote→notification post); `NotificationRecord.subject` omitted from Codable to prevent typeMismatch decoding failures
- DMs: NavigationStack + NavigationLink (not NavigationSplitView), empty state with "Start New Conversation" CTA, new conversation handle search, 30s chat polling, message bubbles
- Gallery: card layout (GalleryCardView) — full-width image, alt text overlay, author strip, reply count / repost / like actions; tap image → LightboxView (fullScreenCover(item:) pattern); tap metadata section → conversation; multi-image grid cells constrained to (maxWidth: .infinity, height: 140) before clipping to prevent scaledToFill overflow; seen posts marked in SwiftData on appear
- Lightbox (rewritten 2026-03-23): UIScrollView-based per-page zoom (ZoomScrollView + ZoomScrollImage UIViewRepresentable) with pinch-to-zoom anchored at centroid, single-finger pan when zoomed; direction-locked DragGesture for left/right paging and up/down dismiss; animated dot indicator; scrollable alt text; off-main image decode via Task.detached; download to camera roll
- TV: topic selector splash, single shared AVPlayer, `containerRelativeFrame` paging (not GeometryReader), mute/unmute swap on item change to prevent audio pop, 2× speed on hold, adult filter, "back to topics" button
- Reader: URL filtering, article cards, Direct / Readable / Archive mode toggle; Readable: URLSession + WKWebView extraction; seen posts marked in SwiftData on appear; `ArticleReaderSheet.post` made optional so it can be called from `LinkCardView` in feed
- Settings: accent color picker (7 colors) + automatic app icon swap via `setAlternateIconName`; default feed tab; seen posts count + clear
- Design: Neubrutalism + Memphis, circular avatars, system font for post content; POST toolbar button wrapped in `.background(Color.nbWhite)` to eliminate iOS default rounded-rect highlight; sidebar header uses VStack + `.background()` (not ZStack with Color sibling) to prevent header from expanding to fill entire sidebar height
- Compose: URL auto-detection via NSDataDetector triggers link preview; OG metadata fetched directly via URLSession (no CORS proxy needed on iOS)
- Link cards: compact horizontal layout (72pt square thumbnail + domain/title); tap opens `ArticleReaderSheet` in Readable mode instead of Safari
- Quoted posts: images from quoted posts rendered inline (single image 100pt, multi-image strip 80pt); external card links shown as domain chip
- App icons: 7 color variants (Blue/Coral/Lime/Purple/Pink/Orange/Teal) generated via SF Symbol cloud.fill; icon auto-switches when accent color changes in Settings
- Mute/Block: `muteActor`/`unmuteActor` in PostCardView and ProfileView; `blockActor` creates `app.bsky.graph.block` record
- Report: `app.bsky.moderation.createReport` for posts and accounts; ReportSheet with 6 reason options
- Quote post: global sheet on MainAppView observes `store.showComposeSheet`; `store.composeQuote` passed to ComposeView
- Klipy: trending endpoint; thumb URL; "Powered by KLIPY" attribution
- Dynamic accent color: `Color.nbAccent` reads UserDefaults; `AppStore.setAccentColor()` persists
- URLCache: configured at app launch with 100 MB memory / 500 MB disk to persist AsyncImage/URLSession responses
- LightboxView: AsyncImage given `.frame(maxWidth: .infinity, maxHeight: .infinity)` inside TabView so images fill the page
- New Message: error feedback, loading state, `dismiss()` after convo creation
- Constellation view: full physics simulation (D3-equivalent force/repulsion/spring/gravity), all 4 gestures (tap to select, single-finger node drag, two-finger pinch zoom, background pan), `UIGestureRecognizer` subclass (`_ConstellationGestureRecognizer`) for immediate touch delivery; `BskyDreams-iOS/ConstellationTests/` SPM package with 43 passing unit tests; root bug was `GraphNode.Equatable` comparing only `id`, causing simulation position updates to not trigger re-renders (visual frozen, hit test used current positions → all gestures missed)
- Share Extension: saves image/video/URL/text to App Group container + UserDefaults; opens main app via UIApplication responder chain (`open:options:completionHandler:` with nil options); `LSApplicationQueriesSchemes` required in extension Info.plist; `processPendingShare()` also called on `willEnterForegroundNotification` as belt-and-suspenders fallback
- Lightbox: save-to-camera-roll with PHPhotoLibrary auth pre-check + Settings deep-link alert; pan after zoom via `.simultaneousGesture(DragGesture)` guarded on `imageScale > 1.01`
- Timeline: auto-loads current user's profile on first open (`.onAppear` check for empty query + `auth.session?.handle`)
- Sidebar channels: fixed SwiftData lightweight migration crash — `SavedSearch.channelType` must have inline default `= "search"` at property declaration level
- Stream view (2026-03-31): landscape slideshow with configurable duration, content filter, background colors; conversation overlay via fullScreenCover (same pattern as article reader); reply button opens ThreadView without leaving stream
- Hybrid feeds (2026-04-01): Discover (whats-hot + hot-classic + with-friends); Following (timeline + best-of-follows + for-you); Gallery (+ followpics + art-new); TV (+ thevids); Reader (+ verified-news). All sorted by HN-style trending score. NSFW filtering via `PostView.isAdultContent`
- Notifications fix (2026-03-31): kebab-case raw values for `starterpack-joined`, `like-via-repost`, `repost-via-repost`; navigation goes to post not profile; grouping includes via-repost variants
- Inline video fullscreen (2026-03-31): AVPlayerViewController via UIKit presentation (not SwiftUI fullScreenCover); fresh player at current seek position; `.transaction { $0.animation = nil }` on VideoThumbnailView prevents animation crash
- Reader improvements (2026-04-01): seen-post filtering with auto-pagination (up to 5 extra pages); `articlesWithCards` computed property prevents invisible rows; share sheet via UIKit with custom OpenInSafariActivity
- Image resize shared (2026-04-01): `ComposeImage.resizeImageData` static method used by both ComposeView and InlineReplyView
- Feed scroll smoothness (2026-03-31): in-memory seenURISet cache in ReaderView (same as FeedView); image pre-warming; earlier pagination trigger (last 5 not last 1)
- World-class polish update (2026-06-17): foundation + per-view sweep porting learnings from sibling apps (BOBA-Playbook, Archive-Watch). See @docs/iOS-DESIGN.md (binding design contract) and DECISIONS.md 2026-06-17 entries. Foundation: Dynamic Type via `relativeTo:` custom fonts (`.syne`/`.inter`); `Color.nbAccentLegible` (dark-mode-lightened accent for foregrounds); `Haptics` semantic taxonomy (selection / light-medium-heavy / success-warning-error); universal feature-state primitives `NBEmptyState` / `NBErrorBanner` (coral, retry/dismiss) / `NBOfflineBanner` (lime) / `NBSkeleton`+`NBSkeletonPostRow` (reduce-motion aware); first-run hints `HintsManager` + `HintBanner` (cyan/blue, dismiss-permanent per-device); `NBImageLoader`+`CachedImage` (URL-bound cached async image, shared NSCache 600/60MB, off-main ImageIO downsample, post-await URL re-check kills recycled-cell wrong-image, `clearCache()`); `NetworkMonitor` (`NWPathMonitor`, `@Observable`, `@Environment`-injected) driving offline banners; SwiftData container graceful on-disk → in-memory fallback (corrupt store can't crash launch); fixed latent background notification check using camelCase `likeViaRepost`/`repostViaRepost` (never matched kebab-case API) — same class as the documented foreground fix; branded `UILaunchScreen` Info.plist dict using asset-catalog `LaunchBackground` (blue #0047FF) + `LaunchCloud` imageset (never coral). BUILD LESSON: synchronized-group new-file gotcha — brand-new `.swift` files intermittently not picked up; mitigation: inline new types into already-compiled files (`AppStore.swift`, `DesignSystem.swift`); new `.xcassets` entries are picked up by `actool` regardless. Per-view: surfaced every previously-swallowed `catch {}` (Profile ×6, Notifications, Search, Stream, Constellation, DMs/Chat, Compose) via `NBErrorBanner` + `Haptics.error`; `NBEmptyState` across Profile/Search/Notifications/Gallery/Thread/Timeline/Analytics; intentional haptics; Reduce Motion honored in Constellation/Stream/TV decorative animations (NOT physics sim or gesture infra); `CachedImage` adopted in ImageGridView + GalleryView cells; offline banner + first-load skeleton + first-run HintBanners in Feed/Reader; VoiceOver labels on icon-only buttons throughout. Settings: "Clear Image Cache", "Notification Settings" (deep-links to system Settings), and a "TIPS & HINTS" section (master Show-Tips toggle + Reset All Tips).

### Next for iOS

- **Analytics view**: implement Canvas-equivalent charts using Swift Charts or Canvas (now has `NBEmptyState` for the no-data path; charts still TBD)
- **Profile interaction graph**: port from web (fetch author feed, tally reply targets, show top 6 chips)
- **Reader read-state persistence**: persist `readURLs` to SwiftData so articles stay dimmed across sessions
- **Cross-device channel/prefs sync**: read/write `app.bsky-dreams.prefs` via AT Protocol repo
- **Scroll position on back navigation**: investigate `.scrollPosition(id:)` (iOS 17) to save/restore feed position

### Done in the 2026-06-17 world-class polish update (was here)

- ~~Dynamic Type~~ — DONE: custom fonts scale via `relativeTo:` in `.syne()`/`.inter()`
- ~~Accessibility (VoiceOver labels on icon-only buttons)~~ — DONE: applied throughout
- ~~Offline handling~~ — DONE: `NetworkMonitor` + `NBOfflineBanner` (graceful degrade, keep cached content)
- ~~Consistent loading/empty/error states~~ — DONE: `NBSkeleton` / `NBEmptyState` / `NBErrorBanner` four-states rule
- ~~Reduce Motion for decorative animations~~ — DONE: honored in Constellation/Stream/TV (not physics/gesture infra)
- ~~Dark-mode link/icon legibility~~ — DONE: `Color.nbAccentLegible`
- ~~Branded launch screen~~ — DONE: `UILaunchScreen` dict (blue, never coral)

---

## Open Questions

### Web
1. Blob limit 1 MB — `resizeImageFile()` handles it but loses GIF animation
2. Notifications: no polling; stale until user navigates to view
3. Klipy not yet on Bluesky animated-GIF allowlist (issue #9728) — no code change needed when added

### iOS
1. Reader `readURLs` (`@State`) is separate from SwiftData `SeenPost` — needs reconciliation for persistent read-state display
2. `app.bsky-dreams.prefs` sync not yet wired — iOS uses SwiftData `CachedPreferences` only
3. Analytics view exists as a shell — Swift Charts implementation needed
4. Notifications badge count from `refreshBadges()` only counts unread in first page (limit: 1) — may undercount
5. Block: no unblock UI from post card (would need block record URI)

### Both
1. AT Protocol OAuth: when it stabilizes, app-password auth should be revisited
2. Firehose/WebSocket: real-time notifications and DMs are architecturally blocked without a server
