# Project Scratchpad — Bsky Dreams

## Current Status

The app is fully functional for daily Bluesky use. Milestones 1–12, 19–51, 37, 39, and 42 are complete,
along with a GIF provider migration (Tenor → Klipy) and several polish/bug-fix passes.

**Next focus:** M22 (analytics), M13 (timeline scrubber), M14 (constellation), M16 (DMs).

---

## Completed Milestones

### M1 + M2: Interface + API Integration ✅
- Initial project scaffold (index.html, css/styles.css, js/auth.js, js/api.js, js/app.js)
- Three-panel layout: Auth screen, Search/Feed, Compose, Conversation View
- AT Protocol API integration (login, search posts/actors, get thread, create post)
- App-password auth with session stored in localStorage

### M3: Interaction Buttons ✅
- Like / Unlike: toggle with live count update, `data-like-uri` on button
- Repost / Unrepost: toggle with live count update, `data-repost-uri` on button
- Reply: opens thread view and focuses reply textarea
- Follow / Unfollow: toggle on actor (people) search result cards

### M4: Media + Rich Text ✅
- **Images**: full-size grid, click-to-lightbox overlay with alt text caption
- **Video**: HLS.js v1.5.13 poster + play-to-activate; muted autoplay; error fallback link
- **External link cards**: thumbnail + title + description + hostname
- **Rich text rendering**: AT Protocol facets with TextEncoder/TextDecoder for correct UTF-8 byte offsets; hashtags clickable, mentions styled, URLs linked
- **recordWithMedia**: images or video alongside a quoted post all render correctly

### M5: Home / Following Timeline ✅
- `API.getTimeline(limit, cursor)` — `app.bsky.feed.getTimeline`
- `API.followActor` / `API.unfollowActor` follow graph
- `renderFeedItems()` in app.js (repost bar, reply context)
- Pagination ("Load more") on home feed

### M6: Author Profiles + Image Upload ✅
- `API.getActorProfile(actor)` and `API.getAuthorFeed(actor, limit, cursor)`
- `view-profile` section with back button, header, feed, load more, follow/unfollow toggle
- **Image upload in Compose**: file picker (up to 4 images), per-image preview and alt text, `API.uploadBlob(file)` → blob CID
- **Auto-resize**: `resizeImageFile()` uses Canvas API to shrink images >950 KB

### M7: Notifications ✅
- `API.listNotifications(limit, cursor)` and `API.updateSeen(seenAt)`
- Notification nav button with unread count badge
- `view-notifications`: type-coded icon, author avatar, action label, post preview, timestamp
- Click notification → opens profile (follow) or thread (like/repost/reply/mention/quote)
- Badge clears + `updateSeen` fires on first view

### M8: Thread UX — Inline Context + Reddit-Style Nesting ✅
- Compact clickable parent-post preview card (`buildParentPreview`) above reply cards in feed
- Root-first navigation: reply feed items open from `item.reply.root.uri`
- Depth-limited nesting: "Continue this thread →" button at depth ≥ 4 (see M46)
- Reddit-style collapse/expand: circle `−` button on connector line collapses branch

### M9: Inline Reply Compose ✅
- Reply button in thread view expands compose box beneath the target post via `expandInlineReply()`
- Mini parent quote shows context while composing; toggle/Cancel/Escape closes
- Live char count; posts via `API.createPost()`, then reloads thread in-place

### M10: Adaptive Image Sizing + Multi-Image Lightbox Carousel ✅
- Single images: natural aspect ratio (`object-fit: contain`, `max-height: 480px`)
- 2–4 image grids: uniform fixed-height crop (180px / 220px on desktop)
- `openLightbox(images, startIndex)`: all images in a post browsable from any thumbnail
- Navigation: arrows, dot indicators, keyboard ← →, touch swipe (40px threshold)

### M11: Saved Searches as Channels (Sidebar) ✅
- Sidebar pinned open on desktop (≥768px, via M43); slide-in drawer on mobile
- "Save as channel" bookmark button after any successful search
- `bsky_channels` in localStorage; each channel stores `id`, `name`, `query`, `lastSeenAt`, `unreadCount`
- Background unread check once per session (checks spaced 700ms apart)
- Channel click: runs search, clears unread badge, marks `lastSeenAt = now`
- Rename / delete via ⋯ menu on hover

