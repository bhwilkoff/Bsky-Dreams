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
- **Scheme:**
  - Thread: `?view=post&uri=at%3A%2F%2F...&handle=...`
  - Profile: `?view=profile&actor=handle.bsky.social`
  - Search: `?q=query&filter=posts`
  - Feed: `?view=feed` / Notifications: `?view=notifications`
- **On navigation:** `openThread` and `openProfile` include the full URL in their
  `pushState` calls. `showView` adds view-specific URL params. Successful searches
  use `replaceState` to update the URL without adding a history entry.
- **On load:** `init()` parses `window.location.search` and passes `URLSearchParams`
  to `enterApp()`, which routes to the correct view after the session profile loads.
- **Bsky.app URL import:** Search input detects `bsky.app/profile/.../post/...`
  patterns and uses `API.resolvePostUrl()` to convert them to AT URIs. Profile URLs
  are detected and redirected to `openProfile`.
- **Copy link:** Each post card has a chain-link icon button that copies the full
  Bsky Dreams URL (`window.location.origin + pathname + ?view=post&uri=...`) to the
  clipboard. Shows a 1.5-second "Copied!" color feedback.
- **Alternatives considered:** Hash routing (safe but ugly); clean paths with 404.html
  redirect trick (cleaner URLs but adds complexity and a redirect hop).
- **Trade-offs:** Query-param URLs are slightly longer than hash or clean-path URLs.
  Acceptable for a tool focused on clarity over aesthetics.
- **Revisit if:** A GitHub Actions deploy pipeline is added, at which point a proper
  SPA with a clean-path 404 rewrite to `index.html` becomes trivial.

---

## Channels Sidebar — Fixed Position + CSS Offset Content

- **Date:** 2026-02-21
- **Decision:** The channels sidebar uses `position: fixed` (not in-flow) and the
  main content area is offset with `padding-left: var(--sidebar-width)` on `.view`
  and `top-bar-inner` on desktop (≥768px). On mobile the sidebar is a full-height
  slide-in drawer with a 220px width.
- **Rationale:** The fixed approach keeps the sidebar out of the scroll flow so it
  never scrolls away. The CSS offset approach avoids restructuring the existing
  HTML (which would require wrapping all view sections in a new flex container).
  `--sidebar-width: 220px` as a CSS custom property makes the offset consistent
  across `.view` padding and `.top-bar-inner` padding in a single source of truth.
- **Alternatives considered:** Flex row layout wrapping sidebar + views (cleaner
  structurally but requires HTML reorganization); no sidebar (feature-reducing).
- **Trade-offs:** `padding-left` on `.view` means on very narrow desktop screens
  (768–860px) the content area is narrower than the 640px `max-width` target. At
  768px: 768px − 220px sidebar = 548px available — which is still readable. The
  `max-width: 640px` on `.view-inner` will simply expand to fill 548px at that
  breakpoint, since `max-width` only caps, not forces.
- **Revisit if:** A bottom navigation bar is introduced for mobile, at which point
  channels could be a full-page view instead.

---

## Channels Unread Checking — Load-on-Login, Throttled, Session-Once

- **Date:** 2026-02-21
- **Decision:** Unread counts for channels are checked once per login session via
  `checkChannelUnreads()`, which runs as a background async task after `enterApp()`
  resolves. It fetches the latest 5 posts per channel and counts posts with
  `createdAt` > `channel.lastSeenAt`. API calls are spaced 700ms apart. No polling.
- **Rationale:** Polling (e.g., every 60s) would consume battery and bandwidth even
  when not interacting with channels. Checking once per login is predictable, low
  cost, and matches user expectations (badge is fresh on load, not necessarily live).
- **Alternatives considered:** Per-channel polling on a 60-second interval (too
  expensive for many channels); WebSocket Firehose subscription (requires server
  infrastructure); not checking at all (no unread counts).
- **Trade-offs:** Badges may be stale by the time the user looks at them later in
  the session. Acceptable for the current use case. If the user opens a channel and
  then comes back, they won't see a fresh unread count until next page load.
