# Bsky Dreams — Architecture & Technology Decisions

Entries are ordered roughly by date. Superseded entries have been removed.

---

## No Framework — Vanilla HTML/CSS/JS
*2026-02-20*

Plain HTML/CSS/JS, no build step. GitHub Pages serves static files; framework abstractions cost more than they save at this scale. React/Vue/Svelte all rejected for requiring a build step. Trade-off: manual DOM manipulation, no reactive state. Revisit if component count exceeds ~20 or DOM work becomes error-prone.

---

## AT Protocol HTTP API via fetch (no SDK)
*2026-02-20*

Direct `fetch` against XRPC endpoints. `@atproto/api` requires a bundler; CDN build is unstable and bloated. Trade-off: manual request construction, must track lexicon changes. Token refresh in `auth.js`. Revisit if Firehose/WebSocket or complex record operations are needed.

---

## App Passwords for Authentication
*2026-02-20*

App passwords only — recommended by BlueSky for third-party clients, independently revocable, scoped permissions. AT Protocol OAuth not yet stable. Trade-off: one extra setup step, mitigated by in-app instructions.

---

## localStorage for Session Persistence
*2026-02-20*

Session (`accessJwt`, `refreshJwt`, handle, DID) stored under `bsky_session`. No server available; localStorage survives reloads and restarts; credentials only sent to bsky.social. XSS risk mitigated by no third-party scripts, strict CSP, HTTPS. Revisit if any third-party script is loaded.

---

## GitHub Pages Root Deployment
*2026-02-20*

Deploy from root `/` of `main`. No subdirectory prefix to manage. Trade-off: main must always be deployable — dev on feature branches only. Switch to a `gh-pages` Actions workflow if a build step is introduced.

---

## Third-Party Libraries — Served Locally (no CDN)
*2026-02-20 – 2026-03-10*

All third-party JS (`hls.min.js`, `d3.min.js`, `Readability.js`) served from `/js/`. CSP `script-src 'self'` blocks CDN scripts. Trade-off: manual updates for security fixes; HLS.js adds 413 KB, D3 ~270 KB, Readability ~80 KB.

---

## CSP connect-src Widened to `*`
*2026-02-20*

HLS.js fetches video manifests via `fetch()`; BlueSky's CDN redirects to Cloudflare edge nodes with unpredictable hostnames. Explicit allowlist is too fragile. Risk is low: `script-src 'self'` still blocks foreign scripts and all output is HTML-escaped. Revisit if a security audit demands tighter egress.

---

## AT Protocol Facets — Byte-Accurate UTF-8 Slicing
*2026-02-20*

Post text rendered via `record.facets` using `TextEncoder`/`TextDecoder` for byte-offset slicing. AT Protocol facets use byte offsets, not JS character indices — plain `.charAt()` is wrong for non-ASCII. Character-index slicing and regex-only linkification both rejected.

---

## History API Routing (pushState / popstate)
*2026-02-20*

Browser History API for Back/Forward across view transitions. Without it, every navigation breaks the Back button. Hash routing produces ugly URLs with no Forward; a router library is overkill. Trade-off: state lost on hard refresh.

---

## CORS — No Proxy for bsky.social
*2026-02-20*

Direct `fetch` to `bsky.social` and `video.bsky.app` — both serve `Access-Control-Allow-Origin: *`. The original concern was unfounded; the video issue was CSP (fixed separately). Revisit if a CORS error appears in the console.

---

## Image Upload via Raw Binary POST
*2026-02-21*

`com.atproto.repo.uploadBlob` called with raw `File` body and `Content-Type` set to the file's MIME type. It's the only non-JSON XRPC endpoint; Base64 JSON and FormData are both unsupported.

---

## Blobs Uploaded Before Post Creation
*2026-02-21*

