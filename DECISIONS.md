# Bsky Dreams — Architecture & Technology Decisions

Entries are ordered roughly by date of decision. Superseded entries have been removed;
the current state of each topic is captured in the most recent relevant entry.

---

## No Framework — Vanilla HTML/CSS/JS

- **Date:** 2026-02-20
- **Decision:** Use plain HTML, CSS, and JavaScript with no front-end framework.
- **Rationale:** GitHub Pages serves static files. A framework adds a build step, CI/CD complexity, and npm dependencies. For an app this size the abstractions cost more than they save.
- **Alternatives considered:** React, Vue, Svelte — all rejected due to build step requirement.
- **Trade-offs:** No component encapsulation, no reactive state management. DOM manipulation is manual.
- **Revisit if:** The component count grows beyond ~20 distinct UI elements or DOM manipulation becomes error-prone.

---

## AT Protocol HTTP API via fetch (no SDK)

- **Date:** 2026-02-20
- **Decision:** Call BlueSky AT Protocol XRPC endpoints directly using the browser's native `fetch` API.
- **Rationale:** `@atproto/api` requires a bundler. Loading it from a CDN is possible but the package is not tree-shaken and pulls in significant dependencies.
- **Alternatives considered:** `@atproto/api` via skypack CDN (unstable ESM build, large bundle); Cloudflare Worker proxy to run SDK server-side (adds infrastructure).
- **Trade-offs:** Manual request construction; must track lexicon changes manually. Token refresh handled in `auth.js`.
- **Revisit if:** The app needs Firehose/WebSocket subscriptions or complex record operations.

---

## App Passwords for Authentication

- **Date:** 2026-02-20
- **Decision:** Use BlueSky "App Passwords" rather than the user's main account password.
- **Rationale:** BlueSky's documentation recommends app passwords for third-party clients. They can be revoked independently and have scoped permissions.
- **Alternatives considered:** AT Protocol OAuth (complex, not yet widely supported); main password (dangerous).
- **Trade-offs:** Extra setup step for users. Mitigated by clear in-app instructions.
- **Revisit if:** AT Protocol OAuth becomes stable and widely supported.

---

## localStorage for Session Persistence

- **Date:** 2026-02-20
- **Decision:** Store the BlueSky session (`accessJwt`, `refreshJwt`, handle, DID) in `localStorage` under `bsky_session`.
- **Rationale:** No server-side session store available (static app). localStorage survives page reloads and browser restarts. Credentials are only ever sent to bsky.social.
- **Alternatives considered:** sessionStorage (requires re-login on every tab close); IndexedDB (overkill); cookies (require a server for HttpOnly).
- **Trade-offs:** XSS could expose the stored token. Mitigated by: no third-party scripts loaded, strict CSP, GitHub Pages HTTPS.
- **Revisit if:** The app loads any third-party script that could create an XSS vector.

---

## GitHub Pages Root Deployment (no subdirectory)

- **Date:** 2026-02-20
- **Decision:** Deploy from the root `/` of the `main` branch. All asset paths are relative.
- **Rationale:** Simplest possible GitHub Pages setup. No subdirectory path prefix to manage.
- **Alternatives considered:** `/docs` publish directory (adds indirection); separate `gh-pages` branch (requires a deploy workflow).
- **Trade-offs:** Main branch must always contain deployable code. Development on feature branches only.
- **Revisit if:** A build step is introduced, at which point a GitHub Actions workflow to `gh-pages` is preferable.

---

## HLS.js Served Locally (no CDN)

- **Date:** 2026-02-20
- **Decision:** Bundle HLS.js v1.5.13 as `/js/hls.min.js` rather than loading from a CDN.
- **Rationale:** CSP `script-src 'self'` blocks scripts from any external origin. Serving locally keeps the strict policy intact.
- **Alternatives considered:** CDN load with explicit domain in script-src (weakens CSP); no video support (too much regression).
- **Trade-offs:** 413 KB added to the repo. No automatic HLS.js updates — must manually update for security fixes.

---

## CSP connect-src Widened to * for Video CDN Compatibility