- **Revisit if:** Users find stale badges confusing; at that point add a manual
  "Refresh channels" button or a lightweight polling interval.

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

---

## Discover Feed — `whats-hot` URI, Tab-Based Toggle

- **Date:** 2026-02-24
- **Decision:** The "Discover" tab on the home feed uses BlueSky's official What's Hot
  feed generator at
  `at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot` via
  `app.bsky.feed.getFeed`. The home feed header is a two-tab toggle (Following /
  Discover) rather than a dropdown or separate nav entry.
- **Rationale:** `whats-hot` is the canonical AT URI for BlueSky's curated discovery
  feed as documented in the official BlueSky API docs and used by bsky.app itself. The
  rkey `discover` does not exist and returns a "Could not locate record" error. A tab
  bar is the lightest-weight toggle pattern and consistent with how other social clients
  (Twitter/X, Mastodon Elk) handle algorithm switching. Adding a separate nav entry would
  clutter the nav bar.
- **Alternatives considered:** A dropdown/select on the feed header (less discoverable
  on mobile); a separate "Discover" nav tab (adds nav clutter); using a third-party feed
  generator URI (unnecessary dependency when the official one exists).
- **Trade-offs:** The `whats-hot` feed is curated by BlueSky and its content policy
  cannot be influenced by the app. If BlueSky changes the feed URI or deprecates the
  generator, the URI constant in `app.js` must be updated manually.
- **Revisit if:** BlueSky publishes a more personalized discovery endpoint, or if a
  user-configurable "feed picker" (selecting from pinned feeds in their AT Protocol
  repo) is implemented.

---

## Elastic Overscroll Suppression — `overscroll-behavior: none` on `.view`

- **Date:** 2026-02-24
- **Decision:** Added `overscroll-behavior: none` to the `.view` CSS rule (the
  `overflow-y: auto` scroll container used by all views).
- **Rationale:** `body` already had `overscroll-behavior: none` to suppress the
  browser pull-to-reload gesture. However, `.view` is the *actual* scroll container
  for the thread, profile, notifications, and feed pages. Inner scroll containers are
  subject to their own overscroll behavior, independent of `body`. Without the property
  on `.view`, iOS Safari and Chrome on Android both exhibited elastic rubber-banding
  when scrolling to the edge of content in those views.
- **Alternatives considered:** Setting `overscroll-behavior: contain` (allows inner
  scroll without propagating to the body — rejected because `.view` IS the outermost
  scroll container and `contain` still allows the bounce within the element itself).
- **Trade-offs:** Suppresses the bounce effect entirely; this is intentional. The app
  implements its own pull-to-refresh gesture, making the native bounce unnecessary and
  confusing.
- **Revisit if:** A native-feel bounce is desired for any specific view.

---

## Bsky Dreams TV — Two-Slot Slide System + Dual-Feed Seeding

- **Date:** 2026-02-24
- **Decision:** TV uses two `position: absolute` video containers (`tv-slide-a`,
  `tv-slide-b`) that swap roles on each transition, enabling simultaneous outgoing and
  incoming CSS `translateY` animations. The TV queue is seeded from custom topic search
  using `Promise.allSettled()` across a hashtag search and a text search in parallel.
- **Rationale:** A single `<video>` element cannot transition out while a new one
  transitions in. The two-slot pattern (used by TikTok, YouTube Shorts, Instagram Reels)
  is the standard approach. `Promise.allSettled()` for dual search ensures hashtag results
  (high video density) are combined with text results (broader coverage) without either
  search failure blocking the other.
- **Alternatives considered:** Single video element with a CSS fade transition (no
  directional slide possible); three slots with a recycled queue (more complex, no
  benefit at queue sizes we use); single search only (was the prior implementation —
  returned no results for most custom topics).
- **Trade-offs:** Two HLS instances (`tvHlsArr[0]`, `tvHlsArr[1]`) exist simultaneously;
  the off-screen slot's instance is kept alive (paused) to enable instant back-navigation.
  Memory cost is acceptable for video on a mobile device.