### M12: Bsky Dreams TV ✅
- "TV" nav tab; setup screen with topic input + "▶ Start TV" button (satisfies audio autoplay gesture)
- Queue engine: video posts from search or dual-feed (timeline + Discover); pre-fetches when < 5 remain
- HLS.js player; `tvStop()` destroys Hls instance and resets state
- TikTok-style overlay: author info left, icon controls right; auto-hides after 3s
- Two-slot slide system (`#tv-slide-a`, `#tv-slide-b`) for simultaneous slide animations
- Back navigation: swipe-down or scroll-up returns to previous video
- Watch history: `bsky_tv_seen` in localStorage (max 1,000, FIFO eviction)
- Adult content filter: "Hide adult content" checkbox (checked by default); `isAdultPost()` checks `post.labels`
- Like / Repost buttons in overlay; "Open post" jumps to thread view; muted by default

### M19: Deep-Link URL Routing ✅
- URL scheme (query-param based; GitHub Pages safe):
  - Thread: `?view=post&uri=at%3A%2F%2F...&handle=...`
  - Profile: `?view=profile&actor=handle.bsky.social`
  - Search: `?q=query&filter=posts`
  - Feed: `?view=feed` / Notifications: `?view=notifications`
- `init()` reads `window.location.search` and routes to correct view on load
- `openThread` and `openProfile` include full URL in `pushState` calls
- Bsky.app URL import: paste `bsky.app/profile/.../post/...` into search → resolves to thread
- Copy link: chain-link icon on every post card; 1.5s "Copied!" feedback

### M20: Cross-Device Settings Sync (AT Protocol Repo) ✅
- `API.getRecord()` and `API.putRecord()` added to `api.js`
- Prefs record: collection `app.bsky-dreams.prefs`, rkey `self`, contains `{ savedChannels, uiPrefs }`
- `loadPrefsFromCloud()` called inside `enterApp()` after auth; falls back to localStorage
- `schedulePrefsSync()` — 2-second debounce write after any channel or preference change

### M21: Reporting Bad Actors ✅
- Three-dot ⋯ button on every post card and on profile headers
- Report modal: reason chips (Spam, Harassment, Misleading, Sexual, Rude, Other), optional textarea
- `API.createReport()` calls `com.atproto.moderation.createReport`
- Floating success banner for 3 seconds after submit

### M28: Discover Feed as Default ✅
- `feedMode` initialises to `'discover'`; Discover tab has `feed-tab-active` in HTML (no flash on load)
- `API.getFeed(DISCOVER_FEED_URI)` uses the `whats-hot` generator URI
- Following / Discover tab bar; `setFeedMode()` swaps active-tab styling and `aria-selected`

### M29: GIF Playback in Timeline ✅
- `isGifExternalEmbed(external)`: true when hostname is `tenor.com`, `c.tenor.com`, `media.giphy.com`, `giphy.com`, or `klipy.com`, or URL ends in `.gif`
- `buildGifEmbed(external)`: renders `<img class="post-gif">` for animated display
- Routes through `isGifExternalEmbed` in `buildPostCard()` before falling through to link card

### M30: Quote Post Interface ✅
- `showRepostActionSheet(btn, post)`: dropdown with "Repost/Undo repost" and "Quote Post"
- Quote post modal with compose textarea, char count, quoted-post preview card, full compose feature parity (images, GIF, link preview, post settings — see M41)
- `API.createQuotePost(text, embedRef)` sends `app.bsky.embed.record`; `recordWithMedia` used when images or external embed also attached

### M31: Reposter Name as Profile Link ✅
- "Reposted by X" bar replaced with `<button class="repost-author-link">` wrapping avatar + display name
- Click calls `openProfile(by.handle)` with `stopPropagation()`

