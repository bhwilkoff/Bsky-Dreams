# Bsky Dreams — Architecture & Technology Decisions

## No Framework — Vanilla HTML/CSS/JS

- **Date:** 2026-02-20
- **Decision:** Use plain HTML, CSS, and JavaScript with no front-end framework (no React, Vue, Svelte, etc.)
- **Rationale:** GitHub Pages serves static files. A framework adds a build step, CI/CD complexity, and npm dependencies. For an MVP with three focused features, a framework's abstractions cost more than they save. The app fits comfortably in a few files.
- **Alternatives considered:** React (requires build step or CDN with limited ecosystem access), Vue (same), Svelte (requires build step). All were rejected due to deployment constraint.
- **Trade-offs:** No component encapsulation, no reactive state management. DOM manipulation is manual. This is acceptable at MVP scope; revisit if the component count exceeds ~20 distinct UI elements.
- **Revisit if:** The app grows to need client-side routing with many views, or the component complexity makes vanilla DOM manipulation error-prone.

---

## AT Protocol HTTP API via fetch (no SDK)

- **Date:** 2026-02-20
- **Decision:** Call the BlueSky AT Protocol XRPC endpoints directly using the browser's native `fetch` API rather than importing `@atproto/api` or any SDK.
- **Rationale:** The `@atproto/api` npm package requires a bundler (Webpack, Vite, etc.) to work in a browser. Loading it from a CDN (unpkg/skypack) is possible but the package is not tree-shaken and pulls in significant dependencies. For the three MVP features (post, search, thread), the raw HTTP surface is small and well-documented at https://docs.bsky.app/docs/category/http-reference.
- **Alternatives considered:** `@atproto/api` via skypack CDN (unstable ESM build, large bundle), a Cloudflare Worker proxy to run SDK server-side (adds infrastructure).
- **Trade-offs:** Manual request construction; no automatic token refresh (handled in auth.js); must track lexicon changes manually.
- **Revisit if:** The app needs Firehose/WebSocket subscriptions or complex record operations that the raw HTTP API makes cumbersome.

---

## App Passwords for Authentication

- **Date:** 2026-02-20
- **Decision:** Use BlueSky "App Passwords" (a dedicated password generated in Settings → Privacy and Security → App Passwords) rather than the user's main account password.
- **Rationale:** BlueSky's own documentation recommends app passwords for third-party clients. They can be revoked independently of the main password. They have scoped permissions. This is the safest approach for a browser-based app storing credentials in localStorage.
- **Alternatives considered:** OAuth via the AT Protocol OAuth spec (complex, not yet widely supported by all clients); main password (dangerous, not recommended).
- **Trade-offs:** Extra setup step for users (must generate an app password first). Mitigated by clear in-app instructions.
- **Revisit if:** AT Protocol OAuth becomes stable and widely supported, enabling a proper OAuth flow without storing any credential in localStorage.

---

## localStorage for Session Persistence

- **Date:** 2026-02-20
- **Decision:** Store the BlueSky session token (JWT accessJwt + refreshJwt) and the user's handle/DID in `localStorage` under the key `bsky_session`.
- **Rationale:** There is no server-side session store (static app). localStorage survives page reloads and browser restarts. The alternative (sessionStorage) requires re-login on every tab close. The credentials are only ever sent to bsky.social — not to any third party.
- **Alternatives considered:** sessionStorage (less convenient), IndexedDB (overkill for a small JSON blob), cookies (require a server to set HttpOnly; cannot use without a backend).
- **Trade-offs:** XSS could expose the stored token. Mitigated by: (1) no third-party scripts loaded, (2) Content-Security-Policy header (see index.html meta tag), (3) GitHub Pages serves over HTTPS.
- **Revisit if:** The app loads any third-party script that could create an XSS vector.

---

## GitHub Pages Root Deployment (no subdirectory)

- **Date:** 2026-02-20
- **Decision:** Deploy from the root `/` of the `main` branch. All asset paths are relative.
- **Rationale:** Simplest possible GitHub Pages setup. No subdirectory path prefix to manage. Live URL is https://bhwilkoff.github.io/bskydreams — if the repo is named `bskydreams` this works directly; if not, the path prefix would need adjustment.
- **Alternatives considered:** A `/docs` publish directory (adds indirection), a separate `gh-pages` branch (requires a deploy workflow).
- **Trade-offs:** Main branch must always contain deployable code. Development happens on feature branches; only merge to main when tested.
- **Revisit if:** A build step is introduced, at which point a GitHub Actions workflow deploying a `/dist` output to `gh-pages` branch would be preferable.