- **Date:** 2026-02-20
- **Decision:** Changed `connect-src` from an explicit allowlist to `*`.
- **Rationale:** HLS.js fetches manifests and segments via `fetch()`. BlueSky's video CDN may redirect to Cloudflare edge nodes whose hostnames are not known at deploy time. Widening to `*` matches the already-permissive `img-src *` and `media-src *` posture.
- **Alternatives considered:** Adding known subdomains (`*.bsky.app`, `*.bsky.network`) — fragile because CDN topology is opaque.
- **Trade-offs:** Removes network-destination restriction from CSP. Risk is low: no third-party scripts loaded (`script-src 'self'`), all output is HTML-escaped.
- **Revisit if:** A security audit recommends tighter egress control.

---

## AT Protocol Facets for Rich Text (TextEncoder/TextDecoder)

- **Date:** 2026-02-20
- **Decision:** Render post text using AT Protocol `record.facets` with byte-accurate UTF-8 slicing via `TextEncoder` / `TextDecoder`.
- **Rationale:** AT Protocol facets use byte offsets, not character offsets. JavaScript string `.charAt()` indices are incorrect for non-ASCII text. Converting to `Uint8Array` and slicing by byte offset is the only correct approach.
- **Alternatives considered:** Character-index slicing (incorrect for non-ASCII); regex-only linkification (misses hashtags and mentions).
- **Revisit if:** AT Protocol changes facet index semantics (unlikely given spec stability).

---

## History API Integration (pushState / popstate)

- **Date:** 2026-02-20
- **Decision:** Use the browser History API (`pushState`, `replaceState`, `popstate`) to make the Back and Forward buttons work across view transitions.
- **Rationale:** Without history integration every navigation breaks the Back button and page refresh resets to the auth screen.
- **Alternatives considered:** Hash-based routing (simpler but ugly URLs, no Forward); a client-side router library (overkill).
- **Trade-offs:** State is stored in `history.state` (not persisted across hard refresh).
- **Revisit if:** Deep-link support requires encoding AT URIs in clean paths.

---

## CORS — No Proxy Needed (bsky.social uses open CORS)

- **Date:** 2026-02-20
- **Decision:** No Cloudflare Worker CORS proxy. Direct browser fetch to all `bsky.social` and `video.bsky.app` endpoints.
- **Rationale:** Both endpoints serve `Access-Control-Allow-Origin: *`. The earlier concern was unfounded; the actual video failure was a CSP `connect-src` restriction (resolved separately).
- **Trade-offs:** If BlueSky changes their CORS policy the app breaks with no fallback.
- **Revisit if:** Any fetch call returns a CORS error in the browser console.

---

## Image Upload via Raw Binary POST (not JSON)

- **Date:** 2026-02-21
- **Decision:** `com.atproto.repo.uploadBlob` is called with the raw `File` object as the request body (binary), with `Content-Type` set to the file's MIME type.
- **Rationale:** The AT Protocol `uploadBlob` endpoint explicitly requires raw binary POST — the only XRPC endpoint that is not JSON-encoded. A separate `uploadBlobRaw(file, token)` helper calls `fetch` directly.
- **Alternatives considered:** Base64-encoding as JSON (not supported); FormData (not supported — endpoint expects raw binary).
- **Revisit if:** AT Protocol changes uploadBlob to accept multipart or JSON.

---

## Image Upload Before Post Creation (separate async step)