### M32: iOS Safari PWA Session Persistence ✅
- `manifest.json` with `"display": "standalone"`, `"start_url": "./index.html?view=feed"`
- Apple meta tags in `index.html`: `apple-mobile-web-app-capable`, status bar style, theme-color
- `handleVisibilityChange()` on `document.visibilitychange`: checks `accessJwt` expiry (`exp` from JWT payload); refreshes proactively if within 15 minutes
- If both tokens expired: session cleared, auth screen shown with friendly message

### M33: Mention Links in Posts ✅
- Mention facets render as `<span class="mention-text mention-link" data-mention-did="{DID}">`
- `querySelectorAll('[data-mention-did]')` in `buildPostCard()` wires click + keydown handlers
- Calls `openProfile(did)` with `stopPropagation()`

### M34: PTR Resistance + Scroll-to-Top Button ✅
- PTR threshold: 96px drag + 400ms hold required before `ptrReadyToRelease` becomes true
- `#scroll-to-top-btn` fixed position; appears when `scrollTop ≥ 300px`; hidden on every view transition

### M35: Inline Reply from Home Feed ✅
- Reply button on feed cards calls `expandInlineReply(card, post, feedRootRef, onSuccess)` with `{ capture: true }`
- `feedRootRef` = `{ uri: rootUri || post.uri, cid: rootCid || post.cid }` from reply context
- On success: shows "Replied ✓" on the button for 3 seconds; no navigation required

### M36: TV Enhancements ✅
- **Pause button**: `tv-pause-btn` toggles `tvPaused`; suppresses auto-advance while paused
- **2× speed hold**: `pointerdown` on video wrap sets `playbackRate = 2`; `pointerup`/`pointercancel` restores to 1
- **Dual-feed queue** (no-topic): `Promise.allSettled()` fetches timeline + Discover in parallel; merged and deduped by URI
- **Short-clip filter**: skips `.gif` URLs and videos with `duration < 5s`

### M38: Minor Interface Polish ✅
- **Logo click**: clicking Bsky Dreams title/cloud calls `showView('feed', true); loadFeed()`
- **Timestamp as external link**: `<a href="https://bsky.app/profile/{handle}/post/{rkey}" target="_blank">` wrapping `<time>`
- **Like button rollback**: optimistic UI update; full rollback on API error; button disabled during in-flight request
- **PTR indicator clipping**: `overflow: hidden` on `#view-feed .view-inner`

### M40: Seen-Posts Deduplication ✅
- `bsky_feed_seen` in localStorage: `Map<uri, { seenAt, likeCount, repostCount }>`, 5,000-entry FIFO cap
- Posts filtered before render unless engagement grew by ≥ 50 interactions ("gone viral" threshold)
- "N posts filtered (show anyway)" hint bar; bypass flag is session-only
- Applies to both Following and Discover modes

### M41: Rich Compose — Link Preview + GIF Picker + Post Settings ✅
- **Link preview**: debounced URL detection (800ms); OG metadata via `allorigins.win` CORS proxy; editable title/description inputs; `_thumbUrl` stored and uploaded as blob at submit; "Change" button to swap thumbnail
- **GIF picker**: "GIF" toolbar button; searches Klipy API (key hardcoded as `KLIPY_KEY`); GIF posted as `app.bsky.embed.external` (CDN URL, animation preserved); `xs.jpg` thumbnail uploaded as blob for native Bluesky image card
- **Post settings**: gear icon toggles reply-gate and quote-gate selects; `app.bsky.feed.threadgate` and `app.bsky.feed.postgate` created via `API.putRecord` after post
- **Quote modal parity**: same features added to quote post modal; `searchKlipyGifs(q, gridEl, onSelect)` parameterized for reuse
- **`api.js createPost` extended**: full embed matrix — images+embedRef → `recordWithMedia`; externalEmbed+embedRef → `recordWithMedia`
- Applies to main compose, inline reply compose, and quote post modal

