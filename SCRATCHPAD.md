# Project Scratchpad — Bsky Dreams

## Current Date: 2026-03-17

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
| Gallery (image posts, card layout, like/repost, lightbox) | ✅ | ✅ | iOS: tap image → lightbox; tap metadata → conversation |
| TV (TikTok-style video feed, topic selector) | ✅ | ✅ | |
| TV: 2× speed on hold | ✅ | ✅ | |
| TV: adult content filter | ✅ | ✅ | |
| Reader (article cards, Direct/Readable/Archive modes) | ✅ | ✅ | |
| Reader: seen tracking + mark-read | ✅ | ✅ | iOS: SwiftData SeenPost inserted on article appear; readURLs still in-session for opacity only |
| Reader: progress bar during Readable extraction | ✅ | ✅ | |
| Analytics dashboard (post stats, heatmap) | ✅ | ⏳ | iOS view exists, content TBD |
| Network Constellation (D3 graph) | ✅ | ⏳ | iOS view exists, content TBD |
| Timeline scrubber (horizontal, time-offset) | ✅ | ⏳ | |
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

### Next for Web

- **M17**: Text Shot Builder — Canvas-based editor: background, font, alignment → PNG attached to compose
- **M18**: Post Collections + Export — Bookmark posts → named collections → export as image strip or JSON
- **M23**: RSS/News Contextual Sidebar — CORS-friendly RSS feeds (BBC, Reuters, AP, NPR) → keyword-matched "In the news" panel in search

---

## iOS App Status

**All primary views implemented.** App is feature-complete for daily use.
Four rounds of polish fixes applied (2026-03-16 through 2026-03-17).

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

### Next for iOS

- **Reader read-state persistence**: `readURLs` (in-session opacity indicator) should be persisted to SwiftData so articles stay dimmed across sessions — SeenPost already inserted, but `readURLs` set is separate
- **Analytics view**: implement Canvas-equivalent charts using Swift Charts or Canvas
- **Constellation view**: implement D3-equivalent force graph (likely using SwiftUI Canvas or a lightweight graph layout)
- **Profile interaction graph**: port from web (fetch author feed, tally reply targets, show top 6 chips)
- **Cross-device channel/prefs sync**: read/write `app.bsky-dreams.prefs` via AT Protocol repo (seen-posts sync is done; channels and UI prefs still SwiftData only)
- **Timeline scrubber**: port horizontal time-offset scrubber to Search view
- **Scroll position on back navigation**: investigate using `.scrollPosition(id:)` (iOS 17) to save/restore feed position when popping ThreadView back to FeedView

---

## Open Questions

### Web
1. `isAdultPost()` uses label-string check; `com.atproto.label.*` offers finer control
2. Blob limit 1 MB — `resizeImageFile()` handles it but loses GIF animation
3. Notifications: no polling; stale until user navigates to view
4. `app.bsky-dreams.prefs` is publicly readable (non-sensitive prefs only)
5. Klipy not yet on Bluesky animated-GIF allowlist (issue #9728) — no code change needed when added

### iOS
1. Reader `readURLs` (`@State`) drives in-session opacity but is separate from SwiftData `SeenPost` inserts — the two need to be reconciled for fully persistent read-state display
2. `app.bsky-dreams.prefs` sync not yet wired — iOS uses SwiftData `CachedPreferences` only; accent color chosen on device is not synced to web
3. Analytics and Constellation views exist as shells — implementation needed before parity is achieved
4. Klipy same allowlist issue as web — no code change needed when resolved
5. Notifications badge count from `refreshBadges()` only counts unread in first page (limit: 1) — may undercount
6. Accent color: `Color.nbAccent` static var reads UserDefaults on each call — views re-render with new color on next navigation, but not instantaneously mid-session; full live preview would require environment injection across all views
7. Block: no unblock UI from post card (would need block record URI); users can unblock from profile page if block record is exposed in `viewer.blocking` AT URI (not currently decoded)
8. Sidebar header safe area: uses `UIApplication.shared.connectedScenes...safeAreaInsets.top` for Dynamic Island padding — relies on UIKit window being ready; consider migrating to `GeometryReader.safeAreaInsets.top` inside the sidebar for a purely SwiftUI solution

### Both
1. AT Protocol OAuth: when it stabilizes, app-password auth should be revisited
2. Firehose/WebSocket: real-time notifications and DMs are architecturally blocked without a server — revisit if a lightweight proxy becomes viable
