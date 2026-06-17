# Bsky Dreams — Architecture & Technology Decisions

Entries are ordered roughly by date. Superseded entries have been removed.
Platform is noted where a decision is specific to one; unlabeled entries
apply to both or to the project as a whole.

---

## [SHARED] App Passwords for Authentication
*2026-02-20*

App passwords only — recommended by BlueSky for third-party clients, independently revocable, scoped permissions. AT Protocol OAuth not yet stable. Trade-off: one extra setup step, mitigated by in-app instructions.

---

## [SHARED] Blobs Uploaded Before Post Creation
*2026-02-21*

All blobs uploaded before `createPost`. AT Protocol requires blob CIDs at post-creation time — no post-hoc attachment. Trade-off: orphaned blobs if `createPost` fails (GC'd eventually).

---

## [SHARED] AT Protocol Facets — Byte-Accurate UTF-8 Slicing
*2026-02-20*

Post text rendered via `record.facets` using byte-offset slicing. AT Protocol facets use byte offsets, not character indices — plain character indexing is wrong for non-ASCII. Web: `TextEncoder`/`TextDecoder`. iOS: `Array(text.utf8)` slicing.

---

## [SHARED] Notifications — Load-on-Demand, No Polling
*2026-02-21*

Notifications load on first navigation to the view. No server, no Firehose. Polling rejected (battery/bandwidth). Trade-off: badge may be stale until user navigates to the view.

---

## [SHARED] Discover Feed — `whats-hot`, Default Tab
*2026-02-24*

"Discover" tab uses `at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot` via `getFeed`. Two-tab toggle (Following / Discover). Provides a populated feed on first load. Trade-off: feed content policy controlled by BlueSky — update the constant if the URI changes.

---

## [SHARED] Direct Messages — Native Chat API
*2026-02-21*

`chat.bsky.convo.*` at `https://api.bsky.chat/xrpc/` with the same `accessJwt`. Only zero-cost, standards-compliant option. Custom AT Protocol repo messaging (not real-time/encrypted) and third-party APIs both rejected. Monitor AT Protocol changelog; docs are sparse.

---

## [SHARED] Like / Repost — Optimistic Update with Rollback
*2026-02-24*

UI updates applied before the API call; on error a snapshot restores prior state; button disabled during request. Non-optimistic updates feel laggy; no rollback left UI desynced on failure.

---

## [SHARED] Timestamp — Relative Time Badge, Links to bsky.app
*2026-02-24*

Relative-time display links to `https://bsky.app/profile/{handle}/post/{rkey}`. Gives users an escape hatch to the official app for unsupported actions. Web: `<a>` tag. iOS: tappable `Button` in author header that calls `UIApplication.shared.open`.

---

## [SHARED] GIF Provider — Klipy as External Embed
*2026-02-25*

GIFs posted as `app.bsky.embed.external` with the Klipy CDN URL; thumbnail uploaded as blob. BlueSky's AppView CDN transcodes blobs to JPEG, stripping animation — CDN URL reference is the only way to preserve animation (same approach as Tenor/Giphy in the native app). Trade-off: Klipy not yet on BlueSky's animated-GIF allowlist (issue #9728); native app shows thumbnail only. No code change needed when allowlist is updated.

---

## [SHARED] Seen-Posts Deduplication — Simple URI Map + Session Bypass
*2026-02-24 (updated 2026-03-17)*

Seen posts are filtered based on a simple URI membership check (not an engagement threshold). The engagement-threshold idea (≥50 likes/reposts to re-show) was specced but never shipped on either platform; iOS previously had it and has been brought into parity with web. Both platforms use a session-level **bypass flag** (`feedSeenBypass`) so users can tap "N posts already seen — show anyway" to see everything for the rest of the session. 7-day rolling window; posts pruned on each save. Web: `Map` in localStorage (5,000-entry FIFO cap). iOS: SwiftData `SeenPost` records. Both platforms now sync via AT Protocol repo.

---

## [SHARED] Thread Depth Limit — Depth 4
*2026-02-21 (lowered from 8 to 4)*

Thread rendering stops at depth ≥ 4, replaced with a "Continue this thread →" link/button. At ~12px indent per level, depth 5+ causes horizontal overflow on 375px screens; depth 4 leaves ~315px. Revisit if users find 4 levels too shallow.

---

## [SHARED] Quoted Posts — Compact Preview Card
*2026-02-21*

Quoted posts render as a compact card (avatar, name, handle, truncated text). Nested full post cards are too heavy; ignoring record embeds caused silent data loss. Trade-off: no facet rendering in quoted card preview.

---

## [SHARED] Feed Reply Context — Parent Preview
*2026-02-21*

Replies in the feed show a compact parent preview above the reply card. Parent is already in the timeline response — no extra fetch needed. Preview omitted if parent is `notFoundPost` or `blockedPost`.

---

## [SHARED] Network Constellation — Search-Seeded
*2026-02-21*

Constellation seeded from a user-entered search term, not the follow graph. Search-seeded graph avoids mapping the user's social graph without intent. Cap at 150 nodes to avoid performance issues. Web uses D3.js v7 served locally. iOS implementation TBD.

---

## [SHARED] Deferred Milestones — Paid API Dependencies
*2026-02-21*

Fact-checking (M27a), political bias (M27b), and AI content detection (M27c) deferred — each requires a paid API. Partial zero-cost paths exist. Revisit if API keys are funded or free alternatives emerge.

---

## [WEB] No Framework — Vanilla HTML/CSS/JS
*2026-02-20*

Plain HTML/CSS/JS, no build step. GitHub Pages serves static files; framework abstractions cost more than they save at this scale. React/Vue/Svelte all rejected for requiring a build step. Trade-off: manual DOM manipulation, no reactive state. Revisit if component count exceeds ~20 or DOM work becomes error-prone.

---

## [WEB] AT Protocol HTTP API via fetch (no SDK)
*2026-02-20*

Direct `fetch` against XRPC endpoints. `@atproto/api` requires a bundler; CDN build is unstable and bloated. Trade-off: manual request construction, must track lexicon changes. Token refresh in `auth.js`. Revisit if Firehose/WebSocket or complex record operations are needed.

---

## [WEB] localStorage for Session Persistence
*2026-02-20*

Session (`accessJwt`, `refreshJwt`, handle, DID) stored under `bsky_session`. No server available; localStorage survives reloads and restarts; credentials only sent to bsky.social. XSS risk mitigated by no third-party scripts, strict CSP, HTTPS. Revisit if any third-party script is loaded.

---

## [WEB] GitHub Pages Root Deployment
*2026-02-20*

Deploy from root `/` of `main`. No subdirectory prefix to manage. Trade-off: main must always be deployable — dev on feature branches only. Switch to a `gh-pages` Actions workflow if a build step is introduced.

---

## [WEB] Third-Party Libraries — Served Locally (no CDN)
*2026-02-20 – 2026-03-10*

All third-party JS (`hls.min.js`, `d3.min.js`, `Readability.js`) served from `/js/`. CSP `script-src 'self'` blocks CDN scripts. Trade-off: manual updates for security fixes; HLS.js adds 413 KB, D3 ~270 KB, Readability ~80 KB.

---

## [WEB] CSP connect-src Widened to `*`
*2026-02-20*

HLS.js fetches video manifests via `fetch()`; BlueSky's CDN redirects to Cloudflare edge nodes with unpredictable hostnames. Explicit allowlist is too fragile. Risk is low: `script-src 'self'` still blocks foreign scripts. Revisit if a security audit demands tighter egress.

---

## [WEB] History API Routing (pushState / popstate)
*2026-02-20*

Browser History API for Back/Forward across view transitions. Hash routing produces ugly URLs with no Forward; a router library is overkill. Trade-off: state lost on hard refresh.

---

## [WEB] URL Routing — Query Parameters
*2026-02-21*

`?view=post&uri=...` style routing. GitHub Pages can't rewrite clean paths. Scheme: Thread `?view=post&uri=...&handle=...`, Profile `?view=profile&actor=...`, Search `?q=...&filter=posts`. `init()` parses `window.location.search` after session loads. bsky.app URLs auto-converted to AT URIs via `API.resolvePostUrl()`.

---

## [WEB] CORS — No Proxy for bsky.social
*2026-02-20*

Direct `fetch` to `bsky.social` and `video.bsky.app` — both serve `Access-Control-Allow-Origin: *`. Revisit if a CORS error appears in the console.

---

## [WEB] Cross-Device Prefs — AT Protocol Repo
*2026-02-21*

Preferences stored as JSON in `app.bsky-dreams.prefs` / rkey `self` via `putRecord`/`getRecord`; falls back to localStorage. The PDS is effectively a user-owned key-value store. Trade-off: records are publicly readable — non-sensitive prefs only, never secrets.

---

## [WEB] Sidebar — Always-Open Desktop, Drawer Mobile
*2026-02-25 (finalized M43)*

`#channels-sidebar` holds all navigation. Desktop (≥768px): always visible, top bar hidden. Mobile: slide-in drawer via hamburger. Top bar disappears on desktop; breadcrumb context via sidebar active state only.

---

## [WEB] Channel Unread Checking — Once Per Session
*2026-02-21*

`checkChannelUnreads()` runs once after login, fetching the latest 5 posts per channel with 700ms spacing. Per-channel polling and Firehose both rejected. Trade-off: badges stale later in the session.

---

## [WEB] TV — Two-Slot Slide System + Dual-Feed Seeding
*2026-02-24*

Two `position: absolute` video containers (`tv-slide-a/b`) swap roles per transition, enabling simultaneous outgoing/incoming `translateY` animations. Single `<video>` can't animate out while a new one animates in; dual seeding overcomes video sparsity in a single feed. Trade-off: two HLS instances live simultaneously.

---

## [WEB] TV — Splash Screen for Audio Autoplay
*2026-02-21*

"▶ Start TV" button required before any video plays. Browsers block audio autoplay without a user gesture. Auto-play muted with an unmute button was rejected as inconsistent with the "TV" metaphor.

---

## [WEB] iOS Safari PWA — `visibilitychange` JWT Refresh
*2026-02-24*

`visibilitychange` listener checks `accessJwt` expiry on every foreground. Proactively refreshes if within 15 minutes of expiry. Safari PWA suspends JS timers while backgrounded — `setInterval` and Service Worker sync both rejected as unreliable.

---

## [WEB] PTR Resistance — Two-Stage Threshold
*2026-02-24 (reduced from 96px to 48px in M65)*

Pull-to-refresh requires ≥ 48px drag plus 400ms hold before `ptrReadyToRelease` is true. Hold timer prevents accidental triggers from fast scrolls.

---

## [WEB] PTR Indicator — Fixed Position, Shared Across Views
*2026-03-10*

`#ptr-indicator` is `position: fixed; top: -52px`, sibling to all view sections. JS uses `style.top` (not `style.marginTop`). Previously lived inside `#view-feed .view-inner` and was invisible when other views were active. Hidden on desktop via `@media (min-width: 768px)`.

---

## [WEB] Mention Links — DID in Data Attribute + Event Delegation
*2026-02-24*

Mention facets store the DID in `data-mention-did` on the `<span>`. Listeners wired via `querySelectorAll('[data-mention-did]')` inside `buildPostCard()` after `innerHTML` is set. `renderPostText()` returns an HTML string so direct listener attachment during construction isn't possible.

---

## [WEB] Elastic Overscroll Suppression
*2026-02-24*

`overscroll-behavior: none` on `.view`. iOS Safari and Android Chrome rubber-banded inside `.view`. Intentional suppression — the app implements its own PTR gesture.

---

## [WEB] OG Link Preview — allorigins.win Proxy
*2026-02-25*

OG metadata fetched via `https://api.allorigins.win/get?url=…`. Thumbnail uploaded as a blob at submit time so native Bluesky renders a rich card. Direct `fetch` blocked by CORS. Trade-off: allorigins.win has no SLA; preview silently skips on failure.

---

## [WEB] Thread Gate and Post Gate via putRecord
*2026-02-25*

After `createPost`, non-default restrictions create `app.bsky.feed.threadgate` and/or `app.bsky.feed.postgate` records with rkey matching the post's rkey. Trade-off: two extra API calls; silent failure leaves post published without restrictions (acceptable).

---

## [WEB] Scroll-Based Seen Marking — Full-Viewport IntersectionObserver
*2026-02-25*

`IntersectionObserver` with `rootMargin: '0px'` and `threshold: 0`. Marks seen when `isIntersecting === false` AND `boundingClientRect.top < 0`.

---

## [WEB] Analytics Charts — Native Canvas API
*2026-03-08*

M22 charts use the browser Canvas 2D API. Chart.js blocked by CSP; locally-bundled Chart.js too large; D3.js overkill for simple charts. Trade-off: verbose custom rendering, manual ARIA labels, no animations.

---

## [WEB] Timeline Scrubber — Fractional Time Offset + 220px Minimum Step
*2026-03-08*

Cards positioned absolutely using `(postMs - firstMs) / spanMs`. Minimum 220px step prevents overlap in dense clusters. Trade-off: visual position may not perfectly reflect exact time in very dense clusters.

---

## [WEB] Timeline Scrubber — MutationObserver Toggle Visibility
*2026-03-08*

"List / Timeline" toggle appears only after a successful post search, detected via `MutationObserver` on `#search-results`. Avoids modifying the async search handler's control flow.

---

## [WEB] Reader View — Three-Proxy CORS Fallback Chain
*2026-03-10*

Article HTML fetched via **codetabs.com → corsproxy.io → allorigins.win**, each with 18s `AbortController` timeout. allorigins.win times out on large pages; codetabs.com is most reliable. Trade-off: up to 54 seconds before all three fail; users see live per-proxy progress.

---

## [WEB] Lightbox Carousel — Shared Array, startIndex
*2026-02-21*

`openLightbox(images, startIndex)` takes an `{src, alt}[]` array. `buildImageGrid` passes a shared `lightboxPayload` so all post images are browsable from any thumbnail.

---

## [WEB] Adaptive Image Sizing
*2026-02-21*

Single images: `object-fit: contain`, `max-height: 480px`. Grids (2–4): fixed-height crop (180px / 220px desktop). Trade-off: wide panoramas may pillarbox.

---

## [WEB] Inline Reply Compose — Context-Preserving
*2026-02-21*

`expandInlineReply(postCard, post)` inserts a compose box directly after the target card. One box at a time; opening a second closes the first. Trade-off: DOM rebuild on successful post closes the box (acceptable).

---

## [iOS] SwiftUI + @Observable + SwiftData
*2026-03-16*

SwiftUI for all UI. `@Observable` (iOS 17 macro) for `AuthManager` and `AppStore` — passed via `@Environment`. SwiftData for local persistence (`SeenPost`, `SavedSearch`, `CachedPreferences`). UIKit only where SwiftUI lacks a native equivalent (WKWebView, AVPlayerLayer, UIActivityViewController). Trade-off: iOS 17+ minimum deployment target.

---

## [iOS] Keychain for Session Persistence
*2026-03-16*

Session (`accessJwt`, `refreshJwt`, handle, DID) stored in Keychain under `kSecAttrAccessibleAfterFirstUnlock`. Survives app restarts and device lock. `UserDefaults` rejected — not encrypted, cleared on reinstall. `KeychainManager` handles SecItemAdd/SecItemUpdate/SecItemDelete/SecItemCopyMatching. On cold start, `AuthManager.refreshIfNeeded()` is called before any API call — extends the refresh window to 1 hour to avoid expiry races.

---

## [iOS] NavigationStack + NavigationPath for Routing
*2026-03-16*

Single `NavigationStack(path: Bindable(store).navigationPath)` at the app root. Push destinations as `Hashable` structs: `PostDestination(uri:post:)`, `ProfileDestination(actor:)`, `HashtagDestination(tag:)`. `PostDestination.post` is optional so notification taps (which have only a URI) work without a prefetched `PostView`. `NavigationSplitView` was used for DMs but collapsed poorly on compact iPhone — replaced with `NavigationStack` + `NavigationLink`.

---

## [iOS] Circular Avatars
*2026-03-16*

`AvatarView` uses `.clipShape(.circle)` + `Circle().strokeBorder(...)`. The web app uses square neubrutalist avatars; iOS uses circles. Rationale: square avatars with thick borders look heavy in compact SwiftUI lists; circles match native iOS conventions without abandoning the neubrutalist design elsewhere. This is an intentional platform divergence.

---

## [iOS] RichTextView — System Font for Emoji Fallback
*2026-03-16*

`RichTextView` uses `.system(size: 15)` as its default font instead of `.inter(15)`. Custom fonts loaded from app bundle do not include emoji or many Unicode characters; iOS does not automatically fall back to the system emoji font when a custom font is applied to an `AttributedString`. Using `.system(size:)` gives full emoji/Unicode support. UI chrome (buttons, labels, headers) still uses Syne/Inter.

---

## [iOS] TV — Single Shared AVPlayer + mute/unmute Swap
*2026-03-16*

One `AVPlayer` instance per TV session. On page change, `replaceCurrentItem` is called; player is briefly muted (400ms) to hide the audio pop during buffer prime, then restored to the user's mute state. Multiple concurrent `AVPlayer` instances caused audio overlap on rapid swipes; muting on swap is inaudible in practice.

---

## [iOS] TV — containerRelativeFrame for Full-Screen Paging
*2026-03-16*

`TVVideoCell` uses `.containerRelativeFrame([.horizontal, .vertical])` instead of reading a `GeometryReader` frame. Inside a `NavigationStack`, the `GeometryReader` value was unreliable (included or excluded navigation bar height unpredictably). `containerRelativeFrame` always reports the correct viewport size relative to the enclosing scroll container.

---

## [iOS] Reader — URLSession Fetch + Off-Screen WKWebView Extraction
*2026-03-16*

Readable mode: `URLSession.shared.data(for:)` with iPhone User-Agent fetches the HTML directly (no CORS proxy needed on iOS). The HTML is loaded into an off-screen `WKWebView` so JS can query the DOM with CSS selectors (article, main, .entry-content, etc.) and extract article body. Three-proxy chain is web-only.

---

## [iOS] Reader — Strip External Resources Before Extractor Load
*2026-03-16*

Before loading fetched HTML into the extractor WKWebView, all `<img>`, `<script>`, `<link>`, `<iframe>`, `<video>`, `<audio>`, `<source>`, `<picture>`, and `<style>` tags are removed via NSRegularExpression. This prevents the extractor from making any network requests, eliminating WEBP decoding errors, sub-frame SSL failures, and WKWebView process churn. The extractor only needs DOM structure; all resource URLs are irrelevant to text extraction.

---

## [iOS] Notification Tap Navigation
*2026-03-16*

`NotificationRowView` implements `navigateFromNotification()` based on reason type: follow → profile, like/repost → `reasonSubject` URI (the post that was liked/reposted), reply/mention/quote → notification's own URI. `BskyNotification.NotificationRecord.subject` field is intentionally omitted from the Codable model — its type varies (StrongRef for likes, plain DID string for follows) causing `typeMismatch` decoding errors that silently fail the entire notifications array.

---

## [iOS] Gallery — Card Layout with Actions
*2026-03-16*

Gallery shows full-card layout (`GalleryCardView`): full-width single image or 2-column grid for multiple images, alt text overlay on single images, author strip (circular avatar, name, @handle, relative time), and inline reply count / repost / like action row. The earlier 3-column Instagram-style grid was replaced because it lacked context (no author, no alt text, no actions) and didn't match the web app's card-first approach.

---

## [iOS] Persistent Translucent Navigation Bar
*2026-03-16*

All views apply `.toolbarBackground(.regularMaterial, for: .navigationBar)` and `.toolbarBackground(.visible, for: .navigationBar)`. Without these, the default SwiftUI behavior allows content to scroll behind the transparent navigation bar, making toolbar icons unreadable over dark or image content. Applied at the `DetailView` level (root of the navigation stack) and repeated on individual views that need it.

---

## [iOS] Sidebar Header — VStack + .background(), Not ZStack + Color
*2026-03-17*

`sidebarHeader` uses a `VStack` with `.background(Color.nbWhite)` rather than a `ZStack` with `Color.nbWhite` as a sibling. `Color` and `DiagonalStripeBackground` (which wraps a `GeometryReader`) are both layout-greedy — when used as `ZStack` siblings they cause the ZStack to fill all available height in the parent `VStack`, consuming the entire sidebar. Using `.background()` as a modifier (not a sibling) prevents it from participating in sizing. Every VStack child has a fixed height so the header stays compact.

---

## [iOS] Link Cards — Compact Horizontal Layout, Opens ArticleReaderSheet
*2026-03-17*

`LinkCardView` uses a horizontal layout: 72pt square thumbnail on the left, domain + title on the right. Height is fixed at 72pt. Tapping opens `ArticleReaderSheet` in Readable mode instead of `UIApplication.shared.open` (Safari). `ArticleReaderSheet.post` made optional (`var post: PostView? = nil`) so it can be called from link cards embedded in feed posts without a parent `PostView` reference. Trade-off: reader may fail on non-article URLs (video sites, social links); those still have the "Direct" tab as a fallback.

---

## [iOS] Gallery Lightbox — fullScreenCover(item:) with LightboxPresentation
*2026-03-17*

Gallery image taps use `fullScreenCover(item: $lightboxPresentation)` with a `LightboxPresentation: Identifiable` struct carrying `images` and `startIndex`. The earlier `fullScreenCover(isPresented:)` with separate `@State` vars was unreliable: `GalleryCardView` is a struct and SwiftUI may evaluate the cover content closure before state mutations are visible, producing an empty lightbox. Using `item:` embeds the data directly in the trigger value, guaranteeing it is available when the cover renders.

---

## [iOS] Image Grid Clipping — Constrain Both Dimensions Before .clipped()
*2026-03-17*

Multi-image grid cells in `GalleryCardView` use `.frame(maxWidth: .infinity, minHeight: 140, maxHeight: 140)` before `.clipped()`. Without an explicit width constraint, `scaledToFill()` scales the image to fill only the proposed height (140pt); for a wide landscape image this produces a rendered width far exceeding the column width, overflowing the card edges. Constraining `maxWidth: .infinity` forces the image to fill the column width, and `.clipped()` then clips correctly. The `LazyVGrid` itself also gets `.clipped()` as a second line of defence.

---

## [iOS] URLCache — Large Disk Cache at App Launch
*2026-03-17*

`URLCache.shared` is replaced at app init with `URLCache(memoryCapacity: 100 MB, diskCapacity: 500 MB)`. `AsyncImage` uses `URLSession` under the hood and benefits from this cache, reducing re-fetching of feed images and videos across sessions. Default iOS cache is 512 KB memory / 10 MB disk — far too small for a media-heavy feed app.

---

## [iOS] Seen Post Marking in Gallery and Reader
*2026-03-17*

`GalleryCardView` and `ReaderView` both insert `SeenPost` records into SwiftData when a post's view appears (`.onAppear`). A `seenURIs: Set<String>` guard prevents duplicate inserts within a session. This ensures the home feed deduplication logic treats gallery- and reader-viewed posts as seen, preventing them from re-appearing in the feed.

---

## [iOS] Quoted Posts — Inline Image Rendering
*2026-03-17*

`QuotedPostView` renders images from the quoted post's embed: single image at 100pt height, multi-image horizontal strip at 80pt. External card links (non-GIF) are shown as a domain chip with a link icon. Previously only text was shown, making quote posts appear incomplete when the original was image-only.

---

## [SHARED] Seen-Posts Cross-Device Sync — AT Protocol Repo
*2026-03-17*

Seen-posts are synced across devices using the AT Protocol repo as a key-value store: collection `app.bsky-dreams.seen`, rkey `recent`. Record schema: `{ $type: "app.bsky-dreams.seen", uris: string[], syncedAt: number }`. Only URIs are stored (no engagement data) — the 7-day rolling window keeps the payload small (~75–225 KB typical). Merge strategy: union (cloud + local, never remove). Sync timing: 30-second debounce after each mark-seen, plus an immediate flush when the app goes to background (web: `visibilitychange`; iOS: `scenePhase == .background`). On cold start, cloud record is fetched and merged into local SwiftData before the feed loads. TV watch history participates in the same unified seen-posts record (same collection, same dedup logic). iOS: `ATProtocolClient.getSeenRecord` / `putSeenRecord`; sync coordination in `AppStore.scheduleSeenSync` / `saveSeenToCloud` / `loadSeenFromCloud`.

---

## [iOS] Toolbar POST Button — Plain View + .onTapGesture, Not Button
*2026-03-17*

The POST button in `FeedView` and `ComposeView` toolbars uses a plain `Text` view with `.onTapGesture` rather than a SwiftUI `Button`. When a `Button` is placed inside a `ToolbarItem`, SwiftUI maps it to a `UIBarButtonItem` backed by a `UIButton` with `UIButtonConfiguration` — iOS 15+ uses this to render a rounded rect highlight background that cannot be suppressed via SwiftUI modifiers (`.buttonStyle(.plain)`) or the legacy `UIBarButtonItem.appearance().setBackgroundImage()` API. A plain view (non-Button) results in `UIBarButtonItem(customView: UIView)` which never receives `UIButtonConfiguration` treatment and therefore renders no rounded rect. Accessibility restored via `.accessibilityLabel` + `.accessibilityAddTraits(.isButton)`. `BskyDreamsApp.init()` also sets `UINavigationBarAppearance.buttonAppearance.backgroundEffect = nil` via the `UINavigationBar.appearance()` proxy (correct modern API; legacy `setBackgroundImage` had no effect). Trade-off: no automatic UIKit press-state feedback; the button visually looks identical pressed vs unpressed (acceptable for the neubrutalist style which doesn't use press states).

---

## [iOS] ConstellationView — UIGestureRecognizer Subclass for Touch Capture
*2026-03-18*

Gesture input in `ConstellationView` uses a custom `_ConstellationGestureRecognizer: UIGestureRecognizer` subclass whose `touchesBegan/touchesMoved/touchesEnded` overrides implement all four gesture types (tap, single-finger node drag, two-finger pinch, background pan). The subclass is attached to a `UIView` via `UIViewRepresentable` (`ConstellationGestureCapture`) placed as the frontmost layer of the graph ZStack.

Rejected: SwiftUI `DragGesture`/`TapGesture` — both pass through `_UIHostingView` recognizers with `delaysTouchesBegan = true`, causing gestures to require a "warm-up" before firing reliably. `UIView.touchesBegan` override on a descendant — delayed by the same mechanism. A recognizer subclass's own touch override methods are dispatched by the gesture recognizer system before responder-chain delivery, making them structurally immune to ancestor `delaysTouchesBegan` flags.

The recognizer stays passive (never transitions to `.recognized`; resets to `.failed` at sequence end). `cancelsTouchesInView = false`. `canPrevent`/`canBePrevented` both return `false`. Callbacks pass `view.bounds.size` so callers never need a `GeometryProxy` (which can be stale on first render). `BskyDreams-iOS/ConstellationTests/` SPM package contains 43 unit tests for the `ConstellationTouchRouter` logic, runnable via `swift test`.

---

## [iOS] ConstellationView — GraphNode.Equatable Must Include Position
*2026-03-18*

`GraphNode.Equatable` compares `id AND x AND y`. The original id-only equality caused a silent, complete failure of all gesture hit-testing.

The physics simulation updates `nodes[idx].x/y` every 16ms. SwiftUI uses `Equatable` on `@State` values to skip re-renders when the new value equals the old. With id-only equality: every simulation write appeared identical to the previous state — SwiftUI never re-rendered the graph during simulation. The visual was permanently frozen at the initial circular layout. The hit test read simulation-updated positions from `@State`. Every tap missed by the full distance the physics had moved the nodes (~99pt in testing). Panning worked because `panOffset: CGSize` has correct memberwise equality and its change forced a re-render — which is why all gestures appeared to "work after the first pan."

Fix: `lhs.id == rhs.id && lhs.x == rhs.x && lhs.y == rhs.y`. Each simulation tick now properly invalidates the view. Trade-off: more re-render work per tick, acceptable at 60fps with ~60 nodes. `ForEach` uses `Identifiable` (by `id`) for stable child identity — existing node views are updated in place, not recreated.

---

## [iOS] Share Extension — Opening the Containing App via Responder Chain
*2026-03-19*

To open the containing app from a Share Extension, traverse the UIResponder chain to reach UIApplication and call `open:options:completionHandler:` with `nil` options. UIApplication exists in the extension's process but `UIApplication.shared` is restricted; the responder chain bypasses that restriction.

```swift
let selector = NSSelectorFromString("openURL:options:completionHandler:")
var responder: UIResponder? = self
while let r = responder {
    if r.responds(to: selector) {
        typealias OpenFunc = @convention(c) (AnyObject, Selector, NSURL, NSDictionary?, ((Bool) -> Void)?) -> Void
        let open = unsafeBitCast(r.method(for: selector), to: OpenFunc.self)
        open(r, selector, url as NSURL, nil, nil)
        break
    }
    responder = r.next
}
extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
```

The Share Extension's Info.plist must also declare `LSApplicationQueriesSchemes: [bskydreams]` — without it `extensionContext?.open()` returns `false`.

**All rejected approaches (do not retry):**

| Approach | Result | Reason |
|---|---|---|
| `extensionContext?.open(url)` | Returns `false` | iOS routes through the host app (Photos); Photos can't handle custom URL schemes |
| Responder chain + `openURL:` selector | Force-blocked | Deprecated; iOS logs "needs to migrate to the non-deprecated UIApplication.open" and returns false |
| `open:options:completionHandler:` with `[:]` | Crash | `Swift.__EmptyDictionarySingleton` doesn't respond to `universalLinksOnly` (private UIKit selector) |
| `open:options:completionHandler:` with `NSDictionary()` | Crash | `__NSDictionary0` same problem — UIKit casts options to a private `_UIOpenURLOptions` class |
| `open:options:completionHandler:` with `nil` | **Works** | UIKit skips the options cast entirely |

The main app's `onOpenURL` receives `bskydreams://share` and calls `processPendingShare()`. As a belt-and-suspenders fallback, `processPendingShare()` is also called on `willEnterForegroundNotification` in `MainAppView` so pending shares are never lost if the user manually switches to the app.

---

## [SHARED] Hybrid Feed Architecture — Multi-Source Merging
*2026-04-01*

Both Following and Discover tabs fetch from multiple AT Protocol feed generators in parallel, deduplicate by post URI, and sort by a HN-style trending score: `(likes - 1) / (hours + 2)^1.8`. Secondary feeds fail silently (`try?` / `.catch(() => null)`).

**Discover sources** (3 feeds): Bluesky Discover (`whats-hot`, personalized), What's Hot Classic (`hot-classic`, network-wide pure engagement), Popular With Friends (`with-friends`, social graph trending).

**Following sources** (3 feeds): Chronological timeline (`getTimeline`), Best of Follows (`best-of-follows`, top posts from follows), For You by spacecowboy17 (`for-you`, collaborative filtering).

**Gallery sources** (4 feeds): Timeline + Discover + The 'Gram (`followpics`, all images from follows) + Artists: Trending (`art-new`, trending art by engagement).

**TV sources** (3 feeds): Timeline + Discover + Video (`thevids`, official trending videos).

**Reader sources** (3 feeds): Timeline + Discover + News (`verified-news`, verified news org headlines).

All feed URIs verified live via `getFeedGenerator` before implementation. Trade-off: more API calls per page load, but all run concurrently so wall-clock latency equals the slowest single feed.

---

## [SHARED] NSFW Content Filtering in Feed Views
*2026-04-01*

All feed views (Home, Gallery, Reader) filter posts with adult content labels (`porn`, `sexual`, `nudity`, `graphic-media`, `adult`, `gore`, `nsfw`) during the merge/dedup step. iOS: `PostView.isAdultContent` computed property. Web: shared `_isAdultPost(post)` function. TV retains its own user-toggleable `hideAdult` filter. Search is intentionally unfiltered — users control via the existing "Hide Adult Content" toggle. Rationale: third-party feeds (hot-classic, with-friends, for-you, followpics, art-new) do not apply the same content filtering as Bluesky's personalized Discover feed.

---

## [SHARED] Stream View — Full-Screen Post Slideshow
*2026-03-31*

Web: full-screen slideshow with setup screen (feed source, duration, content filter, background color, toggles) and player (auto-advance timer via `requestAnimationFrame`, progress bar, keyboard navigation, touch swipe, Wake Lock API). No landscape requirement — works at any screen size. iOS: landscape-only via `fullScreenCover`, requires physical device rotation to start. Both: slide types (text, image, combined, link card), per-slide dot navigation, auto-hiding controls after 3s.

---

## [iOS] Stream Conversation — fullScreenCover Overlay
*2026-03-31*

Reply button in StreamView presents ThreadView via `fullScreenCover(item: $conversationPresentation)` with a `StreamConversationPresentation` carrier struct — same pattern as the article reader overlay. Does NOT dismiss the stream or rotate to portrait. User reads/replies in the conversation overlay and taps back to return to the stream. Timer resumes on dismiss if not paused.

---

## [iOS] Inline Video Fullscreen — UIKit Presentation
*2026-03-31*

`VideoThumbnailView` fullscreen button presents `AVPlayerViewController` directly via UIKit `present(_:animated:completion:)`. A fresh `AVPlayer` is created from the same HLS URL at the current seek position (avoids shared-player conflicts with SwiftUI's `VideoPlayer`). The completion handler resumes playback after the presentation animation. Dismissed via AVKit's native Done button. Rejected: SwiftUI `fullScreenCover` wrapping `AVPlayerViewController` — created a double-fullscreen layer with no dismiss path and white borders.

---

## [iOS] VideoPlayer Animation Crash Prevention
*2026-03-31*

`VideoThumbnailView` applies `.transaction { $0.animation = nil }` to block SwiftUI animation propagation into `AVPlayerViewController`. Without this, animated layout changes (e.g. inline reply box opening in ThreadView) crash AVKit because `AVPlayerLayer` does not support CoreAnimation implicit frame animations. This does not affect the video thumbnail or play button — they appear/disappear without animation, which is acceptable.

---

## [iOS] Reader Share Sheet — Custom OpenInSafariActivity
*2026-04-01*

ArticleReaderSheet share button presents `UIActivityViewController` via UIKit (walks responder chain to topmost VC). Includes a custom `OpenInSafariActivity: UIActivity` subclass that calls `UIApplication.shared.open(url)`. The system's built-in "Open in Safari" action is suppressed when the share sheet is presented from within a WKWebView context; the custom activity guarantees it always appears. Rejected: SwiftUI `ShareLink` (omits Safari); `UIActivityViewController` inside SwiftUI `.sheet` (sheet-within-a-sheet breaks activity VC).

---

## [iOS] Notification Reason Strings — Kebab-Case Raw Values
*2026-03-31*

`NotificationReason` enum raw values use AT Protocol's kebab-case: `starterpack-joined`, `like-via-repost`, `repost-via-repost`. The previous camelCase raw values (`starterpackJoined`, `likeViaRepost`, `repostViaRepost`) never matched the API strings, causing all three to fall through to `.unknown` ("interacted with you"). Navigation for via-repost types now goes to the subject post (not profile).

---

## [iOS] Image Resize — Shared Static Method
*2026-04-01*

`ComposeImage.resizeImageData(_:maxBytes:)` is a static method on `ComposeImage` (in `AppStore.swift`), shared by both `ComposeView` and `InlineReplyView`. Previously `InlineReplyView` had no resize step, causing blob uploads to fail for large camera photos (> 1 MB AT Protocol limit).

---

## [WEB] Smart App Banner + App Store Promotion
*2026-03-31*

`<meta name="apple-itunes-app" content="app-id=6760909675">` in `<head>` renders Safari's native Smart App Banner. Auth screen footer and Settings modal link to the App Store listing. GitHub repository link removed from user-facing UI (repo remains public).

---

## [iOS] Xcode Cloud — Root Workspace + Workspace-Level Shared Scheme
*2026-06-17*

The Xcode project lives nested at `BskyDreams-iOS/Bsky Dreams/Bsky Dreams.xcodeproj` (the repo root is the web app). Xcode Cloud expects the project/workspace at the repository root and reverts a configured subdirectory path back to root, failing with `Bsky Dreams.xcodeproj does not exist at the root of the repository`.

Fix, in three parts:

1. **Root workspace.** `BskyDreams.xcworkspace` at the repo root references the nested project (`<FileRef location="group:BskyDreams-iOS/Bsky Dreams/Bsky Dreams.xcodeproj">`). The workflow targets this workspace, satisfying the "must be at root" check without moving the project or touching `project.pbxproj`. Rejected: relocating the whole project to the repo root — it would mix iOS source among the web-app files and is a large change to a live App Store project.

2. **Workspace-level shared scheme.** Building the workspace, Xcode Cloud validates the scheme at the *workspace's* shared-data path, not the project's. With only a project-level shared scheme, onboarding fails with `The Scheme 'Bsky Dreams' may only exist locally. To use this workflow it must be pushed to your repository`. The fix is `BskyDreams.xcworkspace/xcshareddata/xcschemes/Bsky Dreams.xcscheme`, copied from the project scheme with `ReferencedContainer` / test-plan paths rewritten relative to the repo root (`container:BskyDreams-iOS/Bsky Dreams/...`). `xcodebuild -list` then shows two "Bsky Dreams" entries (project + workspace); harmless, same target — the GUI picker collapses them and prefers the workspace one.

3. **ci_scripts at the repo root.** Xcode Cloud only runs `ci_scripts` located beside the project/workspace the workflow targets. Since the workflow targets the root workspace, `ci_scripts/` lives at the repo root (not beside the `.xcodeproj`). `ci_pre_xcodebuild.sh` stamps `CI_BUILD_NUMBER` into `CURRENT_PROJECT_VERSION` in `AppVersion.xcconfig` (resolved via `CI_PRIMARY_REPOSITORY_PATH`), leaving `MARKETING_VERSION` for manual release bumps. No-ops outside Xcode Cloud.

Also removed 252 MB of committed Xcode derived data (`build/`, 612 files) and gitignored it — Xcode Cloud re-clones the full repo per build, so compiled artifacts in the source tree are dead weight. The workflow must be created from the open root workspace (not the `.xcodeproj`), or Xcode rebinds it to the nested project and the root error returns.

---

## [iOS] Dynamic Type via `relativeTo:` on Custom Fonts
*2026-06-17*

The `.syne()` and `.inter()` font helpers build their fonts with `.custom(_, size:, relativeTo: .body)` instead of a fixed `.custom(_, size:)`. Without `relativeTo:`, a custom (non-system) font renders at a literal point size and ignores the user's Dynamic Type setting entirely — the app reads at one size regardless of the accessibility text-size slider, which fails Apple's accessibility expectations and makes the app unusable for low-vision users. Tying each custom font to a `TextStyle` lets the type-size system scale it proportionally. Post body text still uses `.system(size:)` (see the emoji-fallback decision), which already scales. Trade-off: very large accessibility sizes can force layout reflow in dense rows — acceptable, and far better than ignoring the setting.

---

## [iOS] Universal Feature-State Primitives + the Four-States Rule
*2026-06-17*

Every content surface (list, grid, search, sheet) must explicitly handle four states beyond the happy path: **loading**, **empty**, **error**, and **offline**. Shared primitives enforce this: `NBEmptyState` (structural "nothing here" message), `NBErrorBanner` (coral, with retry/dismiss — for transient failures that just occurred), `NBOfflineBanner` (lime — network unreachable), and `NBSkeleton` / `NBSkeletonPostRow` (shimmer placeholder during first load, reduce-motion aware). Previously each view either showed a spinner forever, a blank screen, or silently swallowed errors in a bare `catch {}` — the user could not tell "loading" from "broken" from "genuinely empty." Standardizing the primitives makes every feature legible in failure and keeps the neubrutalist styling consistent. The four states are a checklist, not a suggestion: a surface that doesn't define all four is incomplete.

---

## [iOS] Haptics Taxonomy — Semantic, Not Ad-Hoc
*2026-06-17*

The `Haptics` enum defines a fixed semantic vocabulary: `selection` (paging, toggles, tab/segment changes), `light`/`medium`/`heavy` (discrete user actions by weight), and `success`/`warning`/`error` (operation outcomes). Calls pick the meaning, not a specific generator. Ad-hoc `UIImpactFeedbackGenerator(style:)` calls scattered through views drift into inconsistency — the same conceptual event (e.g. a failed post) fires different feedback in different places, and feedback gets sprinkled where it adds noise. A central taxonomy makes haptics mean something: `error` always accompanies a surfaced `NBErrorBanner`, `selection` always accompanies a page/toggle change. Trade-off: a small indirection layer over UIKit's generators — worth it for a coherent feel.

---

## [iOS] CachedImage — URL-Bound Cached Async Image with Off-Main Downsample
*2026-06-17*

`CachedImage` (backed by `NBImageLoader`) replaces `AsyncImage` in high-churn media surfaces (feed/gallery image grids). It mirrors `AsyncImage`'s phase API but adds: a shared `NSCache` (600 items / 60 MB), off-main ImageIO downsampling to the display size (not full-resolution decode), and — critically — a re-check of the bound URL *after* the async load completes, discarding the result if the cell has been recycled to a different post. Plain `AsyncImage` in a `LazyVStack`/`LazyVGrid` shows the wrong image in a recycled cell (the in-flight load lands after the cell was reassigned) and decodes images at full resolution on the main thread, causing scroll hitches and memory spikes. The URL re-check kills the wrong-image bug; off-main downsample kills the hitch. `clearCache()` is exposed for the Settings "Clear Image Cache" action. This complements `URLCache` (transport layer) rather than replacing it. Existing grid cells still constrain both width and height before `.clipped()`.

---

## [iOS] NetworkMonitor — Reachability-Driven Graceful Degrade
*2026-06-17*

`NetworkMonitor` (`@Observable`, wrapping `NWPathMonitor`) is injected via `@Environment` and exposes connectivity state. Views observe it to show `NBOfflineBanner` and to keep cached content visible instead of replacing it with a confusing error. Without an explicit reachability signal, an offline launch produced a generic request failure indistinguishable from a server error — the user saw "something went wrong" rather than "you're offline," and a retry button that could not possibly succeed. The monitor lets the app degrade honestly: tell the user it's offline, keep showing what's cached, and re-enable actions when the path returns. Single shared instance; one `NWPathMonitor` on a background queue.

---

## [iOS] SwiftData Container — Graceful On-Disk → In-Memory Fallback
*2026-06-17*

The `ModelContainer` is created inside a `do/catch`: on failure to open the on-disk store, the app falls back to an in-memory container rather than trapping. A corrupt or migration-incompatible store (e.g. a botched lightweight migration, or a store written by a future schema) previously crashed the app on launch with no recovery path — the user was permanently locked out and could only fix it by deleting and reinstalling. The fallback guarantees the app always launches: cross-session persistence is lost for that session (seen-posts, saved channels), but the app is usable and the next clean launch can rebuild the store. Launch-blocking persistence is never worth a hard crash.

---

## [iOS] Synchronized-Group New-File Gotcha — Inline New Types into Existing Files
*2026-06-17*

The Xcode project uses file-system-synchronized groups (`PBXFileSystemSynchronizedRootGroup`). Brand-new standalone `.swift` files dropped into a synchronized group are **intermittently not picked up by the build** — confirmed via `xcodebuild` CLI even after a clean build and a DerivedData wipe; the type "cannot be found in scope" despite the file existing on disk. Mitigation: new Swift types added in this update (`NetworkMonitor`, `NBImageLoader` / `CachedImage`, and other primitives) were **inlined into already-compiled files** (`AppStore.swift`, `DesignSystem.swift`) rather than created as new standalone files. New **asset-catalog** entries (colorsets, imagesets) inside the existing `.xcassets` are picked up by `actool` regardless of the synchronized-group issue — which is why the branded launch assets work as new files. Rule for future work: prefer extending an existing compiled file over adding a new `.swift` file; if a new file is unavoidable, verify it compiles into the target before building on top of it.

---

## [iOS] Branded Launch Screen — `UILaunchScreen` Dict, Blue (Never Coral)
*2026-06-17*

The launch screen is defined via an Info.plist `UILaunchScreen` dictionary (not a storyboard): asset-catalog `LaunchBackground` colorset (brand blue `#0047FF`) plus a `LaunchCloud` imageset (white cloud with a thin black outline, generated from the same `cloud.fill` SF Symbol source as the app icons). The previous setup referenced a `UILaunchStoryboardName` storyboard that no longer existed, yielding a blank/default launch. The `UILaunchScreen` dict avoids the storyboard entirely and renders the brand instantly. The launch background is **blue**, matching the iOS default accent — never coral. (See the per-platform default-accent decision: iOS default is `#0047FF`, web default is `#FF5C35`.) Launch assets are new asset-catalog entries, which `actool` compiles reliably despite the synchronized-group new-file gotcha above.

---

## [iOS] Dark-Mode Accent Legibility — `Color.nbAccentLegible`
*2026-06-17*

`Color.nbAccentLegible` returns a lightened variant of the user's accent color in dark mode, used for foreground elements (links, mentions, icon tints) — while the raw accent is retained for fills (buttons, active backgrounds). The default blue accent `#0047FF` is too dark to read as text/icon color against a dark background; using the same accent for both fills and foregrounds made links and tinted glyphs nearly invisible in dark mode. Splitting fill-accent from foreground-accent keeps both legible across appearances without changing the brand. Same lesson carried from the sibling Archive-Watch app, where `#0047FF`-on-dark was the original offender.

---

## [iOS] First-Run Hints — `HintsManager` + `HintBanner`
*2026-06-17*

Contextual first-run tips are delivered by `HintsManager` (`@Observable`) + `HintBanner` (cyan/blue, visually distinct from the coral error banner and lime offline banner). Each hint is dismissible permanently per-device; dismissals are kept in a stored `Set` reassigned on mutation so `@Observable` fires and dependent views update. A `HintBanner` is a transient, dismissable, one-time teaching tip — categorically different from `NBEmptyState` (structural), `NBErrorBanner` (attention/failure), and a multi-step walkthrough (not used here). The distinction matters: conflating "here's a tip" with "something is wrong" trains users to ignore both. Hints are governed by a master "Show Tips" toggle and a "Reset All Tips" action in Settings, so a user who dismissed everything can bring them back.

---

## [SHARED] Discover Feed — Personalized, Conversation-Weighted, User-Moderated
*2026-06-17*

Discover was rebuilt away from a global virality firehose. The old design merged three feed generators (`whats-hot` + `hot-classic` + `with-friends`) and sorted by raw likes-per-hour `(likes-1)/(hours+2)^1.8`. Two-thirds of those sources are network-wide identical for every account (`hot-classic` is pure global engagement; `whats-hot` is only lightly viewer-aware), so two different accounts saw the same posts — the feed was generic, not personal. Engagement-ranking a global pool also surfaced whatever is viral network-wide (large high-engagement NSFW/furry communities dominate), which no amount of per-account blocking can outrun. And the score optimized for exactly the rage-bait/repost dynamic the app's "build for human engagement" ethos rejects.

The rebuild (`DiscoverEngine` in `AppStore.swift`; mirrored in `js/app.js`):
- **Sources:** `whats-hot` + `with-friends` only. `hot-classic` removed — it was the generic, NSFW-heavy firehose.
- **Honor the user's OWN moderation** via `app.bsky.actor.getPreferences` (never fetched before): muted words, per-label visibility (`contentLabelPref` hide/warn), adult-content toggle. Send the `atproto-accept-labelers` header (Bluesky's default labeler `did:plc:ar7c4by46qjdydhdevvrndac` + the user's subscribed labelers) so labels actually arrive. Filter author `viewer.muted`/`blocking`/`blockedBy` client-side. (Fixed `ActorViewer`: the model had `blocked` which never matched the API's `blocking`/`blockedBy`.)
- **Personalize from the user's own signals** — their network (`author.viewer.following` + `knownFollowers`) and their topics (hashtags from their own recent posts). No opaque model.
- **Conversation-weighted ranking:** replies dominate, reply-to-like ratio rewards discussion, questions boosted, originals favored, **reposts penalized (×0.5)**, raw likes de-emphasized.
- **Transparency:** every discovery post carries a "why you're seeing this" chip ("From someone you follow", "Followed by N you know", "Matches your interest in #X", "Active conversation · N replies"). No opaque "for you" box.

**Feed IA (simplified 2026-06-17):** the home feed is **three flat top-level tabs — Following · Conversations · Trending** — no nested sub-toggle. **Following** = your follows, chronological (`getTimeline` only, no re-rank); a clean "catch up on your people" feed, distinct from discovery, and it honors your moderation too. **Conversations** (default) and **Trending** are both the personalized discovery pipeline above — they differ only in the base signal (discussion vs popularity). An earlier design had two top tabs (Following/Discover) plus a Conversations/In Network/Trending sub-toggle; "In Network" was dropped as redundant (network-awareness is always-on in discovery ranking, and a chronological Following already represents your graph), and the two levels were flattened to remove the nesting.

Rationale: this is the feed run through the project's four-question values check — it deepens understanding (you see *why*), invites participation (your graph + topics + the tab choice are the inputs), supports agency (your own moderation is honored, not a hardcoded list), and rewards conversation over virality. Trade-off: a per-session `getPreferences` + author-feed fetch to build the context, and a smaller candidate pool than the old firehose (mitigated by pagination).