---

## HLS.js Served Locally (no CDN)

- **Date:** 2026-02-20
- **Decision:** Bundle HLS.js v1.5.13 as `/js/hls.min.js` (downloaded once via `npm pack`, 413 KB) rather than loading it from a CDN.
- **Rationale:** The CSP `script-src 'self'` blocks scripts from any external origin. Loading HLS.js from unpkg/cdnjs would require relaxing script-src to include that CDN domain, increasing the attack surface. Serving locally keeps the strict `'self'` policy intact.
- **Alternatives considered:** CDN load with explicit domain in script-src (weakens CSP), inline script via data: URI (not permitted by 'self'), no video support (too much regression).
- **Trade-offs:** 413 KB added to the repo and served on every page load. No automatic HLS.js updates — must manually update when security fixes are released.
- **Revisit if:** HLS.js releases a security patch; update `hls.min.js` manually.

---

## CSP connect-src Widened to * for Video CDN Compatibility

- **Date:** 2026-02-20
- **Decision:** Changed `connect-src` from an explicit allowlist (`bsky.social cdn.bsky.app video.bsky.app`) to `*`.
- **Rationale:** HLS.js uses `fetch()` for every manifest and segment request. BlueSky's video CDN (`video.bsky.app`) may serve segments from, or redirect to, additional subdomains or Cloudflare edge nodes whose hostnames are not known at deploy time. An explicit allowlist silently blocked those fetches, causing all video to fail with a fatal HLS network error. Widening to `*` matches the already-permissive `img-src *` and `media-src *` posture; it is appropriate for a static site whose only sensitive network resource (the bsky.social auth token) is a request header, not a URL-embeddable secret.
- **Alternatives considered:** Adding known subdomains (*.bsky.app, *.bsky.network) — fragile because CDN topology is opaque. Cloudflare Worker proxy — adds infrastructure cost.
- **Trade-offs:** Removes network-destination restriction from CSP. XSS could exfiltrate data to arbitrary hosts. Risk is low: the app loads no third-party scripts (script-src 'self') and displays no user-controlled HTML (all output is HTML-escaped).
- **Revisit if:** A security audit recommends tighter egress control; at that point enumerate video CDN domains or adopt a proxy.

---

## AT Protocol Facets for Rich Text (TextEncoder/TextDecoder)

- **Date:** 2026-02-20
- **Decision:** Render post text using AT Protocol `record.facets` with byte-accurate UTF-8 slicing via `TextEncoder` / `TextDecoder` rather than character-index string slicing.
- **Rationale:** AT Protocol facets use byte offsets, not character offsets. A post containing emoji or non-ASCII characters will have byte offsets that do not match JavaScript string `.charAt()` indices. Using `TextEncoder.encode()` to convert to a `Uint8Array`, slicing by byte offset, then `TextDecoder.decode()` to reconstruct each segment is the only correct approach.
- **Alternatives considered:** Character-index slicing (incorrect for non-ASCII), regex-only linkification (misses hashtags and mentions, loses AT-defined boundaries).
- **Trade-offs:** Slightly more code than a simple regex fallback, but always correct.
- **Revisit if:** AT Protocol changes facet index semantics (unlikely given spec stability).

---

## History API Integration (pushState / popstate)

- **Date:** 2026-02-20
- **Decision:** Use the browser History API (`history.pushState`, `history.replaceState`, `window.popstate`) to make the Back and Forward buttons work across view transitions.
- **Rationale:** Without history integration, every navigation (search → thread → search) breaks the browser's Back button, and refreshing the page always resets to the auth screen. pushState lets each logical "page" (search results, open thread) live at a distinct history entry, matching user expectations.
- **Alternatives considered:** Hash-based routing (`#thread/...`) — simpler but produces ugly URLs and doesn't support Forward. Hash change events — no structured state object. A client-side router library — overkill for three views.
- **Trade-offs:** State is stored in `history.state` (not persisted across hard refresh). Opening a thread from a bookmark requires re-fetching the thread after re-login.
- **Revisit if:** Deep-link support (bookmarkable thread URLs) becomes a requirement; at that point encode the AT URI in the URL hash or path.

---

## CORS — No Proxy Needed (video.bsky.app uses open CORS)