- **Revisit if:** Memory pressure on low-end devices causes crashes; at that point destroy
  the off-screen Hls instance immediately after the transition.

---

## Discover Feed as Default + `whats-hot` URI

- **Date:** 2026-02-24
- **Decision:** The home feed opens to the Discover (What's Hot) feed by default.
  `feedMode` initialises to `'discover'`; the Discover tab is marked `feed-tab-active`
  in the HTML so there is no flash of the wrong active tab on load. The Following tab
  remains one tap away and the user's choice is remembered per session via the tab
  click handler.
- **Rationale:** New and returning users benefit from a populated discovery feed on
  first load rather than an empty Following feed. Following is always one tap away,
  so no content is hidden.
- **Trade-offs:** Users who primarily use Following must tap once per session. If this
  proves annoying, a localStorage preference (`bsky_feed_default`) could persist the
  user's last-used tab.
- **Revisit if:** User feedback indicates Following is more commonly desired as default.

---

## Channels Sidebar Hidden by Default on Desktop

- **Date:** 2026-02-24
- **Decision:** The channels sidebar is hidden by default on all screen sizes, including
  desktop. The user opens it via the hamburger/channels toggle in the nav bar. The last
  open/closed state is persisted in `localStorage` under `bsky_sidebar_open` and restored
  on login. `body.sidebar-open` controls the content offset CSS (`padding-left` on `.view`
  and `.top-bar-inner`) on desktop; the class is added/removed by `openSidebar()` /
  `closeSidebar()`.
- **Rationale:** Most first-time users have no saved channels, so an empty sidebar wastes
  horizontal space and creates visual clutter. Power users who do have channels will
  reopen it and the preference is remembered.
- **Alternatives considered:** Always-visible on desktop (previous behaviour — too
  aggressive for new users); separate nav tab for channels (reduces nav bar to fewer
  options but loses the persistent-workspace feel).
- **Trade-offs:** Users who relied on the always-open desktop sidebar need to open it
  once; thereafter the preference is saved.
- **Revisit if:** Channels become a core part of the app's identity, at which point
  defaulting to open (with a channel count badge visible) may be worthwhile.

---

## Mention Links — DID-based Navigation via Data Attribute + Event Delegation

- **Date:** 2026-02-24
- **Decision:** Mention facets (`app.bsky.richtext.facet#mention`) embed the DID directly
  in a `data-mention-did` attribute on the rendered `<span>`. Click/keyboard handlers are
  wired via `querySelectorAll('[data-mention-did]')` inside `buildPostCard()` after the
  card's inner HTML is set. `openProfile(did)` is called with `stopPropagation()`.
- **Rationale:** `renderPostText()` returns an HTML string (set via `innerHTML`), so
  direct event listener attachment is not possible during construction. Embedding the
  DID in a data attribute and delegating from `buildPostCard` after innerHTML is set is
  the minimal, correct pattern. DIDs are available directly in AT Protocol mention facets
  — no handle-resolution round-trip is needed.
- **Alternatives considered:** Switching `renderPostText` to return DOM nodes instead of
  an HTML string (large refactor, not justified); event delegation on the whole card
  (would require checking the target on every card click, slightly less clean).
- **Trade-offs:** One `querySelectorAll` per card render. Negligible performance cost
  for the number of cards rendered at any given time.
- **Revisit if:** `renderPostText` is refactored to return DOM nodes, at which point
  listeners can be attached directly.

---

## Like Button — Optimistic Update with Rollback

- **Date:** 2026-02-24
- **Decision:** The like button applies the UI change (toggle class, count, SVG fill)
  before the API call resolves. On API error, the pre-change state is restored from a
  snapshot taken before the update. The button is disabled during the in-flight request
  to prevent double-tap issues.
- **Rationale:** Optimistic updates make the interaction feel instant on slow connections.
  The previous code updated inside the `try` block (not truly optimistic — it waited for
  the API) but had no error rollback, so a failed API call would leave the UI in a wrong
  state. The fix snapshot-then-update-then-rollback-on-error pattern is the standard
  approach for social media interactions.
- **Alternatives considered:** Non-optimistic (update only after API confirms) — correct
  but laggy on slow mobile connections; no rollback (previous behaviour) — leaves UI
  desynced from server.
- **Trade-offs:** A snapshot of three fields (likeUri, count text, class) is held in
  closure for the duration of each API call. Negligible memory cost.
- **Revisit if:** The AT Protocol adds a batch-interaction endpoint; at that point
  queuing interactions and flushing them in bulk would be more efficient.

---

## Timestamp as External Link to bsky.app

- **Date:** 2026-02-24
- **Decision:** The relative-time badge on each post card is wrapped in
  `<a href="https://bsky.app/profile/{handle}/post/{rkey}" target="_blank" rel="noopener">`.
  The `rkey` is derived from the AT URI (`uri.split('/').pop()`). Falls back to a plain
  `<time>` element if handle or rkey cannot be determined.
- **Rationale:** Tapping the time badge is a natural affordance for "see the original
  post" — this is standard behaviour on most social clients. It gives users a quick
  escape hatch to the official Bluesky app, which is important for actions the app
  doesn't yet support.
- **Trade-offs:** Opens bsky.app in a new tab, which leaves the app in the background.
  Acceptable since it's an intentional navigation to an external resource.
- **Revisit if:** The app adds all major post actions and there is less reason to link
  out to bsky.app; at that point the link could be removed or made optional.

---

## GIF Detection — Hostname + URL Extension Heuristic (M29)

- **Date:** 2026-02-24
- **Decision:** GIF embeds are detected via `isGifExternalEmbed(external)` which checks
  the hostname for `tenor.com` / `c.tenor.com` / `media.giphy.com` / `giphy.com` and also
  checks whether the URL path ends in `.gif`. Matching embeds are rendered as `<img>` via
  `buildGifEmbed()`, which swaps Tenor `.mp4` URLs to `.gif` for animated display.
- **Rationale:** GIFs posted to BlueSky via Tenor/Giphy are attached as
  `app.bsky.embed.external` link cards, not as image blobs. The browser's native `<img>`
  element handles GIF animation without any autoplay policy restrictions, unlike `<video>`.
  Hostname-based detection is reliable because only these two services are used for GIF
  embedding in practice.
- **Alternatives considered:** MIME type sniffing (requires a HEAD request per embed —
  too slow); always rendering external links as images (breaks ordinary link card display);
  treating all `.gif` URLs as GIFs without hostname check (could falsely match favicon URLs).
- **Trade-offs:** If Tenor or Giphy change their CDN domain structure, the hostname list
  must be updated.
- **Revisit if:** BlueSky adds native GIF support (dedicated embed type), at which point
  a `$type` check would be cleaner than a hostname heuristic.

---

## Quote Post — Action Sheet on Repost Button (M30)

- **Date:** 2026-02-24
- **Decision:** The existing repost toggle button is replaced with a two-option action
  sheet (`showRepostActionSheet`): "Repost / Undo repost" and "Quote Post". Quote posts
  open a full modal with a compose textarea and a read-only quoted-post preview card.
  Plain reposts retain the existing toggle behavior inside the sheet.
- **Rationale:** The native BlueSky app uses the same action-sheet pattern for the repost
  button. Splitting into a sheet avoids adding a new button to the already-crowded post
  actions row, and makes "Quote Post" discoverable without requiring users to learn a
  separate button.
- **Alternatives considered:** Separate "Quote" button on the actions row (too crowded);
  right-click / long-press context menu (not discoverable on mobile); repost always opens
  modal (breaks the fast "just repost" flow).
- **Trade-offs:** Reposting now requires two taps (button → sheet option) instead of one.
  Acceptable given the added value of quote posting.
- **Revisit if:** User testing shows the extra tap is consistently annoying for plain
  reposts; at that point a one-tap repost with a separate quote button may be preferable.

---

## iOS Safari PWA Session Persistence — `visibilitychange` JWT Refresh (M32)

- **Date:** 2026-02-24
- **Decision:** `auth.js` session management is augmented with a
  `document.visibilitychange` listener in `app.js`. On `document.hidden === false`
  (page becomes visible), the stored `accessJwt` expiry (`exp` from the JWT payload)
  is checked. If within 15 minutes of expiry, `AUTH.refreshSession(refreshJwt)` is
  called proactively. If fully expired, the session is cleared and the auth screen
  is shown with a message.
- **Rationale:** Safari standalone PWA mode suspends JavaScript timers while the app
  is backgrounded. A `~2-hour accessJwt` can expire between launches without any
  in-app timer firing. The `visibilitychange` event is the only reliable hook that
  fires immediately on cold launch or app foreground.
- **Alternatives considered:** `setInterval` polling (suspended by Safari background
  throttling); decoding JWT `exp` on every API call in `api.js` (adds latency to every
  request); Service Worker background sync (requires additional manifest configuration
  and is unreliable on iOS).
- **Trade-offs:** Adds one async operation on every app foreground. If the refresh API
  call fails (network offline), the original token remains in use and will expire
  naturally; the next API call will attempt a refresh via the existing `withAuth` 401 retry.
- **Revisit if:** AT Protocol introduces shorter `refreshJwt` TTLs, at which point more
  aggressive proactive refresh (checking both tokens) would be needed.

---

## PTR Resistance — Two-Stage Threshold (M34)

- **Date:** 2026-02-24
- **Decision:** Pull-to-refresh requires a drag of ≥ 96px (up from 64px) *plus* a 400ms
  hold at that distance before `ptrReadyToRelease` becomes `true`. Both conditions must
  be met before releasing triggers a refresh.
- **Rationale:** The 64px threshold caused accidental refreshes when users quickly
  scrolled past the top of the feed. The hold timer ensures only deliberate, sustained
  pulls trigger a refresh — a pattern used by iOS's native pull-to-refresh.
- **Trade-offs:** Slightly slower to trigger for intentional pulls. The 400ms delay is
  imperceptible in practice; users holding the pull past 96px are clearly intentional.
- **Revisit if:** The 400ms hold proves too long for users with motor-impairment concerns
  or accessibility feedback; at that point make the hold duration configurable.

---

## Seen-Posts Deduplication — Map + Viral Threshold + Show-Anyway Escape (M40)

- **Date:** 2026-02-24
- **Decision:** Seen feed posts are stored as `Map<uri, { seenAt, likeCount, repostCount }>`
  in `localStorage` under `bsky_feed_seen` with a 5,000-entry FIFO cap. Posts are filtered
  before render unless their engagement has grown by ≥ 50 interactions since first view
  (the "gone viral" threshold). A "N posts filtered (show anyway)" link below the feed
  bypasses the filter for the current session.
- **Rationale:** Deduplication prevents the frustrating experience of seeing the same posts
  repeatedly across feed reloads and tab switches. The viral threshold resurfaces genuinely
  popular content without requiring any server-side intelligence. The show-anyway escape
  hatch respects user agency — some users may want to revisit posts.
- **Alternatives considered:** Simple URI blocklist with no viral threshold (misses
  resurging content); time-based expiry (20-minute TTL) rather than engagement-based
  (doesn't account for slow-to-trend posts); server-side dedup (not possible without
  a backend).
- **Trade-offs:** The viral threshold of 50 is arbitrary. Very popular posts on large
  accounts may still not resurface if their like count grew by fewer than 50 while the
  user wasn't looking. Acceptable for a first implementation.
- **Revisit if:** User feedback suggests the threshold is too high or too low; at that
  point expose it as a configurable preference.

---

## TV Dual-Feed Queue + Short-Clip Filter + Pause + 2× Hold (M36)

- **Date:** 2026-02-24
- **Decision:** Four enhancements were added to Bsky Dreams TV in a single milestone:
  (1) The no-topic queue seeds from both `API.getTimeline()` and `API.getFeed(DISCOVER_FEED_URI)`
  in parallel; (2) `loadVideoInSlot()` skips videos with `duration < 5s` or `.gif` source
  URLs; (3) a pause/resume button (`tv-pause-btn`) was added to the playback controls bar;
  (4) holding the pointer on the video area (not on a button) sets `playbackRate = 2`,
  releasing restores to `1`.
- **Rationale for dual-feed**: The timeline alone is sparse in video content for accounts
  that follow few video creators. Adding Discover gives access to the broader "what's hot"
  pool without requiring a topic filter. `Promise.allSettled()` ensures one failure doesn't
  block the other.
- **Rationale for short-clip filter**: Very short clips (< 5s) include animated preview
  stills, GIF-loops, and preview segments that are not satisfying as standalone TV content.
  The `durationchange` listener fires once the duration is known, keeping the check lazy.
- **Rationale for pause**: Users interrupted during TV viewing had no way to hold a frame.
  The pause button is the most universally expected video control.
- **Rationale for 2× hold**: Common in TikTok and YouTube Shorts for quickly previewing
  less interesting clips. `pointerdown`/`pointerup` events are cross-device (touch + mouse)
  and cleaner than separate `touchstart`/`mousedown` pairs.
- **Trade-offs**: Two HLS instances are active simultaneously (for slide transitions); the
  2× speed hold applies only to the currently active slot. Pausing blocks `advanceToNext()`
  so video-end auto-advance is suppressed while paused.
- **Revisit if:** Memory pressure on low-end devices becomes an issue; at that point
  destroy the off-screen HLS instance after each transition.


---

## Sidebar Navigation Redesign — Always-Open Desktop, Drawer Mobile (M43)

- **Date:** 2026-02-25
- **Decision:** The existing `#channels-sidebar` element was expanded to contain all
  navigation (logo, own-profile, nav items, channels, sign-out). On desktop (≥768px) the
  sidebar is always visible (`left: 0`, no class required, no toggle). The top bar shrinks
  to zero height on desktop. On mobile the sidebar is a slide-in drawer triggered by a
  hamburger in the top bar.
- **Rationale:** Moving all navigation into a persistent sidebar matches standard
  desktop app patterns (Slack, Discord, Gmail). The always-open approach eliminates the
  confusing `body.sidebar-open` toggle that M38 introduced, which required persisting
  state in localStorage and caused content-layout jitter. Mobile drawer behavior is
  preserved because full-width sidebars are impractical on small screens.
- **Alternatives considered:** Keeping the horizontal top-bar nav on desktop (original
  design — limited space for new entries); always-open with a toggle-collapse button
  (adds persistent icon-only "mini mode" complexity not justified at current scale).
- **Trade-offs:** The top bar disappears entirely on desktop, so breadcrumb context (e.g.,
  current view name) is visible only via sidebar active state. Profile dropdown moves to
  the sidebar own-profile button rather than a popover from the top bar. `closeSidebar`
  no-ops on desktop — no accidental closure.
- **Revisit if:** A breadcrumb or view-title bar becomes necessary for deeper navigation;
  at that point restore a slim header bar above the content area.

---

## OG Link Preview via allorigins.win Proxy (M41)

- **Date:** 2026-02-25
- **Decision:** When a URL is pasted/typed in any compose surface, OpenGraph metadata is
  fetched via `https://api.allorigins.win/get?url=…` (a free, open CORS proxy) and parsed
  with the browser's DOMParser. Title and description are rendered as editable inputs in
  a dismissible preview card. The embed is sent as `app.bsky.embed.external` without a
  thumbnail blob (thumbnail URL is shown in the preview card for visual reference only).
- **Rationale:** Direct `fetch()` of third-party pages is blocked by CORS in browsers.
  `allorigins.win` is the lightest zero-cost proxy that returns the raw HTML response.
  Skipping the thumbnail blob upload avoids an extra API call per post and keeps the
  compose flow fast; the AT Protocol spec allows `app.bsky.embed.external` without a
  `thumb` field.
- **Alternatives considered:** Cloudflare Worker proxy (adds infrastructure); server-side
  OG fetch (no server available — static Pages deployment); thumbnail blob upload (adds
  latency and a second upload step).
- **Trade-offs:** `allorigins.win` is a third-party service with no SLA. If it is down,
  link preview silently fails (the compose flow is unaffected). The external embed appears
  in BlueSky feeds without a thumbnail image, which is less visually rich than the native
  client's cards.
- **Revisit if:** `allorigins.win` becomes unreliable or rate-limits requests; at that
  point self-host a Cloudflare Worker proxy.

---

## GIF Picker — Tenor API v2, User-Supplied Key (M41)

- **Date:** 2026-02-25
- **Decision:** GIF search uses the Tenor API v2 (`tenor.googleapis.com/v2/search`). The
  API key is entered by the user via a `prompt()` dialog and stored in `localStorage`
  under `bsky_tenor_api_key`. Selected GIFs are fetched as blobs and attached as
  `app.bsky.embed.images` (single image, `image/gif` MIME).
- **Rationale:** Tenor has a free tier (no cost for the user) but requires an API key.
  Storing the key client-side in localStorage is consistent with the existing app-password
  storage pattern. Attaching as an image blob follows the existing `uploadBlob` path with
  no additional API surface needed.
- **Alternatives considered:** Giphy (different API, similar key requirement); hardcoding
  a shared API key (violates Tenor's TOS and creates rate-limit risk); no GIF support.
- **Trade-offs:** Users must supply their own Tenor API key — an extra setup step.
  GIF blobs can be large (multi-MB); the existing `API.uploadBlob` has no size guard
  for GIFs (unlike images which go through `resizeImageFile`).
- **Revisit if:** Tenor changes its free-tier terms or the API endpoint; or if a
  bundled key arrangement becomes available.

---

## Thread Gate and Post Gate via putRecord (M41)

- **Date:** 2026-02-25
- **Decision:** After a successful `createPost`, if the user has selected non-default
  reply or quote restrictions, `API.putRecord` is called to create:
  - `app.bsky.feed.threadgate` (reply restriction) with `allow` array containing
    `#mentionRule` or `#followingRule`
  - `app.bsky.feed.postgate` (quote restriction) with `embeddingRules` containing
    `#disableRule`
  The rkey for both records matches the post's rkey (last segment of the AT URI).
- **Rationale:** AT Protocol requires threadgate and postgate to be separate records
  stored in the repo after the post itself is created. `putRecord` with the same rkey
  as the post is the prescribed approach.
- **Trade-offs:** Two extra API calls after each restricted post. If either call fails,
  the post is published without the intended restriction. Silent failure is acceptable
  given how rarely non-default restrictions are set; a retry UI would add disproportionate
  complexity.
- **Revisit if:** AT Protocol introduces a transactional post+gate creation endpoint.

---

## Scroll-Based Seen Marking — IntersectionObserver at -80% rootMargin (M44)

- **Date:** 2026-02-25
- **Decision:** A shared `IntersectionObserver` with `rootMargin: "0px 0px -80% 0px"`
  and `threshold: 0` marks a post as "seen" when its top edge exits the top 20% of
  the viewport (i.e., the post has been scrolled fully past). The observer is created
  after each `renderFeedItems()` call and disconnected when leaving the feed view.
- **Rationale:** The previous "mark all rendered posts as seen immediately" approach
  was too aggressive — posts near the bottom of the first render batch were marked seen
  before the user ever scrolled to them. The -80% rootMargin means only posts that have
  been actively scrolled past are counted, matching the intuitive definition of "read."
- **Alternatives considered:** -100% rootMargin (fires when card is completely above
  viewport — equivalent but less forgiving on slow scrolls); explicit scroll-position
  tracking per card (complex, not needed given IntersectionObserver's reliability).
- **Trade-offs:** Very fast scrollers may skip posts without triggering the observer.
  This is acceptable — rapid scroll-past is not reading.
- **Revisit if:** Users report that seen-post filtering is too aggressive (posts being
  filtered that they have not actually read).