### M43: Sidebar Navigation Redesign ✅
- **Desktop (≥768px)**: sidebar always open (`left: 0`, no toggle); top bar height collapses to 0; main content offset via `padding-left: var(--sidebar-width)`
- **Mobile**: slide-in drawer triggered by hamburger in minimal top bar
- **Sidebar contents**: logo button, own-profile section (avatar + name + handle), nav items (Home, Post, TV, Notifications, Search), separator, channel links, sign-out footer
- `updateSidebarProfile(profile)` populates sidebar after login; resets on sign-out
- `.sidebar-nav-item.active` has left accent border + accent background

### M44: Scroll-Based Read Indicator ✅
- One shared `feedSeenObserver` after each `renderFeedItems()`; `threshold: 0`, `rootMargin: '0px'`
- Post marked "seen" when `entry.isIntersecting === false` AND `entry.boundingClientRect.top < 0`
- `.post-seen` class added to card: `opacity: 0.82; border-left: 3px solid #aab0bc`
- Observer disconnected in `showView()` when leaving feed; recreated on next `loadFeed()`

### M45: Scroll-to-Top Button Repositioning ✅
- Fixed position: `left: 8px` on mobile; `left: calc(var(--sidebar-width, 240px) + 8px)` on desktop
- 36×36px circular button with `backdrop-filter: blur(4px)`

### M46: Deep Thread Overflow Fix ✅
- Depth cutoff changed to `depth >= 4` (max 5 nesting levels; was ≥ 8)
- "Continue this thread →" calls `openThread` with `fromContinue: true`; "← Back to parent thread" breadcrumb prepended
- `overflow-x: hidden` on `#view-thread .view-inner` and `.reply-group-body`; `max-width: 100%` on `.reply-group-body > .post-card`

### M47: Pull-to-Refresh on Search + Profile Views ✅
- `makePTR(scrollEl, triggerFn)` generic factory applied to `#view-search` and `#view-profile`
- Same 96px / 400ms threshold as home feed PTR

### M48: "Load More" on Search Results ✅
- `searchCursor`, `lastSearchQuery`, `lastSearchSort`, `lastSearchOpts` state variables
- `appendSearchLoadMore(type)` injects "Load more" button at bottom of results
- `renderPostFeed(posts, container, append)` extended with `append` parameter

### M49: Advanced Search Media Type Filters ✅
- Media filter chips (Image / Video / Link) in advanced search panel
- `applyMediaFilter(posts)` checks embed `$type` for `images`, `video`, `external`
- `searchMediaFilters = new Set()` state variable; chips toggle set membership

### M50: Infinite Scroll for Thread Replies ✅
- Per-`.show-more-replies` button `IntersectionObserver` (`rootMargin: '0px 0px 200px 0px'`)
- Button auto-fires reveal handler when it enters the 200px pre-viewport zone
- "Continue this thread →" buttons remain tap-only (not auto-triggered)

### M51: Post Success Banner with In-App Link ✅
- Compose success banner "View post →" is a `<button>` calling `openThread()` in-app; auto-dismisses after 4s
- Quote post modal shows `#quote-success-banner` on success with same pattern

### GIF Provider Migration: Tenor → Klipy ✅
- Replaced Tenor API with Klipy (`api.klipy.com/api/v1/{key}/gifs/search`); key hardcoded as `KLIPY_KEY`
- GIFs embedded as `app.bsky.embed.external` (CDN URL) so animation is preserved
- `xs.jpg` thumbnail uploaded as blob → `thumb` in external embed for native Bluesky image card
- `isGifExternalEmbed` updated to detect `klipy.com` URLs