- **Date:** 2026-02-20
- **Decision:** No Cloudflare Worker CORS proxy. Direct browser fetch to all bsky.social and video.bsky.app endpoints.
- **Rationale:** Testing confirmed that both `bsky.social/xrpc/*` and `video.bsky.app` serve `Access-Control-Allow-Origin: *`, permitting cross-origin requests from the GitHub Pages origin. The earlier "CORS watch item" concern proved unnecessary; the actual video failure was a CSP `connect-src` restriction (resolved separately).
- **Alternatives considered:** Cloudflare Worker free-tier proxy (would add infrastructure and latency).
- **Trade-offs:** If BlueSky changes their CORS policy, the app breaks with no fallback. No known plan to restrict CORS.
- **Revisit if:** Any fetch call returns a CORS error in the browser console.

---

## Image Upload via Raw Binary POST (not JSON)

- **Date:** 2026-02-21
- **Decision:** `com.atproto.repo.uploadBlob` is called with the raw `File` object as the request body (binary), with `Content-Type` set to the file's MIME type, rather than JSON-encoding the file data.
- **Rationale:** The AT Protocol `uploadBlob` endpoint explicitly requires raw binary POST — it is the only XRPC endpoint that is not JSON-encoded. The existing `authPost` helper always sets `Content-Type: application/json` and `JSON.stringify`s the body, making it unsuitable. A separate `uploadBlobRaw(file, token)` helper was added that calls `fetch` directly with the file as the body and the file's type as Content-Type.
- **Alternatives considered:** Base64-encoding the file and sending as JSON (not supported by the endpoint); using FormData (not supported — the endpoint expects raw binary, not multipart).
- **Trade-offs:** The `uploadBlobRaw` function bypasses the shared `post` helper. It still uses `withAuth` for token handling, so retry-on-401 works.
- **Revisit if:** AT Protocol changes uploadBlob to accept multipart or JSON.

---

## Image Upload Before Post Creation (separate async step)

- **Date:** 2026-02-21
- **Decision:** When the user attaches images in Compose, all blobs are uploaded sequentially via `Promise.all` before `createPost` is called. The resulting blob references (containing CID and mimeType) are passed as an `images` array to `createPost`, which embeds them as `app.bsky.embed.images`.
- **Rationale:** The AT Protocol requires blob CIDs at post-creation time — there is no way to attach a blob after a post is created. Uploading first and passing references to `createPost` is the only valid flow. `Promise.all` uploads in parallel for speed.
- **Alternatives considered:** Uploading one at a time sequentially (slower for multiple images), combining upload+post in a single transaction (not possible in AT Protocol).
- **Trade-offs:** If a blob upload succeeds but `createPost` fails, the uploaded blobs are orphaned in the repo (harmless but wasteful). The user sees the error and can retry; the blobs will eventually be garbage-collected.
- **Revisit if:** AT Protocol adds a transactional blob+post endpoint.

---

## Notifications: Load-on-Demand, No Polling

- **Date:** 2026-02-21
- **Decision:** Notifications are loaded the first time the user navigates to the Notifications view (or on manual Refresh), not on a timer or WebSocket push. The unread badge is populated from the first batch and cleared when the view is opened.
- **Rationale:** The app is a static GitHub Pages site with no server component. Persistent WebSocket subscriptions to the AT Protocol Firehose are not feasible. A polling timer would consume battery and bandwidth even when the user isn't looking at notifications. Load-on-demand is simpler and sufficient for the current use case.
- **Alternatives considered:** `setInterval` polling every 60 s (keeps badge fresh but burns resources); Firehose WebSocket (requires a relay server); Service Worker with background sync (complex, requires HTTPS and manifest).
- **Trade-offs:** Badge count and list are stale until the user taps Refresh or re-opens the view. Acceptable for an MVP.
- **Revisit if:** Users find the stale badge confusing; at that point add a 60-second polling interval with exponential back-off on error.

---

## URL Routing — Query-Parameter Based (Not Hash, Not Clean Paths)

- **Date:** 2026-02-21
- **Decision:** Use query-parameter routing (`?view=post&uri=...`) for all deep-linkable
  views. Hash routing and clean-path routing were both considered.
