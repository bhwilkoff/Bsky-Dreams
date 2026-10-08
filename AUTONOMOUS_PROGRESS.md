# Autonomous Progress — Bsky Dreams polish loop (started 2026-10-08)

Goal (Ben, 2026-10-08): audit every surface against lessons from Tidbits Trivia / Archive Watch /
UniversalAppTemplate, fix + improve, and **submit new builds to the App Store**.

## Release model
- iOS build: bump `BskyDreams-iOS/Bsky Dreams/AppVersion.xcconfig` (MARKETING +0.01, BUILD +1) →
  push → `gh workflow run appstore-build.yml -f platform=ios` (cloud = the compile gate).
- Submit: `tools/asc_release.py ship --platform ios --notes-file … --wait-build-minutes 40 --submit`
  (local, `/usr/bin/python3`, creds from `../Archive-Watch/tools/asc-credentials.env`).
- **Submit for review ONCE, at loop end** (Ben, 2026-10-08: "You shouldn't submit an interim build
  for review"). Cloud builds mid-loop are fine as the compile gate / TestFlight. 1.48 (49) was
  submitted by mistake and withdrawn → version 1.48 is DEVELOPER_REJECTED (editable); `ship` will
  rename it to the final MARKETING_VERSION and attach the final build.
- **No local simulators** (Ben, 2026-10-08). Real devices only; cloud build is the compile gate.
- Web deploys from `main` (GitHub Pages). `main` is stale since 2026-04-01 — all June web work is
  only on the default branch. Merging to main = deploying the live site → needs Ben's go-ahead.

## Cadence
`tick % 5`: 1,2,4 = iOS · 3 = web · 0 = opt (net-remove lines). Release when an iOS batch is ready.

## Backlog — iOS
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
- [x] Console-only errors → showBanner (follow 3501/3561/4440, repost 6056, like 6654, TV 5090/5444/5465, search scroll 3342, DM list 9942)
- [x] Offline banner (lime) via online/offline events
- [~] a11y (done: zoom, dark link color, contrast, modal focus/Esc/trap, link underline; TODO: keyboard-openable post cards, aria-live flooding, <main>+skip link): remove user-scalable=no (index.html:5); dark-mode legible link color; #888 text contrast; modal focus mgmt + Escape; keyboard-openable post cards; aria-live flooding; <main> + skip link
P3
- [x] theme boot script in <head> + prefers-color-scheme default; analytics chart bg in dark
- [ ] manifest icons 192/512 + maskable; orientation conflict
- [ ] defer d3/hls/Readability
- [ ] dedupe OG-fetch/link-preview ×3, thumbnail upload ×3 (opt tick)

## Tick log

### Tick 0 — 2026-10-08 — release tooling + audit
- Audits: sibling lessons, ASC tooling, web surfaces, iOS surfaces (agents).
- Shipped: `tools/asc_release.py` + `appstore-submit.yml` (17444f0); Share Extension floor fix (396775a).
- ASC status: live 1.46; build 48 (1.47) uploaded 2026-06-30 never submitted (TestFlight-expired).
- Next: fold in iOS audit, ship iOS batch 1 → build 49 → submit.

### Tick 1 — 2026-10-08 — iOS batch 1 (built as 1.48/49; review submission withdrawn)
- Facet crash, offline logout + refresh races, mention/hashtag facets, like/repost URI, unblock,
  timestamps, feed auto-fetch + tab race, search adult filter, ModelContainer once. Cloud build ✅.

### Tick 2 — 2026-10-08 — web P0 + P1 (873b15c, 0fb8ede)
- safeUrl/sanitizer/escaping, single signOut; shared refresh, cursor-on-failure, paging re-arm,
  video pause, DM poll races, CSP-safe avatar fallback, constellation mode.

### Tick 3 — 2026-10-08 — iOS batch 2 (uncommitted→committed below, local compile ✅)
- Reader Readable mode renders with JS off + escaped title; lightbox loader via URLSession +
  stale-URL guard; sign-out confirm + label; Password AutoFill; real badge counts (getUnreadCount,
  DM unread); failed posts kept + retry banner; app-level action-error banner (gallery/reader);
  TV hands audio back + ignores foreign end notifications; PTR keeps content (thread/profile);
  thread skeleton/error per contract; seen-cloud record capped + clear clears cloud.

## Remaining iOS backlog (from 2026-10-08 audit)
- [x] Dynamic Type: reading text → `.scaledSystemFont` (post body, names, bios, chat, actor rows); rule §4.3
- [x] Dark mode: 41 foreground sites → nbLinkColor / nbAccentLegible (logo keeps raw accent)
- [x] Offline banner: `.nbOfflineBanner()` on DMs list+chat, Gallery, Analytics, Constellation, Timeline (TV/Stream immersive — intentionally none)
- [~] Hand-rolled error states → NBErrorBanner: Gallery + DMs done; Feed 285, Analytics 91 remain
- [x] AsyncImage in churn lists → CachedImage (RetryAsyncImage = feed single image + video thumbs, quoted video, Reader, TV). Stream/Profile banner left (no churn)
- [x] Background notif fetch never refreshes token; saveDeliveredIDs keeps random 500
- [x] Notifications getPosts >25 URIs not chunked; loadMore w/o cursor refetches page 1 (also Profile)
- [x] DMs: optimistic bubble + poll duplicate; poller not cancelled on re-appear
- [x] Stream: no moderation filter; 1Hz Timer.publish in body
- [x] Gallery duplicate SeenPost inserts
- [ ] Gallery/Stream pagination stall on all-filtered page
- [ ] Heavy main-thread work (MainActor default isolation): compose resize/video read/GIF decode
- [x] Analytics Retry loads signed-in user instead of viewed account
- [x] Notification permission prompt on login screen → after sign-in
- [x] VoiceOver: video play/fullscreen, retry, gallery+reader like/repost, MARK READ
- [x] Contrast: white on lime → near-black
- [x] Dead code removed (-328 lines): test views, stale plist, scrollToTopTrigger ×4, Analytics harness
- [x] Share Extension PrivacyInfo.xcprivacy (verified bundled in .appex)
- [ ] Docs: Analytics is a working Swift Charts view (SCRATCHPAD says shell); link cards are 160pt vertical

### Tick 4 — 2026-10-08 — iOS a11y: Dynamic Type for system-font text + dark-mode foregrounds

### Tick 5 — 2026-10-08 — opt: -328 lines (dead test views, stale Info plist, unused triggers, preview harness)

### Tick 6 — 2026-10-08 — iOS logic bugs: paging, DM dupes, Stream moderation, background notif auth (Stream 1Hz timer kept: documented rotation fallback)

### Tick 7 — 2026-10-08 — web a11y + states: zoom, link token, contrast, dialog manager, offline banner, visible errors, theme boot (browser smoke ✅)

### Tick 8 — 2026-10-08 — iOS: CachedImage in churn surfaces, offline modifier, error banners, VoiceOver, lime contrast, extension privacy manifest

### Tick 9 — 2026-10-08 — web keyboard/live-regions + REAL-DEVICE verification begins
- Ben: verify on devices, not just the SDK. Test devices = iPhone 12 + iPad Pro 12.9 (NOT the
  personal 15 Pro — a Debug build was installed there once by mistake). `tools/device_smoke.py`.
- iPhone 12 (wired): login title "BSKY DREAMS" clipped both edges at 390pt → shrink-to-fit. ✅ device
- iPad Pro 12.9 (landscape): iPhone-compat window renders app content ROTATED 90°. Adding landscape to
  UISupportedInterfaceOrientations~ipad made no difference (reverted). OPEN: asked Ben whether the
  physical screen is sideways or only the devicectl capture. App Review tests on iPad → must resolve.
- iPhone 12 Wi-Fi: `transport None` (Mac can't discover it; same as AW's ATV note) — cable works.

### Tick 10 — 2026-10-08 — device-review fixes (iPhone 12, signed in as test account) ✅ device
- Adversarial screenshot review of 6 screens. Fixed + re-shot: NeubrutalistButtonStyle label color
  from fill luminance (black on #0047FF was 3.35:1 → white 6.3:1; all 7 accents handled) + uppercase;
  empty-state titles uppercase; Search row one ScaledMetric height + shadows; sort toggle joins the
  mode toggle's component family; Reader strips "www.".
- Backlog (polish): notifications end-of-list cue; Reader hint banner inset vs cards; nav→content top
  gap varies 5–11pt; toolbar box heights (MARK READ vs hamburger); notification permission asked
  seconds after first sign-in → ask at a meaningful moment (HIG).

### Tick 11 — 2026-10-08 — iPad fixes (device-verified) + WEB DEPLOYED
- iPad sideways: AppDelegate.supportedInterfaceOrientationsFor returned .portrait at runtime (overrode
  plist). iPad hardware → .all. ✅ upright on iPad Pro 12.9.
- iPad window controls overlapped the leading nav button → NBWindowControls.leadingInset (56pt, iPad
  hardware only) in NBNavBar + FeedNavBar. ✅ device (dark mode).
- Web: PR #120 merged → main → Pages built; live site verified serving new code (cache-busted).
  Ben: deploy web myself from now on.

### Tick 12 — 2026-10-08 — second device review (7 screens) → all fixed + re-verified on iPhone 12 ✅
- Conversation: quoted preview collapses newlines (blank 3rd line); root accent bar on card edge.
- Constellation: forces rebalanced (repulsion was ~100× weaker than gravity → knot + label collisions);
  Reset View uses NeubrutalistButtonStyle; duplicate counter dropped.
- Analytics: LOAD stretches to field height (label lifted above row); "Pick an account" pre-load state.
- NBTextField placeholder → nbTextSecondary (system placeholder ~1.7:1) — login too.
- TV splash: black-bordered/shadowed chips, field, card; selected chip label via Color.nbLabel(on:);
  Toggle no longer squeezes title; errors → NBErrorBanner.
- Settings: duplicate SETTINGS heading → thin Memphis stripe band. Profile tiles captioned.
- Timeline: "1d" in Inter (Syne 1 → ı); shadows on zoom/date controls.
- NEW: repost attribution ("Reposted by X") on iOS Profile + Following (web parity — web had it).
- Web: PWA icons 192/512 + maskable, orientation any — deployed (PR #121), live-verified.
- Tooling: Xcode-beta was deleted by another session mid-run → device_smoke uses release Xcode 27.1,
  which lists HARDWARE UDIDs (both id forms now supported).

### Tick 13 — 2026-10-08 — iOS: error primitives, off-main compose work, paging stalls
- Feed + Analytics first-load errors → NBErrorBanner + Haptics.error (last hand-rolled error screens).
- resizeImageData nonisolated + run detached (Compose + inline reply); video size from file attributes,
  read off-main (.mappedIfSafe); photo-load failures surfaced.
- Gallery + Stream: a fully-filtered page no longer stalls paging (bounded auto-advance); Stream no
  longer claims a connection failure for an all-seen page.
- Compiles with release Xcode 27.1; Home + Gallery re-checked on iPhone 12.

### Tick 14 — 2026-10-08 — web opt (-14 lines) + live site checked in iPhone Safari ✅
- fetchOgEmbed() + uploadEmbedThumb() replace 3 copies each (compose/quote/inline reply), now with
  AbortSignal timeouts on the third-party proxy + CDN fetches. Deployed.
