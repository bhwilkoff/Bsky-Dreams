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

## CORS Watch Item — Potential Cloudflare Worker Proxy

- **Date:** 2026-02-20
- **Decision:** No proxy at this time. Direct browser fetch to `https://bsky.social/xrpc/*`.
- **Rationale:** BlueSky's public XRPC endpoints include CORS headers that permit cross-origin requests from browsers. Authenticated endpoints also support CORS. A proxy is not needed.
- **Alternatives considered:** Cloudflare Worker free-tier proxy (would add a layer of infrastructure and latency).
- **Trade-offs:** If BlueSky changes their CORS policy, the app breaks with no fallback.
- **Revisit if:** Any fetch call returns a CORS error in the browser console. In that case, create a Cloudflare Worker that forwards requests and add it as a configurable proxy base URL.