### Unnumbered: Repost / Quote-Post Rendering Fixes ✅
- `app.bsky.embed.record#view` renders as compact `buildQuotedPost` card (clicking opens quoted post's thread)
- `app.bsky.embed.recordWithMedia#view` renders both media AND the quoted post card
- Repost attribution bar includes reposter's small avatar

### Unnumbered: Thread Nesting Visual Polish ✅
- Depth-colored `border-left` on `.reply-group` elements (8 cycling colors via `[data-depth]` attribute selectors)
- Post cards carry matching depth `border-left-color`
- `group.dataset.depth = depth + 1` set by `renderThread`

### Unnumbered: Video Player Bug Fix ✅
- `wrap.addEventListener('click', (e) => e.stopPropagation())` in `buildVideoEmbed` prevents video controls from opening the thread view

### Unnumbered: Early UX Improvements ✅
- Default home view: `enterApp()` opens Discover feed; history seed updated to `?view=feed`
- Pull-to-refresh: `#ptr-indicator` hidden above scroll area (`margin-top: -52px`); touch handlers detect downward pull at `scrollTop === 0`

### Unnumbered: Home Feed Discover Tab + Overscroll Fix ✅
- Following / Discover tab bar added to home feed header
- `API.getFeed(feedUri, limit, cursor)` added to `api.js`
- `overscroll-behavior: none` added to `.view` (the actual scroll container)

### M39: Feed Content Filters ✅
- "Filters ▾" toggle button added to the feed tab bar (right-aligned)
- Filter panel: Politics, Sports, Current Events, Entertainment checkboxes + free-text keyword input
- `/js/filter-words.json`: curated keyword lists for each category
- `applyFeedFilters()`: client-side keyword matching against `.post-text` content; matching posts set to `display:none`; runs after every `renderFeedItems()` call into the home feed
- "N posts filtered" counter shown in filter panel when active
- "Remember my filters" checkbox: writes `bsky_feed_filters: { categories, custom }` to localStorage; `loadFeedFilters()` called in `enterApp()` to restore on login
- Caveat label: "Approximate — keyword matching may miss or misidentify some posts"
- Ephemeral by default (unchecked); session-only otherwise

### M37: Image Browser ("Bsky Dreams Gallery") ✅
- "Gallery" nav item in sidebar (grid icon); `view-gallery` section in index.html
- Fetches timeline + Discover feed in parallel (`Promise.allSettled`); filters to image posts only
- Dedup by URI (session-level `Set`) and by blob CID (prevents same image from different reposts); respects M40 seen-posts map
- `buildGalleryCard()`: image grid via `buildImageGrid`, tap any image → `openLightbox`; author avatar + name + handle strip; Like/Repost action buttons with optimistic update + rollback; click card body → opens thread
- Infinite scroll via `IntersectionObserver` on sentinel element (400px pre-load margin)
- Observer disconnected in `showView()` when leaving gallery view
- `?view=gallery` deep-link routing supported

### M42: Video Upload in All Post Types ✅
- "Video" toolbar button in main compose and quote post modal; mutually exclusive with images
- File picker accepts `video/mp4`, `video/webm`, `video/quicktime`; one video per post
- `validateAndLoadVideo()`: rejects files > 50 MB or > 180s; shows friendly error
- FFmpeg.wasm skipped (requires SharedArrayBuffer / COOP+COEP headers GitHub Pages cannot serve); unsupported formats show an error
- Preview: `<video>` element in compose area; filename + duration displayed; ✕ to remove
- Upload: `API.uploadBlob(file)` → `app.bsky.embed.video` with `alt` and `aspectRatio` when available
- Video + quote post: `app.bsky.embed.recordWithMedia` (media = video embed, record = quoted post)
- Daily limit: 25 uploads/day tracked in `bsky_video_daily: { date, count }` in localStorage
- Cleanup: `clearComposeVideo()` / `clearQuoteVideo()` called on view switch, modal close, and GIF/image selection
- Applies to: main compose, quote post modal

### Unnumbered: 8-Item UX Polish Pass ✅
- **TV sidebar on desktop**: `@media (min-width: 768px)` restores `padding-left: var(--sidebar-width)` for `.view-tv`
- **TV autoplay fallback**: if `vid.play()` rejected, retries with `vid.muted = true`
- **TV adult checkbox**: label "Hide adult content"; `checked` by default; `tvAllowAdult = !$('tv-adult-toggle').checked`
- **Mobile header layout**: `.mobile-logo` absolutely centered; `margin-left: auto` on `.nav-avatar-btn`
- **Link preview thumbnail**: stored as `_thumbUrl`; uploaded as blob at submit; "Change" button added
- **Quote modal full compose features**: image attachment, GIF picker, link preview, post settings; `searchKlipyGifs` parameterized `(q, gridEl, onSelect)`
- **Seen-posts observer**: `rootMargin` changed from `'0px 0px -80% 0px'` to `'0px'`
- **Thread collapse button**: `overflow-x: hidden` moved from `.reply-group` to `.reply-group-body`
- **Feed tab refresh**: removed `if (feedMode !== '...')` guards so clicking the active tab always refreshes

---

## Planned Milestones

Ordered by implementation priority. Items marked **[RESEARCH]** need API/cost investigation.

---

### Near-Term

---

### Medium-Term

#### M22: Analytics Dashboard

- **Entry**: "Analytics" nav tab (bar-chart icon)
- **Charts** via Chart.js served locally as `/js/chart.min.js`:
  - Engagement over time (likes + reposts per post, by date)
  - Top posts table (sortable by likes, reposts, replies)
  - Follower count over time (snapshots stored in localStorage — AT Protocol has no history endpoint)
  - Post frequency heatmap (GitHub-style contribution graph)
- **Actor switcher**: search bar to switch dashboard to any public profile
- **Topic mode**: hashtag/query → aggregate engagement stats across all matching posts

#### M13: Horizontal Event Timeline Scrubber

- **Entry**: "Timeline" toggle in search results
- **Layout**: posts arranged horizontally on a scrollable rail, chronologically left to right; timestamp large at top, author + text snippet below
- **Axis**: date/time axis below cards; "hours" and "days" zoom levels
- **Interaction**: mouse drag / trackpad / touch swipe scrolls; clicking a card opens the full thread

#### M14: Network Constellation Visualization

- **Entry**: "Constellation" button/tab in search results
- **Data**: `searchPosts(query, 'latest', 100)` → nodes = users, edges = replies; capped at 150 nodes
- **Rendering**: D3.js v7 force-directed layout served locally as `/js/d3.min.js`; node size ∝ post count, edge weight ∝ reply count
- **Interaction**: click node to center it and show only its connections; hover tooltip; double-click opens profile

#### M16: Direct Messages (Native Chat API)

- **Entry**: "Messages" nav tab with unread badge
- **API**: `chat.bsky.convo.*` at `https://api.bsky.chat/xrpc/` (separate base URL from bsky.social; same `accessJwt`)
- **Conversation list**: avatar, handle, last message snippet, timestamp; sorted by most recent
- **Chat view**: bubble style; own messages right-aligned (accent); theirs left-aligned; timestamps grouped by day
- **Compose**: text input, send on Enter or button; 1,000 char limit per AT Protocol spec
- **Polling**: refresh convo list every 30s while Messages view is active
- **New conversation**: "New message" button; search for handle to start a convo

---

### Later

#### M15: Profile Interaction Graph (Frequent Contacts)

- **Data**: last 100 posts from `getAuthorFeed` with `filter: 'posts_and_author_threads'`; count `reply.parent.author` frequency
- **Display**: "Frequent conversations with" section below profile stats; top 6–8 handles as avatar chips
- **Labels**: own profile → "People you talk to most"; others → "Often replies to"
- **Mutual detection**: flag A↔B mutual conversations with "↔ mutual" indicator

#### M17: Image Tools — Text Shot Builder ⚠️ Partial

> **Note**: Link preview and GIF picker from the original M17 spec are now implemented in M41. Remaining work is the canvas-based text shot builder only.

- "T" compose toolbar button opens canvas-based editor
- Choose background (solid color, gradient, or preset photo), font size, alignment
- Output is a PNG rendered via Canvas API, attached as an image to the post

#### M18: Post Collections + Export

- **Selection**: bookmark icon (☆) on every post card; add to Quick Collection or named collection
- **Collections view**: nav tab or profile menu; lists collections with count and preview thumbnails
- **Export as image**: Canvas API renders selected posts as a vertical image strip; "Post to BlueSky" shortcut attaches to new compose draft
- **Export as JSON**: download backup file
- **Persistence**: localStorage (extend M20 AT Protocol sync to include collections)

#### M23: RSS/News Contextual Sidebar

- **Data sources**: curated CORS-friendly RSS feeds (BBC, Reuters, AP News, NPR)
- **Fetch**: direct browser `fetch()` of RSS XML; parse with `DOMParser`
- **Integration**: collapsible "In the news" panel in search results; up to 5 keyword-matched articles linked to source
- **Cache**: 15 minutes in memory

#### M24: Post-to-Image Export (Stylized Post Cards)

- **Entry**: "Share as image" in post card ⋯ menu and in Lightbox
- **Canvas renderer**: author avatar, display name, handle, timestamp, post text (word-wrapped), attached images, "Posted on BlueSky" footer
- **Background options**: white, dark, gradient presets, custom color picker
- **Export**: `canvas.toBlob('image/png')` → download or "Attach to new post" button

#### M25: Lightbox Annotation Tools

- **Entry**: "Annotate" button in lightbox bottom bar (pencil icon)
- **Tools**: freehand pen (3 stroke widths), text label, arrow, rectangle highlight; eraser; undo (20 steps); 8 preset colors + custom
- **Save flow**: renders annotated canvas to PNG; opens compose with image pre-attached and reply reference set to original post
- **Implementation**: Canvas 2D API overlay; no external library needed

#### M26: Location-Based Content Discovery

- **Signals** (priority order): profile location field, hashtags matching city/country names, keyword detection in post text
- **Entry**: "Near" filter chip in search bar; text input or Leaflet.js + OpenStreetMap map click (both zero-cost)
- **Bundled data**: `/js/locations.json` maps city names/aliases to coordinates — no geocoding API needed

---

### Deferred — Requires API/Cost Research

#### M27a: Fact-Checking Integration
- Free path: link out to Google Fact Check Explorer for claims in post text
- Heuristic path: static blocklist of known misinformation domains
- **Blocker**: no zero-cost automated fact-check API with acceptable accuracy exists today

#### M27b: Political Bias / Spectrum Analysis
- Partial path: domain-level bias rating using AllSides or Media Bias/Fact Check static dataset (zero-cost)
- Profile-level NLP requires an LLM API call per profile — not zero-cost

#### M27c: AI-Generated Content Detection
- Partial path: check for C2PA "Content Credentials" metadata in image uploads if BlueSky surfaces it
- Full implementation blocked on cost (Hive Moderation, Illuminarty are paid)

---

## Open Questions

1. **Adult content labels**: BlueSky has a richer labelling system (`com.atproto.label.*`) that could give finer control than the current label-string check in `isAdultPost()`.
2. **Image file size limit**: AT Protocol limits blobs to 1 MB. `resizeImageFile()` handles this but GIF animation is lost on resize.
3. **Notification polling**: Notifications load once per session; no polling or WebSocket push. Users must navigate to Notifications to see new ones.
4. **DM base URL**: `chat.bsky.convo.*` uses `https://api.bsky.chat/xrpc/` (not `bsky.social/xrpc/`). The `withAuth` wrapper needs a base-URL parameter or separate helper in `api.js` before M16 can be implemented.
5. **AT Protocol prefs record privacy**: `app.bsky-dreams.prefs` is publicly readable by anyone who knows the DID + collection + rkey. Acceptable for non-sensitive prefs, but must be disclosed to users.
6. **Klipy GIF allowlist**: Klipy is not yet on Bluesky's animated-GIF allowlist (issue #9728). Native Bluesky shows the thumbnail card but not animation. No code change needed when they are added.

---

## Blockers

None currently.

---

## Next Session Starting Point

1. **M22 — Analytics Dashboard** (Chart.js local, engagement over time, top posts table)
2. **M13 — Horizontal Event Timeline Scrubber** (search-seeded, horizontal scroll rail)
3. **M14 — Network Constellation Visualization** (D3.js local, force-directed graph)
4. **M16 — Direct Messages** (chat.bsky.convo.* API, separate base URL)
4. **M22 — Analytics Dashboard** (Chart.js local, engagement over time, top posts table)
5. **M13 — Horizontal Event Timeline Scrubber**
6. **M14 — Network Constellation Visualization** (D3.js local)
7. **M16 — Direct Messages** (chat.bsky.convo.* API, separate base URL)
