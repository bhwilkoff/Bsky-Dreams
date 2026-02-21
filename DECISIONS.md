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