- **Rationale:** GitHub Pages always serves `index.html` from the root for the root
  path, but a request to `/post/at://...` would return a 404 because GitHub Pages has
  no server-side rewrite rules. Hash-based routing (`/#/post/...`) would work but
  produces visually noisier URLs and is harder to parse for sharing. Query parameters
  are served safely (the root `index.html` is always returned), are human-readable,
  and parse cleanly via `URLSearchParams`. The 404-redirect trick (adding a `404.html`
  that re-encodes the path as a query param) was also considered but adds a redirect
  hop and complexity that isn't justified at current scale.
- **Alternatives considered:** Hash routing (safe but ugly); clean paths with 404.html
  redirect trick (cleaner URLs but adds complexity and a redirect hop).
- **Trade-offs:** Query-param URLs are slightly longer than hash or clean-path URLs.
  Acceptable for a tool focused on clarity over aesthetics.
- **Revisit if:** A GitHub Actions deploy pipeline is added, at which point a proper
  SPA with a clean-path 404 rewrite to `index.html` becomes trivial.

---

## Cross-Device Persistence — AT Protocol Repo as Sync Backend

- **Date:** 2026-02-21
- **Decision:** User preferences, saved channels, and collections are stored as a
  JSON record in the user's own AT Protocol repository under the collection
  `app.bsky-dreams.prefs` with rkey `self`. Written via `com.atproto.repo.putRecord`,
  read via `com.atproto.repo.getRecord`. Falls back to localStorage if the record
  doesn't exist yet.
- **Rationale:** The zero-cost constraint rules out any traditional backend. The AT
  Protocol repo is effectively a user-owned, hosted key-value store. Since the user
  authenticates via app password to their own PDS (bsky.social), we already have
  write access to their repo. This gives free, cross-device sync with no additional
  infrastructure.
- **Alternatives considered:** localStorage only (no cross-device sync); export/import
  JSON file (manual and friction-heavy); Cloudflare Workers KV (free tier but adds
  infrastructure and an account dependency).
- **Trade-offs:** AT Protocol repo records are publicly readable by anyone who knows
  the DID + collection + rkey. Preferences (saved searches, UI settings) are
  non-sensitive, so this is acceptable. Users must be informed that their saved
  channels/collections are technically public. Secrets (passwords, tokens) must
  never be stored in this record.
- **Revisit if:** BlueSky adds private/encrypted record support to the AT Protocol spec.

---

## Saved Searches Sidebar — Mobile Drawer Pattern

- **Date:** 2026-02-21
- **Decision:** The saved searches ("channels") sidebar uses a responsive drawer
  pattern: pinned open on desktop (≥768px) alongside the main content area; on mobile
  it is hidden and revealed via a hamburger/channel-list button in the nav bar,
  sliding in as a full-height overlay drawer.
- **Rationale:** A persistent sidebar on mobile would leave too little horizontal
  space for content on typical phone widths (360–430px). The drawer pattern is the
  standard mobile solution (used by Gmail, Slack, Discord). It preserves the
  mobile-first single-column layout while making channels easily accessible.
- **Alternatives considered:** Channels as a dedicated nav tab (simpler, but loses
  the persistent-visibility benefit that makes Slack-style channels feel like live
  workspaces); bottom sheet (less discoverable).
- **Trade-offs:** Two layout modes (pinned vs. drawer) add CSS and JS complexity.
  The breakpoint at 768px matches the existing responsive breakpoints.
- **Revisit if:** A bottom navigation bar is introduced (e.g., for mobile tab bar),
  at which point channels could become a tab instead.

---

## Bsky Dreams TV — Splash Screen for Audio Autoplay

- **Date:** 2026-02-21
- **Decision:** The TV view requires a deliberate "▶ Start TV" user interaction
  before any video begins playing. This ensures the first video plays with audio
  enabled. Subsequent videos in the queue play with audio automatically.
- **Rationale:** Browsers (Chrome, Firefox, Safari) block audio autoplay until the
  page has received a user gesture. If the TV view started playing immediately on
  navigation, the first video would be muted and the user would have to hunt for an
  unmute button — poor UX. A dedicated Start button makes the audio-enabled experience
  reliable and intentional across all browsers.
- **Alternatives considered:** Auto-play muted with a prominent unmute button
  (standard for feed videos; less appropriate for a "TV" metaphor where sound is
  the primary experience).
- **Trade-offs:** One extra tap before content plays. Accepted as a worthwhile
  trade-off for reliable audio.
- **Revisit if:** The Web Audio API unlocking strategy (creating and resuming an
  AudioContext on first nav-btn click) proves reliable enough across browsers.

---