All blobs uploaded via `Promise.all` before `createPost`. AT Protocol requires blob CIDs at post-creation time — no post-hoc attachment. Trade-off: orphaned blobs if `createPost` fails (GC'd eventually).

---

## Notifications — Load-on-Demand, No Polling
*2026-02-21*

Notifications load on first navigation to the view. No server, no Firehose possible from a static site. `setInterval` polling rejected (battery/bandwidth). Trade-off: badge may be stale until user refreshes.

---

## URL Routing — Query Parameters
*2026-02-21*

`?view=post&uri=...` style routing. GitHub Pages can't rewrite clean paths; hash routing works but produces ugly URLs. Scheme: Thread `?view=post&uri=...&handle=...`, Profile `?view=profile&actor=...`, Search `?q=...&filter=posts`. `init()` parses `window.location.search` after session loads. bsky.app URLs auto-converted to AT URIs via `API.resolvePostUrl()`. Each card has a copy-link button (1.5s feedback). Revisit if a CI/CD pipeline enables clean-path SPA rewrites.

---

## Cross-Device Prefs — AT Protocol Repo
*2026-02-21*

Preferences stored as JSON in `app.bsky-dreams.prefs` / rkey `self` via `putRecord`/`getRecord`; falls back to localStorage. Zero-cost constraint rules out a traditional backend; the PDS is effectively a user-owned key-value store. Trade-off: records are publicly readable — non-sensitive prefs only, never secrets.

---

## Sidebar — Always-Open Desktop, Drawer Mobile
*2026-02-25 (evolved through M38, finalized M43)*

`#channels-sidebar` holds all navigation. Desktop (≥768px): always visible, top bar hidden. Mobile: slide-in drawer via hamburger. Replaces the `body.sidebar-open` toggle from M38 which caused localStorage dependency and layout jitter. Top bar disappears on desktop; breadcrumb context via sidebar active state only.

---

## Channel Unread Checking — Once Per Session
*2026-02-21*

`checkChannelUnreads()` runs once after login, fetching the latest 5 posts per channel with 700ms spacing. Per-channel polling and Firehose both rejected (too expensive or require a server). Trade-off: badges stale later in the session.

---

## TV — Splash Screen for Audio Autoplay
*2026-02-21*

"▶ Start TV" button required before any video plays. Browsers block audio autoplay without a user gesture. Auto-play muted with an unmute button was rejected as inconsistent with the "TV" metaphor.

---

## TV — Two-Slot Slide System + Dual-Feed Seeding
*2026-02-24*

Two `position: absolute` video containers (`tv-slide-a/b`) swap roles per transition, enabling simultaneous outgoing/incoming `translateY` animations. Feed seeded from `getTimeline()` + `getFeed(DISCOVER_FEED_URI)` in parallel; custom topics fire hashtag + plain-text searches in parallel. Single `<video>` can't animate out while a new one animates in; dual seeding overcomes video sparsity in a single feed. Trade-off: two HLS instances live simultaneously. Revisit if low-end devices show memory pressure.

---

## Network Constellation — Search-Seeded, D3.js
*2026-02-21*

Constellation (M14) seeded from a user-entered search term, not the follow graph. D3.js v7 served locally. Search-seeded graph avoids mapping the user's social graph without intent. Vis.js and Cytoscape.js rejected as heavier; WebGL rejected as complex. Cap at 150 nodes to avoid jank.

---

## Direct Messages — Native Chat API
*2026-02-21*

`chat.bsky.convo.*` at `https://api.bsky.chat/xrpc/` with the same `accessJwt`. `chatGet`/`chatPost` helpers in `api.js`. Only zero-cost, standards-compliant option. Custom AT Protocol repo messaging (not real-time/encrypted) and third-party APIs both rejected. Monitor AT Protocol changelog; docs are sparse.

---

## Quoted Posts — Compact `buildQuotedPost` Card
*2026-02-21*

Quoted posts render as a compact card (avatar, name, handle, truncated text). Clicking opens the quoted thread. Nested full `buildPostCard` is too heavy with recursive action buttons; ignoring record embeds caused silent data loss. Trade-off: no facet rendering in quoted card preview.

---

## Feed Reply Context — Parent Preview, Root-First Navigation
*2026-02-21*

Replies in the feed show a compact `buildParentPreview` above the reply card. Clicking either card navigates to the thread root. Parent `PostView` is already in the timeline response — no extra fetch needed. Full thread fetch on render is too expensive; "Replying to @handle" label was insufficient. Preview omitted if parent is `notFoundPost` or `blockedPost`.

---

## Thread Depth Limit — Depth 4, "Continue This Thread →"
*2026-02-21 (lowered from 8 to 4 in M46)*

`renderThread` stops at depth ≥ 4, replacing further recursion with a "Continue this thread →" button. The button uses `pushState` so Back returns to the parent; a "← Back to parent thread" breadcrumb appears via `history.state`. At ~12px indent per level, depth 5+ causes horizontal overflow on 375px screens; depth 4 leaves ~315px. Revisit if users find 4 levels too shallow.

---

## Lightbox Carousel — Shared Array, startIndex
*2026-02-21*

`openLightbox(images, startIndex)` takes an `{src, alt}[]` array. `buildImageGrid` passes a shared `lightboxPayload` so all post images are browsable from any thumbnail. Scrollable strip inside the lightbox was rejected as less standard.

---

## Adaptive Image Sizing
*2026-02-21*

Single images: `object-fit: contain`, `max-height: 480px`. Grids (2–4): fixed-height crop (180px / 220px desktop). Preserves portrait screenshots that were previously cropped to landscape strips; grids need uniform height for clean tiling. AT Protocol embed views don't expose width/height metadata. Trade-off: wide panoramas may pillarbox.

---

## Thread Nesting — Depth-Colored Left Border
*2026-02-21*

`border-left` on `.reply-group` driven by `[data-depth]` CSS selectors — 8 cycling colors. Reddit-style collapse button on the connector line. Old `top: -8px` connector element intruded into the card above; `border-left` on the container eliminates overflow and z-index issues. `::before` pseudo-element had the same overlap problem; avatar-column threading requires layout restructure.

---

## Inline Reply Compose — Context-Preserving
*2026-02-21*

`expandInlineReply(postCard, post)` inserts a compose box directly after the target card. One box at a time; opening a second closes the first; tapping Reply again toggles it. Keeps the parent post visible while composing. Fixed overlay, modal, and scroll-to-anchor all rejected for losing context. Trade-off: DOM rebuild on successful post closes the box (acceptable).

---

## Discover Feed — `whats-hot`, Default Tab
*2026-02-24*

"Discover" tab uses `at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot` via `getFeed`. Two-tab toggle (Following / Discover); Discover is default (`feedMode = 'discover'`). Provides a populated feed on first load; tab bar is the lightest toggle on mobile. Trade-off: feed content policy controlled by BlueSky — update the constant if the URI changes.

---

## Elastic Overscroll Suppression
*2026-02-24*

`overscroll-behavior: none` on `.view` (the actual scroll container, not `body`). Without it, iOS Safari and Android Chrome rubber-banded inside `.view`. `overscroll-behavior: contain` still allows bounce within the element. Intentional suppression — the app implements its own PTR gesture.

---

## Mention Links — DID in Data Attribute + Event Delegation
*2026-02-24*

Mention facets store the DID in `data-mention-did` on the `<span>`. Listeners wired via `querySelectorAll('[data-mention-did]')` inside `buildPostCard()` after `innerHTML` is set. `renderPostText()` returns an HTML string so direct listener attachment during construction isn't possible. Refactoring to return DOM nodes rejected as too large a change.

---

## Like Button — Optimistic Update with Rollback
*2026-02-24*

UI updates (class, count, SVG fill) applied before the API call; on error a closure snapshot restores prior state; button disabled during the request. Non-optimistic updates feel laggy; the old code had no rollback and left UI desynced on failure.

---

## Timestamp as External Link to bsky.app
*2026-02-24*

Relative-time badge wrapped in `<a href="https://bsky.app/profile/{handle}/post/{rkey}" target="_blank">`. The `rkey` is `uri.split('/').pop()`. Falls back to a plain `<time>` element if handle/rkey are unavailable. Gives users an escape hatch to the official app for unsupported actions. Revisit when the app covers all major post actions.

---

## GIF Detection — Hostname + Extension Heuristic
*2026-02-24 (Klipy added 2026-02-25)*

`isGifExternalEmbed()` checks for `tenor.com`, `c.tenor.com`, `giphy.com`, `media.giphy.com`, `klipy.com`, or a `.gif` URL path. Matching embeds render as `<img>` via `buildGifEmbed()`. MIME sniffing (requires HEAD per embed) and always-as-image (breaks link cards) both rejected. Revisit if BlueSky adds a native GIF `$type`.

---

## Quote Post — Action Sheet on Repost Button
*2026-02-24*

Repost button opens a two-option sheet: "Repost / Undo repost" and "Quote Post". Quote opens a modal with a compose textarea and read-only quoted-post preview. Matches native BlueSky UX; avoids adding another button to the crowded actions row. Trade-off: plain repost now takes two taps.

---

## iOS Safari PWA — `visibilitychange` JWT Refresh
*2026-02-24*

`visibilitychange` listener checks `accessJwt` expiry on every foreground. Proactively refreshes if within 15 minutes of expiry; clears session and shows auth screen if fully expired. Safari PWA suspends JS timers while backgrounded — `setInterval`, JWT decode on every API call, and Service Worker sync all rejected as unreliable. Trade-off: one async op on every foreground; offline failures let the original token expire naturally.

---

## PTR Resistance — Two-Stage Threshold
*2026-02-24 (reduced from 96px to 48px in M65)*

Pull-to-refresh requires ≥ 48px drag *plus* 400ms hold before `ptrReadyToRelease` is true. Hold timer prevents accidental triggers from fast scrolls. The 400ms delay is imperceptible in use.

---

## Seen-Posts Deduplication — Viral Threshold + Escape Hatch
*2026-02-24*

Seen posts stored as `Map<uri, { seenAt, likeCount, repostCount }>` in `bsky_feed_seen` (5,000-entry FIFO). Posts are filtered unless engagement grew by ≥ 50 since first view. "N posts filtered (show anyway)" link bypasses the filter for the session. Simple blocklist misses resurging content; time-based expiry ignores engagement. Threshold of 50 is arbitrary — revisit based on user feedback.

---

## OG Link Preview — allorigins.win Proxy
*2026-02-25*

OG metadata fetched via `https://api.allorigins.win/get?url=…`, parsed with `DOMParser`. Thumbnail uploaded as a blob at submit time so native Bluesky renders a rich card. Direct `fetch` blocked by CORS; Cloudflare Worker adds infrastructure; skipping thumbnail upload produces a bare text link. Trade-off: allorigins.win has no SLA; preview silently skips on failure. Revisit if it becomes unreliable.

---

## Thread Gate and Post Gate via putRecord
*2026-02-25*

After `createPost`, non-default restrictions create `app.bsky.feed.threadgate` and/or `app.bsky.feed.postgate` records with rkey matching the post's rkey. AT Protocol requires these as separate records post-creation. Trade-off: two extra API calls; silent failure leaves the post published without restrictions (acceptable — restrictions rarely used).

---

## GIF Provider — Klipy as External Embed
*2026-02-25*

GIFs posted as `app.bsky.embed.external` with the Klipy CDN URL; `xs.jpg` thumbnail uploaded as blob. BlueSky's AppView CDN transcodes blobs to JPEG, stripping animation — CDN URL reference is the only way to preserve it (same approach as Tenor/Giphy in the native app). Trade-off: Klipy not yet on BlueSky's animated-GIF allowlist (issue #9728); native app shows thumbnail only. No code change needed when allowlist is updated.

---

## Scroll-Based Seen Marking — Full-Viewport IntersectionObserver
*2026-02-25*

`IntersectionObserver` with `rootMargin: '0px'` and `threshold: 0`. Marks seen when `isIntersecting === false` AND `boundingClientRect.top < 0`. The original `-80%` rootMargin meant fast-scrolled posts never entered the top-20% detection zone and were never marked seen. `-100%` rootMargin is equivalent but less forgiving on slow scrolls.

---

## Deferred Milestones — Paid API Dependencies
*2026-02-21*

Fact-checking (M27a), political bias (M27b), and AI content detection (M27c) deferred — each requires a paid API (ClaimBuster, Ground News, Hive, etc.). Partial zero-cost paths exist: static dataset for domain-level bias, C2PA metadata for AI detection. See SCRATCHPAD.md. Revisit if API keys are funded or free alternatives emerge.

---

## Analytics Charts — Native Canvas API
*2026-03-08*

M22 charts use the browser Canvas 2D API. Chart.js blocked by CSP and requires a build pipeline; locally-bundled Chart.js (≥ 60 KB) too large for one bar chart; D3.js overkill for simple charts. Trade-off: verbose custom rendering, manual ARIA labels, no animations. Revisit if multiple new chart types justify the overhead.

---

## Timeline Scrubber — Fractional Time Offset + 220px Minimum Step
*2026-03-08*

Cards positioned absolutely using `(postMs - firstMs) / spanMs`. Minimum 220px step between cards prevents overlap when posts cluster in time. Pure proportional layout collapses clusters to unclickable regions. Trade-off: visual position may not perfectly reflect exact time in dense clusters; axis ticks remain accurate. Revisit if users report temporal confusion.

---

## Timeline Scrubber — MutationObserver Toggle Visibility
*2026-03-08*

"List / Timeline" toggle appears only after a successful post search, detected via `MutationObserver` on `#search-results`. Hides when no `.post-card` elements present or `lastSearchType !== 'posts'`. Avoids modifying the async search handler's control flow. Direct handler modification (tighter coupling), `setInterval` (wasteful), and custom events (more ceremony) all rejected.

---

## Reader View — Three-Proxy CORS Fallback Chain
*2026-03-10*

Article HTML fetched via **codetabs.com → corsproxy.io → allorigins.win**, each with 18s `AbortController` timeout. First response ≥ 500 chars passed to Readability. allorigins.win times out (HTTP 408) on large pages; codetabs.com is most reliable for full pages. Trade-off: up to 54 seconds before all three fail; users see live per-proxy progress. Revisit if codetabs.com rate-limits.

---

## PTR Indicator — Fixed Position, Shared Across Views
*2026-03-10*

`#ptr-indicator` is `position: fixed; top: -52px`, sibling to all view sections. JS uses `style.top` (not `style.marginTop`). Previously lived inside `#view-feed .view-inner` and was invisible when other views were active. Duplicating per-view (DOM bloat) and dynamic reparenting (fragile) both rejected. Hidden on desktop via `@media (min-width: 768px)`.