- **Date:** 2026-02-21
- **Decision:** All blobs are uploaded via `Promise.all` before `createPost` is called. Blob refs (CID + mimeType) are passed as an `images` array to `createPost`.
- **Rationale:** AT Protocol requires blob CIDs at post-creation time — no way to attach a blob after a post is created.
- **Trade-offs:** If upload succeeds but `createPost` fails, blobs are orphaned (harmless; GC'd eventually).
- **Revisit if:** AT Protocol adds a transactional blob+post endpoint.

---

## Notifications: Load-on-Demand, No Polling

- **Date:** 2026-02-21
- **Decision:** Notifications load the first time the user navigates to the view, not on a timer.
- **Rationale:** No server component available. WebSocket Firehose subscriptions are not feasible from a static site. Load-on-demand is simpler and sufficient.
- **Alternatives considered:** `setInterval` polling every 60s (burns battery/bandwidth); Firehose WebSocket (requires relay server).
- **Trade-offs:** Badge count and list are stale until the user taps Refresh or re-opens the view.
- **Revisit if:** Users find the stale badge confusing.

---

## URL Routing — Query-Parameter Based (Not Hash, Not Clean Paths)

- **Date:** 2026-02-21
- **Decision:** Use query-parameter routing (`?view=post&uri=...`) for all deep-linkable views.
- **Rationale:** GitHub Pages serves `index.html` for the root path, but `/post/at://...` returns a 404 (no server-side rewrite rules). Hash routing would work but produces noisier URLs. Query parameters are safe, human-readable, and parse cleanly via `URLSearchParams`.
- **Scheme:**
  - Thread: `?view=post&uri=at%3A%2F%2F...&handle=...`
  - Profile: `?view=profile&actor=handle.bsky.social`
  - Search: `?q=query&filter=posts`
  - Feed: `?view=feed` / Notifications: `?view=notifications`
- **On navigation:** `openThread` and `openProfile` include the full URL in `pushState` calls. `showView` adds view-specific URL params. Successful searches use `replaceState`.
- **On load:** `init()` parses `window.location.search` and routes to the correct view after the session profile loads.
- **Bsky.app URL import:** Search input detects `bsky.app/profile/.../post/...` patterns and uses `API.resolvePostUrl()` to convert them to AT URIs.
- **Copy link:** Each post card has a chain-link icon that copies the full Bsky Dreams URL to the clipboard with 1.5s "Copied!" feedback.
- **Alternatives considered:** Hash routing (safe but ugly); clean paths with 404.html redirect trick (adds complexity and a redirect hop).
- **Revisit if:** A GitHub Actions deploy pipeline is added, enabling a proper SPA with clean-path rewrites.

---

## Cross-Device Persistence — AT Protocol Repo as Sync Backend

- **Date:** 2026-02-21
- **Decision:** User preferences and saved channels are stored as a JSON record in the user's own AT Protocol repository under collection `app.bsky-dreams.prefs`, rkey `self`. Written via `com.atproto.repo.putRecord`, read via `com.atproto.repo.getRecord`. Falls back to localStorage if the record doesn't exist yet.
- **Rationale:** The zero-cost constraint rules out any traditional backend. The AT Protocol repo is effectively a user-owned hosted key-value store. Since the user authenticates to their own PDS, we already have write access.
- **Alternatives considered:** localStorage only (no cross-device sync); export/import JSON file (manual); Cloudflare Workers KV (free tier but adds infrastructure).
- **Trade-offs:** AT Protocol repo records are publicly readable by anyone who knows the DID + collection + rkey. Preferences are non-sensitive, so this is acceptable. Secrets must never be stored here.
- **Revisit if:** BlueSky adds private/encrypted record support to the AT Protocol spec.

---

## Sidebar — Mobile Drawer, Desktop Always-Open (M43)

- **Date:** 2026-02-25 (drawer pattern: 2026-02-21; evolved through M38, finalized M43)
- **Decision:** `#channels-sidebar` contains all navigation. On desktop (≥768px) the sidebar is always open (`left: 0`, no toggle). The top bar collapses to zero height on desktop. On mobile the sidebar is a slide-in drawer triggered by a hamburger in a minimal top bar.
- **Rationale:** A persistent sidebar on mobile leaves too little horizontal space. The drawer pattern is the standard mobile solution (Gmail, Slack, Discord). The always-open desktop approach (M43) eliminates the confusing `body.sidebar-open` toggle from M38 that required localStorage state and caused layout jitter.
- **Alternatives considered:** Channels as a nav tab (simpler but loses workspace feel); always-open with toggle-collapse mini mode (complexity not justified).
- **Trade-offs:** Top bar disappears on desktop; breadcrumb context visible only via sidebar active state.
- **Revisit if:** A breadcrumb or view-title bar becomes necessary for deeper navigation.

---

## Channels Unread Checking — Load-on-Login, Throttled, Session-Once

- **Date:** 2026-02-21
- **Decision:** Unread counts checked once per login session via `checkChannelUnreads()`, a background async task after `enterApp()` resolves. Fetches latest 5 posts per channel, spaced 700ms apart. No polling.
- **Rationale:** Polling would consume battery and bandwidth. Checking once per login is predictable and low cost.
- **Alternatives considered:** Per-channel polling every 60s (too expensive); WebSocket Firehose (requires server); no checking at all.
- **Trade-offs:** Badges may be stale later in the session.
- **Revisit if:** Users find stale badges confusing.

---

## Bsky Dreams TV — Splash Screen for Audio Autoplay

- **Date:** 2026-02-21
- **Decision:** TV requires a deliberate "▶ Start TV" user interaction before any video plays.
- **Rationale:** Browsers block audio autoplay until the page has received a user gesture. Without a Start button the first video would be muted and users would have to hunt for an unmute button.
- **Alternatives considered:** Auto-play muted with a prominent unmute button (less appropriate for a "TV" metaphor).
- **Trade-offs:** One extra tap before content plays. Worth it for reliable audio.

---

## Bsky Dreams TV — Two-Slot Slide System + Dual-Feed Seeding

- **Date:** 2026-02-24
- **Decision:** TV uses two `position: absolute` video containers (`tv-slide-a`, `tv-slide-b`) that swap roles on each transition, enabling simultaneous outgoing/incoming CSS `translateY` animations. The no-topic queue seeds from both `API.getTimeline()` and `API.getFeed(DISCOVER_FEED_URI)` in parallel via `Promise.allSettled()`. Custom-topic queries fire both a hashtag search and a plain-text search in parallel.
- **Rationale:** A single `<video>` element cannot transition out while a new one transitions in. Dual-feed seeding overcomes the sparsity of video-only content in a single feed. Dual-topic search fixes the bug where text results rarely included video posts.
- **Alternatives considered:** Single video element with CSS fade (no directional slide); single search only (returned no results for most custom topics).
- **Trade-offs:** Two HLS instances exist simultaneously; the off-screen slot is kept alive (paused) to enable instant back-navigation. Memory cost is acceptable on a mobile device.
- **Revisit if:** Memory pressure on low-end devices causes crashes.

---

## Network Constellation — Search-Seeded, D3.js, Served Locally

- **Date:** 2026-02-21
- **Decision:** The constellation visualization (M14, not yet implemented) seeds from a user-entered search term, not the logged-in user's follow graph. D3.js v7 will be served locally as `/js/d3.min.js`.
- **Rationale:** Search-seeded graph is more broadly useful and avoids mapping the user's own social graph without explicit intent. Serving D3 locally is consistent with the HLS.js pattern.
- **Alternatives considered:** Seeding from the user's own network (narrower use case); Vis.js or Cytoscape.js (heavier); WebGL renderer (faster but complex).
- **Trade-offs:** D3.js adds ~270 KB to the repo. Cap enforced at 150 nodes to avoid jank.

---

## Direct Messages — Native Chat API, Separate Base URL

- **Date:** 2026-02-21
- **Decision:** DMs (M16, not yet implemented) will use BlueSky's native `chat.bsky.convo.*` lexicon at `https://api.bsky.chat/xrpc/`. Same `accessJwt`. A dedicated `chatGet`/`chatPost` helper pair will be added to `api.js`.
- **Rationale:** BlueSky's native chat is the only zero-cost, standards-compliant option. The separate base URL is a minor inconvenience handled cleanly by a second set of fetch helpers.
- **Alternatives considered:** Custom messaging via AT Protocol repo records (not real-time, not encrypted); third-party messaging APIs (cost, privacy).
- **Trade-offs:** `chat.bsky.convo.*` is relatively new; documentation sparse. Monitor AT Protocol changelog.

---

## Quoted Post Rendering — Separate `buildQuotedPost` Card

- **Date:** 2026-02-21
- **Decision:** Quoted posts render as a distinct compact card (`buildQuotedPost`) — avatar, name, handle, truncated text. Clicking opens the quoted post's own thread.
- **Rationale:** Quote-posts and replies are semantically different relationships. A compact card matches bsky.app and keeps navigation semantically correct.
- **Alternatives considered:** Nested full `buildPostCard` (too heavy, recursive action buttons); ignoring the record embed (was previous behaviour — caused silent data loss).
- **Trade-offs:** Quoted card does not render facets (plain `textContent`). Acceptable for a truncated preview.

---

## Feed Reply Context — Compact Parent Preview, Root-First Navigation

- **Date:** 2026-02-21
- **Decision:** When a feed item is a reply, a compact clickable preview of the parent post appears above the reply card (`buildParentPreview`). Clicking either card navigates to the **root** of the thread, not the reply's own URI.
- **Rationale:** BlueSky's timeline delivers replies mid-thread with no context. Root-first navigation ensures the user always sees the full conversation from the top. The parent `PostView` is already present in the timeline response — no extra API call needed.
- **Alternatives considered:** Fetching the full parent thread on render (too expensive); "Replying to @handle" text label (previous behaviour — not enough context); opening the reply's own URI (disorienting).
- **Trade-offs:** Parent preview shows only the first line of parent text. If parent is `notFoundPost` or `blockedPost`, preview is omitted.

---

## Thread Depth Limit — Depth 4, "Continue This Thread →"

- **Date:** 2026-02-21 (initial: depth ≥ 8); updated 2026-02-25 (M46: changed to depth ≥ 4)
- **Decision:** `renderThread` tracks nesting depth (0 = root). At depth ≥ 4, further recursion is replaced by a "Continue this thread →" button that re-opens the thread from that reply node. Clicking uses `history.pushState` so the Back button returns to the parent. A "← Back to parent thread" breadcrumb appears when `fromContinue: true` is in `history.state`.
- **Rationale:** Deep threads cause DOM bloat and layout jank with indented connector lines. At ~12px indent per level, depth 5+ causes visible horizontal overflow on 375px screens. Depth 4 leaves ~315px for content — tight but readable.
- **Alternatives considered:** No depth limit (DOM performance degrades); 3-level cap (too shallow); collapsing the sub-tree (hides context).
- **Trade-offs:** Very long chains require multiple "Continue" navigations.
- **Revisit if:** Users report that 4 levels is too shallow for their typical threads.

---

## Lightbox Carousel — Shared Image Array, startIndex

- **Date:** 2026-02-21
- **Decision:** `openLightbox(images, startIndex)` accepts an array of `{src, alt}` objects. `buildImageGrid` passes a shared `lightboxPayload` array so all images in a post are browsable from any starting thumbnail.
- **Rationale:** Posts with 2–4 images previously required closing and reopening the lightbox for each. Carousel navigation is standard UX.
- **Alternatives considered:** Scrollable strip inside the lightbox (less common, harder to caption per image).
- **Trade-offs:** The lightbox holds an in-memory copy of the image URL array; negligible for 2–4 URLs.

---

## Adaptive Image Sizing — Natural Ratio for Singles, Fixed Crop for Grids

- **Date:** 2026-02-21
- **Decision:** Single-image posts use `object-fit: contain` with `max-height: 480px`. Multi-image grids (2–4) retain uniform fixed-height crop (180px / 220px on desktop).
- **Rationale:** Portrait screenshots were previously sliced to a 180px landscape strip. Natural aspect ratio for single images fixes this without requiring the server to supply dimensions. Grids need uniform height for a clean tiled layout.
- **Alternatives considered:** `aspect-ratio` CSS property from image metadata (AT Protocol doesn't expose width/height in the embed view); uniform height for all counts (reverts the portrait regression).
- **Trade-offs:** Very wide panoramas may show black pillarboxing in the 480px box.

---

## Thread Nesting — Depth-Colored Left Border, No Connector Element

- **Date:** 2026-02-21
- **Decision:** `border-left` on `.reply-group` elements (not an absolutely-positioned connector element). Color driven by CSS custom property set via `[data-depth]` attribute selectors — 8 cycling colors. Post cards inside each reply group carry the same depth color. Collapse button on the connector line (Reddit-style).
- **Rationale:** The old `top: -8px` connector element intruded into the post card above. `border-left` on the container ties the visual connector directly to the grouped content with no overflow or z-index issues.
- **Alternatives considered:** `::before` pseudo-element (same overlap problem); avatar-column threading like Twitter/X (requires restructuring post card layout).
- **Trade-offs:** No "flow line" emerging from the parent card's avatar — visually clean but slightly less explicit. Depth colors compensate.

---

## Inline Reply Compose — Context-Preserving, Toggle, Dismiss

- **Date:** 2026-02-21
- **Decision:** `expandInlineReply(postCard, post)` inserts a compose box directly after the target post card in the DOM. Only one inline box at a time; opening a second closes the first; clicking Reply on the same card toggles it closed.
- **Rationale:** The previous flow (reply → scroll to bottom of thread → type) forced users to lose visual context. The inline approach keeps the parent post visible immediately above the textarea.
- **Alternatives considered:** Fixed overlay panel at the bottom of the viewport (covers content); modal dialog (harder to dismiss); keeping the bottom reply area with an anchor (still loses visual context).
- **Trade-offs:** Reloading the thread after a successful post destroys and rebuilds the DOM, closing the box. Acceptable — the post was just submitted.

---

## Discover Feed — `whats-hot` URI, Tab-Based Toggle, Default Tab

- **Date:** 2026-02-24
- **Decision:** The "Discover" tab uses `at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot` via `app.bsky.feed.getFeed`. The home feed header is a two-tab toggle (Following / Discover). Discover is the default tab on load (`feedMode` initialises to `'discover'`).
- **Rationale:** `whats-hot` is the canonical AT URI for BlueSky's curated discovery feed. Tab bar is the lightest-weight toggle. Discover as default provides a populated feed on first load rather than an empty Following feed.
- **Alternatives considered:** Dropdown/select (less discoverable on mobile); separate nav tab (adds clutter); Following as default (empty for new users).
- **Trade-offs:** `whats-hot` feed content policy is controlled by BlueSky. If the URI changes, the constant in `app.js` must be updated.

---

## Elastic Overscroll Suppression — `overscroll-behavior: none` on `.view`

- **Date:** 2026-02-24
- **Decision:** `overscroll-behavior: none` added to `.view` (the `overflow-y: auto` container used by all views).
- **Rationale:** `body` already had this property, but `.view` is the *actual* scroll container for all views. Inner scroll containers have independent overscroll behavior; without the property on `.view`, iOS Safari and Chrome on Android exhibited elastic rubber-banding inside those containers.
- **Alternatives considered:** `overscroll-behavior: contain` on `.view` (still allows the bounce within the element itself).
- **Trade-offs:** Suppresses the bounce effect entirely. This is intentional — the app implements its own pull-to-refresh gesture.

---

## Mention Links — DID-based Navigation via Data Attribute + Event Delegation

- **Date:** 2026-02-24
- **Decision:** Mention facets embed the DID in a `data-mention-did` attribute on the rendered `<span>`. Click/keyboard handlers are wired via `querySelectorAll('[data-mention-did]')` inside `buildPostCard()` after innerHTML is set.
- **Rationale:** `renderPostText()` returns an HTML string (set via `innerHTML`), so direct listener attachment during construction is not possible. Embedding the DID in a data attribute and delegating from `buildPostCard` is the minimal correct pattern.
- **Alternatives considered:** Switching `renderPostText` to return DOM nodes (large refactor, not justified).
- **Trade-offs:** One `querySelectorAll` per card render. Negligible performance cost.

---

## Like Button — Optimistic Update with Rollback

- **Date:** 2026-02-24
- **Decision:** The like button applies the UI change (toggle class, count, SVG fill) before the API call resolves. On API error, the pre-change state is restored from a snapshot. Button is disabled during the in-flight request.
- **Rationale:** Optimistic updates feel instant on slow connections. The previous code updated inside the `try` block and had no error rollback, leaving the UI desynced on failure.
- **Alternatives considered:** Non-optimistic (update only after API confirms — laggy); no rollback (previous behaviour — leaves UI desynced).
- **Trade-offs:** A snapshot of three fields (likeUri, count text, class) is held in closure for each API call. Negligible memory cost.

---

## Timestamp as External Link to bsky.app

- **Date:** 2026-02-24
- **Decision:** The relative-time badge on each post card is wrapped in `<a href="https://bsky.app/profile/{handle}/post/{rkey}" target="_blank" rel="noopener">`. The `rkey` is derived from the AT URI (`uri.split('/').pop()`). Falls back to a plain `<time>` element if handle or rkey cannot be determined.
- **Rationale:** Tapping the time badge is a natural affordance for "see the original post." It gives users a quick escape hatch to the official Bluesky app for actions not yet supported in Bsky Dreams.
- **Trade-offs:** Opens bsky.app in a new tab.
- **Revisit if:** The app adds all major post actions and there is less reason to link out.

---

## GIF Detection — Hostname + URL Extension Heuristic

- **Date:** 2026-02-24 (updated 2026-02-25 to add Klipy)
- **Decision:** `isGifExternalEmbed(external)` checks the hostname for `tenor.com`, `c.tenor.com`, `media.giphy.com`, `giphy.com`, and `klipy.com`, and also checks whether the URL path ends in `.gif`. Matching embeds are rendered as `<img>` via `buildGifEmbed()`.
- **Rationale:** GIFs posted via Tenor/Giphy/Klipy are attached as `app.bsky.embed.external` link cards. The browser's native `<img>` element handles GIF animation without autoplay policy restrictions.
- **Alternatives considered:** MIME type sniffing (requires a HEAD request per embed — too slow); always rendering external links as images (breaks ordinary link cards).
- **Trade-offs:** If any GIF provider changes their CDN domain structure, the hostname list must be updated.
- **Revisit if:** BlueSky adds a native GIF embed type with a dedicated `$type`.

---

## Quote Post — Action Sheet on Repost Button

- **Date:** 2026-02-24
- **Decision:** The repost toggle button is replaced with a two-option action sheet: "Repost / Undo repost" and "Quote Post". Quote posts open a full modal with a compose textarea and a read-only quoted-post preview card.
- **Rationale:** The native BlueSky app uses the same action-sheet pattern. Splitting into a sheet avoids adding a new button to the already-crowded post actions row.
- **Alternatives considered:** Separate "Quote" button on the actions row (too crowded); long-press context menu (not discoverable on mobile).
- **Trade-offs:** Plain reposting now requires two taps instead of one.

---

## iOS Safari PWA Session Persistence — `visibilitychange` JWT Refresh

- **Date:** 2026-02-24
- **Decision:** A `document.visibilitychange` listener in `app.js` checks `accessJwt` expiry on every app foreground. If within 15 minutes of expiry, `AUTH.refreshSession(refreshJwt)` is called proactively. If fully expired, session is cleared and the auth screen is shown with a message.
- **Rationale:** Safari standalone PWA mode suspends JavaScript timers while backgrounded. A ~2-hour `accessJwt` can expire between launches without any timer firing. `visibilitychange` is the only reliable hook that fires immediately on cold launch or foreground.
- **Alternatives considered:** `setInterval` polling (suspended by Safari background throttling); decoding JWT `exp` on every API call (adds latency); Service Worker background sync (unreliable on iOS).
- **Trade-offs:** One async operation on every app foreground. If the refresh fails (network offline), the original token remains and will expire naturally.

---

## PTR Resistance — Two-Stage Threshold

- **Date:** 2026-02-24
- **Decision:** Pull-to-refresh requires a drag of ≥ 96px *plus* a 400ms hold before `ptrReadyToRelease` becomes true. Both conditions must be met before releasing triggers a refresh.
- **Rationale:** The 64px threshold caused accidental refreshes when users quickly scrolled past the top. The hold timer ensures only deliberate, sustained pulls trigger a refresh.
- **Trade-offs:** Slightly slower to trigger for intentional pulls. The 400ms delay is imperceptible in practice.

---

## Seen-Posts Deduplication — Map + Viral Threshold + Show-Anyway Escape

- **Date:** 2026-02-24
- **Decision:** Seen feed posts stored as `Map<uri, { seenAt, likeCount, repostCount }>` in `localStorage` under `bsky_feed_seen` with a 5,000-entry FIFO cap. Posts are filtered before render unless engagement has grown by ≥ 50 interactions since first view ("gone viral" threshold). A "N posts filtered (show anyway)" link below the feed bypasses the filter for the current session.
- **Rationale:** Deduplication prevents seeing the same posts repeatedly. The viral threshold resurfaces genuinely popular content. The show-anyway escape hatch respects user agency.
- **Alternatives considered:** Simple URI blocklist with no viral threshold (misses resurging content); time-based expiry (doesn't account for slow-to-trend posts).
- **Trade-offs:** The viral threshold of 50 is arbitrary.
- **Revisit if:** User feedback suggests the threshold is too high or too low.

---

## Sidebar Navigation Redesign — Always-Open Desktop, Drawer Mobile (M43)

- **Date:** 2026-02-25
- **Decision:** `#channels-sidebar` expanded to contain all navigation. On desktop (≥768px) the sidebar is always visible (`left: 0`, no class required, no toggle). Top bar shrinks to zero height on desktop. On mobile it is a slide-in drawer triggered by a hamburger in the top bar.
- **Rationale:** Moving all navigation into a persistent sidebar matches standard desktop app patterns (Slack, Discord, Gmail). The always-open approach eliminates the confusing `body.sidebar-open` toggle from M38, which required localStorage persistence and caused content-layout jitter.
- **Alternatives considered:** Horizontal top-bar nav on desktop (limited space for new entries); always-open with toggle-collapse mini mode (complexity not justified).
- **Trade-offs:** Top bar disappears on desktop; breadcrumb context visible only via sidebar active state.

---

## OG Link Preview via allorigins.win Proxy

- **Date:** 2026-02-25
- **Decision:** OpenGraph metadata fetched via `https://api.allorigins.win/get?url=…` (free, open CORS proxy) and parsed with browser `DOMParser`. Title and description rendered as editable inputs. Thumbnail stored as `_thumbUrl` and uploaded as a blob at submit time so native Bluesky renders an image card.
- **Rationale:** Direct `fetch()` of third-party pages is blocked by CORS. `allorigins.win` is the lightest zero-cost proxy. Uploading the thumbnail (same pattern as GIF thumbnails) ensures rich cards in native clients.
- **Alternatives considered:** Cloudflare Worker proxy (adds infrastructure); server-side OG fetch (no server available); skipping thumbnail upload (bare text link in native clients).
- **Trade-offs:** `allorigins.win` is a third-party service with no SLA. If it is down, link preview silently fails without blocking the compose flow.
- **Revisit if:** `allorigins.win` becomes unreliable; at that point self-host a Cloudflare Worker proxy.

---

## Thread Gate and Post Gate via putRecord

- **Date:** 2026-02-25
- **Decision:** After a successful `createPost`, if non-default restrictions are selected, `API.putRecord` creates `app.bsky.feed.threadgate` and/or `app.bsky.feed.postgate` records. The rkey for both matches the post's rkey.
- **Rationale:** AT Protocol requires threadgate and postgate to be separate records stored after the post itself. `putRecord` with the same rkey is the prescribed approach.
- **Trade-offs:** Two extra API calls after each restricted post. If either fails, the post is published without the intended restriction. Silent failure is acceptable given how rarely non-default restrictions are set.

---

## GIF Provider — Klipy via External Embed (not Blob Upload)

- **Date:** 2026-02-25
- **Decision:** GIFs selected from Klipy are posted as `app.bsky.embed.external` with the Klipy CDN URL as the embed `uri`. The `xs.jpg` static thumbnail is uploaded as a blob and attached as `thumb`. No GIF file is uploaded to the AT Protocol blob store.
- **Rationale:** BlueSky's AppView CDN transcodes uploaded image blobs to JPEG, stripping animation. The only way to preserve GIF animation is to reference the source CDN URL directly via an external embed — the same approach the official Bluesky app uses for Tenor and Giphy. Uploading the thumbnail blob ensures native Bluesky renders a rich card (not a bare text link).
- **Alternatives considered:** Uploading the GIF as an image blob (strips animation); canvas-frame capture (produces pixelated static first frame).
- **Trade-offs:** Klipy is not yet on Bluesky's animated-GIF allowlist (issue #9728). Native Bluesky shows the thumbnail card but not animation. No code change needed when Klipy is added to the allowlist.

---

## Scroll-Based Seen Marking — Full-Viewport IntersectionObserver

- **Date:** 2026-02-25
- **Decision:** A shared `IntersectionObserver` with `rootMargin: '0px'` (full viewport) and `threshold: 0` marks a post as "seen" when `entry.isIntersecting === false` AND `entry.boundingClientRect.top < 0` (scrolled above the viewport).
- **Rationale:** The original `-80%` rootMargin shrinks the effective root to the top 20% of the viewport. A post scrolled past quickly (never entering that top-20% zone) stays at intersection ratio 0 throughout — no callback fires, post is never marked seen. With `rootMargin: '0px'`, the callback fires on any transition from visible to above-viewport, regardless of scroll speed.
- **Alternatives considered:** `-100%` rootMargin (equivalent but less forgiving on slow scrolls); explicit scroll-position tracking per card (complex).
- **Trade-offs:** Posts at the very bottom of the initial render batch that are partly visible are "intersecting" immediately. They will be marked seen as soon as the user scrolls them above the viewport — the correct behavior.

---

## Deferred Milestones — Paid API Dependencies

- **Date:** 2026-02-21
- **Decision:** Three proposed milestones are deferred pending research into zero-cost implementation paths: fact-checking (M27a), political bias analysis (M27b), and AI-generated content detection (M27c).
- **Rationale:** Each requires a paid third-party API (ClaimBuster, Ground News, Hive, etc.). The zero-cost constraint rules these out. Partial implementations are possible (static datasets for domain-level bias; C2PA metadata check for AI detection) and are noted in SCRATCHPAD.md.
- **Revisit if:** The user decides to fund specific API keys, or an open/free alternative emerges.