## Network Constellation — Search-Seeded, D3.js, Served Locally

- **Date:** 2026-02-21
- **Decision:** The constellation visualization seeds from a user-entered search
  term or hashtag (not the logged-in user's personal follow graph). D3.js v7 is
  served locally as `/js/d3.min.js` (no CDN) to maintain the `script-src 'self'` CSP.
- **Rationale:** A search-seeded graph is more broadly useful (any topic, any event)
  and avoids the privacy implication of automatically mapping the user's own social
  graph. D3.js is the standard library for force-directed graphs in the browser;
  serving it locally is consistent with the existing pattern for HLS.js.
- **Alternatives considered:** Seeding from the user's own network (more personal
  but narrower use case); Vis.js or Cytoscape.js (heavier, less battle-tested for
  force layouts); WebGL-based renderer (faster but much more complex).
- **Trade-offs:** D3.js adds ~270 KB to the repo. Graph construction from 100 posts
  is O(n) and fast; rendering >150 nodes may cause jank on low-end devices — cap
  enforced at 150 nodes.
- **Revisit if:** Performance testing shows the D3 force simulation is too slow on
  mobile; at that point consider a canvas-based renderer or WebWorker offloading.

---

## Direct Messages — Native BlueSky Chat API, Separate Base URL

- **Date:** 2026-02-21
- **Decision:** DMs are implemented via BlueSky's native `chat.bsky.convo.*`
  lexicon. This API uses a different base URL (`https://api.bsky.chat/xrpc/`) from
  the main AT Protocol endpoints (`https://bsky.social/xrpc/`). The same `accessJwt`
  is used for authentication. A dedicated `chatGet` / `chatPost` pair of helpers
  will be added to `api.js` using the chat base URL. Only 1:1 conversations are
  supported in the initial implementation.
- **Rationale:** BlueSky's native chat is the only zero-cost, standards-compliant
  way to implement real messaging. Building a custom messaging layer would require
  a backend. The separate base URL is a minor inconvenience handled cleanly by a
  second set of fetch helpers.
- **Alternatives considered:** Custom messaging via AT Protocol repo records (not
  real-time, not encrypted, not intended for chat); third-party messaging APIs
  (cost, privacy, not tied to BlueSky identity).
- **Trade-offs:** The `chat.bsky.convo.*` API is relatively new and documentation
  is sparse. Breaking changes are possible. Monitor AT Protocol changelog.
- **Revisit if:** Group chat becomes a priority or the chat API base URL changes.

---

## Quoted Post Rendering — Separate `buildQuotedPost` Card

- **Date:** 2026-02-21
- **Decision:** Quoted posts (`app.bsky.embed.record#view` and the record portion
  of `app.bsky.embed.recordWithMedia#view`) are rendered as a distinct compact card
  element (`buildQuotedPost`) rather than being folded into the existing post-card
  layout or ignored.
