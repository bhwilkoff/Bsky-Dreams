# Autonomous Progress — Bsky Dreams polish loop (started 2026-10-08)

Goal (Ben, 2026-10-08): audit every surface against lessons from Tidbits Trivia / Archive Watch /
UniversalAppTemplate, fix + improve, and **submit new builds to the App Store**.

## Release model
- iOS build: bump `BskyDreams-iOS/Bsky Dreams/AppVersion.xcconfig` (MARKETING +0.01, BUILD +1) →
  push → `gh workflow run appstore-build.yml -f platform=ios` (cloud = the compile gate).
- Submit: `tools/asc_release.py ship --platform ios --notes-file … --wait-build-minutes 40 --submit`
  (local, `/usr/bin/python3`, creds from `../Archive-Watch/tools/asc-credentials.env`).
- Only ONE version can be in review at a time → batch iOS fixes into a release; while a version is
  WAITING_FOR_REVIEW / IN_REVIEW, keep working (web, next iOS batch) and ship the next build after.
- **No local simulators** (Ben, 2026-10-08). Real devices only; cloud build is the compile gate.
- Web deploys from `main` (GitHub Pages). `main` is stale since 2026-04-01 — all June web work is
  only on the default branch. Merging to main = deploying the live site → needs Ben's go-ahead.

## Cadence
`tick % 5`: 1,2,4 = iOS · 3 = web · 0 = opt (net-remove lines). Release when an iOS batch is ready.

## Backlog — iOS
(iOS surface audit pending — see below when added)
- [x] Share Extension deployment target 26.2 → 18.6 (was invisible on iOS 18.6–26.1) — 396775a
- [x] NBImageLoader.downsample read UIScreen off-main → scale captured on main, nonisolated
- [ ] Accessibility-size layouts: ViewThatFits action bar, @ScaledMetric avatars, .isHeader on section titles (AW iOS-DESIGN §3.5c/§4.5a)
- [ ] Liquid Glass decision on iOS 26 (behind #available) vs. rule 1.5 regularMaterial — DECISIONS entry first
- [ ] "Not affiliated with Bluesky Social PBC" line in Settings/About + review notes (4.1 copycat risk; BOBA rejection lesson)
- [ ] App-password login sanity on iPad sizes (2.1(a) BOBA lesson) — app is iPhone-only so low priority
- [ ] DEBUG launch doors (BSKY_START_VIEW etc.) for device testing — M
- [ ] Siri/App Shortcuts + NSUserActivity handoff on Conversation/Profile — M (later)
- [ ] Analytics view: Swift Charts (SCRATCHPAD "Next for iOS")
- [ ] Profile interaction graph port (SCRATCHPAD)

## Backlog — Web (audit 2026-10-08, verified file:line in js/app.js unless noted)
P0 security
- [ ] Shared `safeUrl()` (http/https only) for link facets (~8792), link cards (~6908), Stream card href (~5728, also unescaped attr); unify `escapeHTML`(5496, doesn't escape quotes) → `escHtml`(8740)
- [ ] Reader: sanitize Readability output before innerHTML (~2667) — strip form/meta/base/style/iframe/on*, non-http hrefs
- [ ] Single `signOut()` (duplicates at ~558 & ~3224): clear seen map + cancel seen-sync timer (cross-account leak), stop DM polling, clear view content
P1 bugs
- [ ] Search/Notifications infinite scroll dies after back-nav (observers not reconnected, ~3046/3051/3141); feedSeenObserver too
- [ ] Gallery/Reader: one failed source marks cursor 'done' forever (~1793, ~2273) → keep cursor, surface error+retry
- [ ] Inline feed videos keep playing / Hls leaks after leaving view (~6792) → pause + destroy in showView
- [ ] DM polling races: capture convoId before await (~9946); send advances lastMessageId and skips others' msgs (~10323)
- [ ] api.js:60 token refresh: shared in-flight promise; treat 400 ExpiredToken like 401
- [ ] Constellation: any single word → profile mode (~10625); only @ / contains '.' / did:
- [ ] 9 inline onerror= avatar fallbacks blocked by CSP → one delegated capture listener
P2
- [ ] Console-only errors → showBanner (follow 3501/3561/4440, repost 6056, like 6654, TV 5090/5444/5465, search scroll 3342, DM list 9942)
- [ ] Offline banner (lime) via online/offline events
- [ ] a11y: remove user-scalable=no (index.html:5); dark-mode legible link color; #888 text contrast; modal focus mgmt + Escape; keyboard-openable post cards; aria-live flooding; <main> + skip link
P3
- [ ] theme boot script in <head> + prefers-color-scheme default; analytics chart bg in dark
- [ ] manifest icons 192/512 + maskable; orientation conflict
- [ ] defer d3/hls/Readability
- [ ] dedupe OG-fetch/link-preview ×3, thumbnail upload ×3 (opt tick)

## Tick log

### Tick 0 — 2026-10-08 — release tooling + audit
- Audits: sibling lessons, ASC tooling, web surfaces, iOS surfaces (agents).
- Shipped: `tools/asc_release.py` + `appstore-submit.yml` (17444f0); Share Extension floor fix (396775a).
- ASC status: live 1.46; build 48 (1.47) uploaded 2026-06-30 never submitted (TestFlight-expired).
- Next: fold in iOS audit, ship iOS batch 1 → build 49 → submit.
