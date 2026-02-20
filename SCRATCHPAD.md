# Project Scratchpad — Bsky Dreams

## Current Status

Initial project scaffold has been created. The repository was empty; this
session establishes the foundational file structure, living documents
(CLAUDE.md, DECISIONS.md, README.md), and the full application source
(index.html, css/styles.css, js/auth.js, js/api.js, js/app.js). The app
implements all three MVP features — Posting, Searching, and Conversation
View — using the BlueSky AT Protocol HTTP API directly via fetch. No build
step is required. The app is deployable immediately to GitHub Pages from the
main branch root.

## Active Milestone

**Milestone 1 + 2 combined: Interface + API Integration**

Completed in this session:
- [x] Initial project scaffold (directories, CLAUDE.md, SCRATCHPAD.md, DECISIONS.md, README.md)
- [x] index.html with three-panel layout: Auth, Search/Feed, Compose, Conversation View
- [x] css/styles.css — mobile-first, CSS custom properties, WCAG AA contrast
- [x] js/auth.js — app-password login, session stored in localStorage
- [x] js/api.js — all AT Protocol API calls (login, search, getThread, post, like, repost)
- [x] js/app.js — UI orchestration, event handlers, view transitions

Remaining for future sessions:
- [ ] Milestone 3: Individual interaction buttons (like, repost, follow) fully wired
- [ ] Milestone 4: Alt text display and authoring for images/video

## Completed Milestones

None fully signed off yet (first session).

## Open Questions

1. **App password flow**: The MVP uses BlueSky "App Passwords" (Settings → App Passwords). This is the recommended approach for third-party apps. Is this acceptable UX, or should we surface clearer in-app instructions for generating an app password?
2. **CORS**: bsky.social's public API endpoints are accessible from the browser without a proxy. Authenticated endpoints also work cross-origin. If a CORS error appears in future testing, a Cloudflare Worker proxy may be needed (logged in DECISIONS.md as a watch item).
3. **Alt text milestone (M4)**: The spec calls for alt text as "primary text" for images. Should this mean alt text shown prominently above/instead of the image, or shown on hover/tap?

## Blockers

None currently. The BlueSky public API (bsky.social/xrpc) supports CORS for browser requests. If this proves incorrect during live testing, a Cloudflare Worker CORS proxy will be needed (zero cost, free tier).

## Next Session Starting Point

1. Test the app locally: open `index.html`, log in with a BlueSky app password, run a search, open a thread, post a reply.
2. Wire up like/repost buttons fully (Milestone 3) — the UI elements exist but the API calls need to be connected to each post card's action row.
3. Implement Milestone 4 alt text display: show alt text prominently beneath each image in thread and search views, and expose an alt-text input in the compose/reply form.
4. Review DECISIONS.md and confirm technology choices before any refactoring.