- **Rationale:** The AT Protocol distinguishes a quote-post (referencing another
  post's URI/CID) from a reply (parent/root refs). Visually collapsing them would
  confuse the two relationships. A separate compact card — author avatar, name,
  handle, truncated text — matches the pattern used by bsky.app and other clients.
  Clicking the quoted card opens *that* post's own thread, keeping navigation
  semantically correct.
- **Alternatives considered:** Rendering the quoted post as a nested full `buildPostCard`
  (too heavy — recursive action buttons, unnecessary complexity); ignoring the record
  embed entirely (was the previous behaviour — caused silent data loss for quote-posts).
- **Trade-offs:** The quoted card does not render facets on the inner text (plain
  `textContent`). This is acceptable for a truncated preview; the full text is one
  click away via the thread view.
- **Revisit if:** Quote chains (quoting a quote) need visual differentiation, or if
  non-post record types (lists, feeds, starter packs) need their own quoted-card styles.

---

## Feed Reply Context — Compact Parent Preview, Root-First Navigation

- **Date:** 2026-02-21
- **Decision:** When a feed item is a reply, display a compact clickable preview of
  the parent post above the reply card (`buildParentPreview`). Clicking either the
  preview card or the reply card itself navigates to the **root** of the thread
  (using `item.reply.root.uri`), not to the reply's own URI.
- **Rationale:** BlueSky's home timeline delivers replies mid-thread, often with no
  visible context. Without a parent preview, the reply appears orphaned. Root-first
  navigation ensures the user always sees the full conversation from the top, matching
  how Reddit and Mastodon handle reply surfacing in feeds. The parent `PostView` is
  already present in the timeline response (`item.reply.parent`) so no extra API
  call is needed.
- **Alternatives considered:** Fetching the full parent thread on render for richer
  context (extra API calls per feed item — too expensive); showing only a text label
  "Replying to @handle" (the previous behaviour — not enough context); opening the
  reply's own thread URI (disorienting — user lands mid-thread with no parent visible).
- **Trade-offs:** The parent preview shows only the first line of the parent text
  (single-line truncated). If the parent is a `notFoundPost` or `blockedPost` the
  preview is simply omitted (the `item.reply.parent.author` guard handles this).
- **Revisit if:** Users find the parent preview too visually heavy and want to hide it.

---

## Thread Depth Limit — 8 Levels, "Continue This Thread →"

- **Date:** 2026-02-21
- **Decision:** `renderThread` tracks nesting depth (0 = root, incremented on each
  recursive call). At depth ≥ 8 (i.e., the 8th level of replies), further recursion
  is replaced by a "Continue this thread →" button that re-opens the thread from
  that reply node.
- **Rationale:** Deep BlueSky threads can have 20+ levels of nesting. Rendering all
  of them causes DOM bloat and layout jank with the indented connector lines. Eight
  levels covers the vast majority of real conversations; deeper chains are rare and
  best read by navigating into them directly.
- **Alternatives considered:** No depth limit (DOM performance degrades on long
  chains); fixed 3-level cap (too shallow for normal discourse); collapsing the whole
  sub-tree (hides context rather than offering a path forward).
- **Trade-offs:** A very long chain requires multiple "Continue" navigations. This is
  acceptable — each navigation resets the view from a well-defined point.
- **Revisit if:** Users report that 8 levels is too shallow for their typical threads.

---

## Lightbox Carousel — Shared Image Array, startIndex

- **Date:** 2026-02-21
- **Decision:** `openLightbox(images, startIndex)` accepts an array of `{src, alt}`
  objects and an index. `buildImageGrid` builds a shared `lightboxPayload` array
  from all images in a post and passes it with the clicked image's index, so all
  images in the post are browsable from any starting thumbnail.
- **Rationale:** Single-image lightboxes are a baseline; posts with 2–4 images
  previously required closing and reopening for each image. Carousel navigation
  (arrows, dots, keyboard, swipe) is standard UX for multi-image posts.
- **Alternatives considered:** A separate lightbox gallery page (navigation cost);
  showing all images as a scrollable strip inside the lightbox (vertical vs. carousel
  — less common for this use case, harder to implement with captions per image).
- **Trade-offs:** The lightbox holds an in-memory copy of the image URL array;
  negligible for 2–4 URLs. Dot indicators are regenerated on every slide change
  (simpler than patching active state on existing dots).
- **Revisit if:** Video embeds need to be part of a mixed-media carousel.

---

## Adaptive Image Sizing — Natural Ratio for Singles, Fixed Crop for Grids

- **Date:** 2026-02-21
- **Decision:** Single-image posts use `object-fit: contain` with `max-height: 480px`
  and `min-height: 120px`, displaying the image at its natural aspect ratio against a
  black background. Multi-image grids (2–4 images) retain the uniform fixed-height
  crop (180px / 220px on desktop) for visual alignment.
- **Rationale:** Portrait screenshots and tall images (common on mobile) were
  previously sliced to a 180px landscape strip, hiding most of the content. Natural
  aspect ratio for single images fixes this without requiring the server to supply
  dimensions. Grids need uniform height to form a clean tiled layout; `contain` on
  a grid would leave irregular whitespace gaps.
- **Alternatives considered:** `aspect-ratio` CSS property set from image metadata
  (AT Protocol does not expose width/height in the image view object, so this is not
  available client-side without loading the image first); uniform height for all
  counts (reverts the portrait-image regression).
- **Trade-offs:** Very wide landscape images (panoramas) may leave black pillarboxing
  strips on the sides within the 480px box. This is visually acceptable and better
  than cropping.
- **Revisit if:** AT Protocol begins exposing image dimensions in the embed view, at
  which point CSS `aspect-ratio` can be set precisely before the image loads.

---

## Thread Nesting — Depth-Colored Left Border, No Connector Element

- **Date:** 2026-02-21
- **Decision:** Replace the old absolute-positioned `.reply-thread-connector` L-shaped
  element (which used `top: -8px` to overlap into the parent post card) with a clean
  `border-left` on the `.reply-group` element itself. The border color is driven by a
  CSS custom property `--thread-line-color` set via `[data-depth]` attribute selectors.
  Eight cycling colors (blue → violet → cyan → emerald → amber → red → orange →
  pink) distinguish nesting levels. Post cards inside each reply group also receive the
  same depth color as their `border-left`, making the relationship between connector
  lines and cards visually explicit. Each reply group has a small collapse button on
  the connector line that hides/shows the branch (Reddit-style).
  `renderThread` now sets `group.dataset.depth = depth + 1` on each reply group div.
- **Rationale:** The old connector element's `top: -8px` caused it to visually intrude
  into the post card above, making the thread tree look sloppy — post card outlines
  and the connector lines conflicted with no clear visual separation. Using `border-left`
  on the reply-group container ties the visual connector directly to the grouped content
  rather than requiring an absolutely-positioned child. No overflow, no z-index issues,
  no overlap with post card borders. Depth-colored card borders make the thread
  hierarchy immediately scannable. Eight colors (vs. the initial four) reduce color
  repetition in deeply nested discussions; collapsibility matches user expectations set
  by Reddit and Hacker News.
- **Alternatives considered:** Keeping the pseudo-element (`::before`) approach but
  adjusting geometry (tried; the overlap at the top remains hard to eliminate without
  either leaving a visual gap or covering the parent card's bottom border);
  avatar-column threading like Twitter/X (would require restructuring the post card
  layout to expose a consistent avatar column position across all card variants).
- **Trade-offs:** The left border of `.reply-group` starts at the very top of the group
  (top of the first reply card), with no visual "flow line" emerging from the parent
  card's avatar. This is visually clean but slightly less explicit than the L-connector
  metaphor. Depth colors compensate by making hierarchy immediately readable.
  The collapse button is 16px and sits on the 2px border-left; it requires
  `position: relative` on `.reply-group` but adds no meaningful layout cost.
- **Revisit if:** A more elaborate visual tree (avatar-threaded like X) becomes a
  design priority; at that point refactor post card layout to expose an avatar column.

---

## Inline Reply Compose — Context-Preserving, Toggle, Dismiss

- **Date:** 2026-02-21
- **Decision:** The global bottom-of-page reply form (`#thread-reply-area`) is
  replaced by an inline compose box inserted directly after the target post card in
  the DOM via `expandInlineReply(postCard, post)`. The old form remains in the HTML
  but is never shown. Only one inline box can exist at a time; opening a second closes
  the first; clicking Reply on the same card again toggles it closed.
- **Rationale:** The previous flow (reply button → scroll to bottom of thread → type
  reply) forced users to lose visual context of the post they were replying to. The
  inline approach keeps the parent post visible immediately above the textarea. This
  is the standard pattern on modern social platforms (Mastodon, GitHub issues) and is
  especially important in deep threads where the reply target may be far from the root.
- **Alternatives considered:** A fixed/sticky overlay panel at the bottom of the
  viewport showing the parent post preview (preserves context but covers thread
  content); a modal dialog (focus trap, harder to dismiss accidentally);
  keeping the bottom reply area but adding a "jump back to reply" anchor (user still
  loses visual context of the reply target mid-scroll).
- **Trade-offs:** The inline box is inserted into the thread content DOM, which means
  reloading the thread (after a successful post) destroys and rebuilds the DOM, closing
  the box. This is acceptable — the post was just submitted, so there is no unsaved
  draft to lose.
- **Revisit if:** Users want to attach images to replies from the thread view — at that
  point the inline box needs an image attachment flow similar to the Compose screen.

---

## Deferred Milestones — Paid API Dependencies

- **Date:** 2026-02-21
- **Decision:** Three proposed milestones are deferred pending research into
  zero-cost implementation paths: fact-checking (M27a), political bias analysis
  (M27b), and AI-generated content detection (M27c).
- **Rationale:** Each of these features, done well, requires a paid third-party API
  (ClaimBuster, Ground News, Hive, etc.). The project's zero-cost constraint rules
  these out at present. Partial implementations are possible (static datasets for
  domain-level bias; C2PA metadata check for AI detection) and are noted in the
  scratchpad, but full feature delivery is blocked on cost.
- **Revisit if:** The user decides to fund specific API keys, or an open/free
  alternative emerges (e.g., if BlueSky labelers provide standardized bias/AI labels).

