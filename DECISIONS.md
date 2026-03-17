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
