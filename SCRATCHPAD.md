# Project Scratchpad — Bsky Dreams

## Current Status

Milestones 1–12, 19, 20, 21, 29, 30, 32, 34, 35, 36, 38, 40 are complete, plus repost/quote-post rendering fixes, thread nesting visual polish, M9 (Inline Reply Compose), video player bug fix, M11 (Channels sidebar), M19 (Deep-Link Routing), UX improvements (default home view, pull-to-refresh), Bsky Dreams TV enhancements (TikTok-style redesign, watch history, dual search, back navigation, pause button, 2× speed hold, dual-feed queue, short-clip filter), home feed Discover tab with elastic overscroll fix, M28/M31/M33/M38 (Discover as default, reposter links, mention links, interface polish), M20 (cross-device prefs sync via AT Protocol repo), M29 (GIF playback in timeline), M30 (quote post interface), M32 (iOS Safari PWA session persistence), M34 (PTR resistance + scroll-to-top button), M35 (inline reply from home feed), M40 (seen-posts deduplication).

## Completed Milestones

### Milestone 1 + 2: Interface + API Integration ✅
- Initial project scaffold (index.html, css/styles.css, js/auth.js, js/api.js, js/app.js)
- Three-panel layout: Auth screen, Search/Feed, Compose, Conversation View
- AT Protocol API integration (login, search posts/actors, get thread, create post)
- App-password auth with session stored in localStorage

### Milestone 3: Interaction Buttons ✅
- Like / Unlike: toggle with live count update, `data-like-uri` on button
- Repost / Unrepost: toggle with live count update, `data-repost-uri` on button
- Reply: opens thread view and focuses reply textarea
- Follow / Unfollow: toggle on actor (people) search result cards

### Milestone 4: Media + Rich Text ✅
- **Images**: full-size grid, click-to-lightbox overlay with alt text caption
- **Alt text display**: shown prominently below each image; shown below video too
- **Alt text authoring**: per-image textarea in compose form (completed in M6)
- **Video**: HLS.js v1.5.13 poster + play-to-activate; muted autoplay; error
  fallback shows "Watch video ↗ (reason)" link
- **External link cards**: thumbnail + title + description + hostname
- **Rich text rendering**: AT Protocol facets with TextEncoder/TextDecoder for
  correct UTF-8 byte offsets; hashtags clickable, mentions styled, URLs linked
- **recordWithMedia**: images or video alongside a quoted post all render

### Milestone 5: Home / Following Timeline ✅
- `API.getTimeline(limit, cursor)` — `app.bsky.feed.getTimeline`
- `API.followActor(subjectDid)` / `API.unfollowActor(followUri)` — follow graph
- Home nav button + `view-feed` section in index.html
- `renderFeedItems()` in app.js (repost bar, reply context)
- Follow/Unfollow toggle on actor cards in People search results
- Pagination ("Load more") on home feed

### Milestone 6: Author Profiles + Image Upload ✅
- `API.getActorProfile(actor)` — `app.bsky.actor.getProfile`
- `API.getAuthorFeed(actor, limit, cursor)` — `app.bsky.feed.getAuthorFeed`
- `view-profile` section in index.html (back button, header area, feed, load more)
- `openProfile(handle, opts)` + `renderProfileHeader(profile)` in app.js
- `loadProfileFeed(actor, append)` with pagination
- `.author-link` click handlers on avatar + name in every post card
- Profile follow/unfollow button wired in renderProfileHeader
- **Image upload in Compose**: file picker (up to 4 images), per-image preview,
  per-image alt text textarea, `API.uploadBlob(file)` → blob CID → embed in post
- **Auto-resize**: `resizeImageFile()` uses Canvas API to shrink images >950 KB
  (iterates JPEG quality then dimensions); CSP `img-src` now includes `blob:`

### Milestone 7: Notifications ✅
- `API.listNotifications(limit, cursor)` — `app.bsky.notification.listNotifications`
- `API.updateSeen(seenAt)` — marks all notifications as seen
- Notification nav button (bell icon) with unread count badge
- `view-notifications` section: type-coded icon, author avatar, action label,
  post preview text, timestamp
- Click notification → opens profile (follow) or thread (like/repost/reply/mention/quote)
- Badge clears + `updateSeen` fires on first view

### Repost/Quote-Post Rendering Fixes ✅
- `app.bsky.embed.record#view` (pure quote) now renders as a compact embedded
  card (`buildQuotedPost`) showing quoted author avatar, name, handle, and
  truncated text; clicking opens *that* post's thread, not the outer post
- `app.bsky.embed.recordWithMedia#view` now renders both the attached media
  *and* the quoted post card below it (previously the quoted record was dropped)
- Repost attribution bar now includes the reposter's small avatar alongside
  the "Reposted by …" label

### Milestone 8: Thread UX — Inline Context + Reddit-Style Nesting ✅
- **Feed reply context**: Replaced bare "Replying to @handle" bar with a
  compact clickable parent-post preview card (`buildParentPreview`) showing the
  parent's avatar, author name, and truncated text
- **Root-first navigation**: Feed items that are replies now open the thread
  from the root post URI (`item.reply.root.uri`) when clicked, keeping the full
  conversation in view; the reply button on those cards does the same
- **Depth-limited nesting**: `renderThread` tracks nesting depth (default 0,
  incremented on each recursive call). At depth ≥ 8 a "Continue this thread →"
  button appears instead of recursing further, linking to that reply node
- Blocked/missing reply nodes are filtered out before rendering

### Milestone 10: Adaptive Image Sizing + Multi-Image Lightbox Carousel ✅
- **Adaptive sizing**: Single images render at their natural aspect ratio
  (`object-fit: contain`, `max-height: 480px`) instead of a forced 180px
  landscape crop. Portrait screenshots and tall images now display properly.
  2–4 image grids retain uniform crop (180px / 220px on desktop).
- **Lightbox carousel**: `openLightbox()` now accepts an array of `{src, alt}`
  objects and a `startIndex`. All images in a post are browsable from any
  starting thumbnail.
- **Navigation**: Previous/Next arrow buttons; dot indicator row (clickable);
  "2 / 4" counter; keyboard ← → arrows; touch swipe (40px threshold).
- `buildImageGrid` passes the full image array as a shared carousel payload.

### Thread Nesting Visual Polish ✅
- **Depth-colored connector lines**: Replaced the old single-color absolute-
  positioned vertical line (which overlapped post card borders) with a CSS
  `border-left` on each `.reply-group` element. Eight cycling colors keyed to
  `data-depth` attributes (blue → violet → cyan → emerald → amber → red →
  orange → pink → repeat).
- **Depth-colored post card borders**: Each post card inside a reply group
  also carries the same depth color as its connector line via
  `border-left-color` on `.reply-group-body > .post-card`.
- **No more awkward overlap**: Removed the `.reply-thread-connector` absolutely-
  positioned L-shaped element that had `top: -8px` overflow into parent cards.
  The colored left border of `.reply-group` is the visual connector — no
  separate element needed.
- **`data-depth` on reply groups**: `renderThread` now sets `group.dataset.depth`
  to `depth + 1` on each `reply-group` div, enabling depth-specific CSS rules.
- **Reddit-style collapse/expand**: Each reply group has a small circle `−`
  button on the connector line. Clicking it collapses all replies in that
  branch and shows a `↓ N replies` expand button. Works independently at
  every nesting depth.

### Milestone 9: Inline Reply Compose ✅
- **Inline compose box**: Clicking "Reply" on any post in the thread view now
  expands a compact compose box directly beneath that post card via
  `expandInlineReply(postCard, post)`. The previous bottom-of-page reply area
  is no longer shown.
- **Mini parent quote**: The reply box shows a small read-only preview (avatar +
  @handle + text snippet) of the post being replied to, so context is always
  visible while composing.
- **Toggle behaviour**: Clicking Reply on the same post a second time closes the
  inline box. Opening a new one closes the previous one.
- **Dismiss**: Cancel button or Escape key closes the box without posting.
- **Mobile**: The box scrolls into view automatically on open via
  `scrollIntoView({ behavior: 'smooth', block: 'nearest' })`.
- **Char count**: Live remaining-character counter turns red below 20 chars.
- **Submit**: Posts via `API.createPost()`, then reloads the thread in-place.
  Error message displayed inline if posting fails.
- **`currentThread` simplified**: Now stores only `{ rootUri, rootCid,
  authorHandle }` — the old `replyToUri/Cid/Handle` fields that fed the bottom
  form are no longer needed.

### Video Player Bug Fix ✅
- **Root cause**: Native `<video controls>` click events bubbled through
  `.post-video-wrap` to the post card's click handler, opening the thread view
  whenever the user interacted with play/pause, volume, or the scrubber.
- **Fix**: Added `wrap.addEventListener('click', (e) => e.stopPropagation())`
  at the top of `buildVideoEmbed`. The poster element already had
  `stopPropagation`; this extends that protection to the activated video
  element with its native controls.

### Milestone 19: Deep-Link URL Routing ✅
- **URL scheme** (query-param based; GitHub Pages safe):
  - Thread: `?view=post&uri=at%3A%2F%2F...&handle=...`
  - Profile: `?view=profile&actor=handle.bsky.social`
  - Search: `?q=query&filter=posts`
  - Feed: `?view=feed`
  - Notifications: `?view=notifications`
- **On load**: `init()` reads `window.location.search` and passes
  `URLSearchParams` to `enterApp()`, which routes to the right view after
  the session profile loads. Supports direct deep-link navigation and page
  refresh recovery for all views.
- **On navigation**: `openThread` and `openProfile` now include the full URL
  in their `pushState` calls. `showView` also adds URL params to pushState.
  Successful searches update the URL with `replaceState`.
- **Bsky.app URL import**: Pasting a `bsky.app/profile/.../post/...` URL into
  the search bar uses the existing `API.resolvePostUrl()` helper to resolve
  the AT URI and open the thread directly. Pasting a profile URL opens the
  profile view.
- **Copy link**: Every post card has a chain-link icon button (far right of the
  actions row) that copies the Bsky Dreams deep-link URL to the clipboard with
  a 1.5-second "Copied!" confirmation. Uses `navigator.clipboard`.
- **Back/Forward**: The `popstate` handler prefers `history.state` data but
  falls back to URL params so deep-linked pages work correctly.

### Milestone 11: Saved Searches as Channels (Sidebar) ✅
- **Left sidebar**: Pinned open at ≥768px; on mobile it slides in as a drawer from
  the hamburger/channels button in the nav bar. Overlay dims the rest of the page.
- **Saving a search**: "Save as channel" bookmark button appears above search results
  after any successful search. Uses `prompt()` to let user name the channel (default:
  the query). Duplicate queries are blocked.
- **Channel persistence**: `bsky_channels` in localStorage. Each channel stores:
  `id`, `name`, `query`, `lastSeenAt`, `unreadCount`.
- **Unread count**: Background check runs once per session after login —
  fetches the latest 5 posts per channel and counts posts newer than `lastSeenAt`.
  Checks are spaced 700ms apart. Badge shown on channel item.
- **Channel click**: Runs `searchPosts(query, 'latest', 25)`, clears the unread
  badge, marks `lastSeenAt = now`. Closes mobile drawer automatically.
- **Rename / delete**: ⋯ menu button revealed on hover; inline dropdown with
  Rename (uses `prompt()`) and Delete channel options.
- **Desktop layout**: `padding-left: var(--sidebar-width)` on `.view` and
  `top-bar-inner` shifts all content right to coexist with the fixed sidebar.
- **Mobile layout**: `closeSidebar()` restores drawer state on sign-out and view switch.

### Milestone 28: Discover Feed as Default ✅
- Changed `feedMode` initial value from `'following'` to `'discover'` in `app.js`.
- Updated `index.html` feed tab HTML so Discover tab has `feed-tab-active` and
  `aria-selected="true"` by default; Following tab starts unselected.
- `setFeedMode()` is called by tab click handlers and keeps both JS state and HTML
  in sync; Discover is shown on first load with no extra init call needed.

### Milestone 31: Reposter Name as Profile Link ✅
- Replaced the static `<span>` "Reposted by X" label in `renderFeedItems()` with a
  `<button class="repost-author-link">` wrapping the reposter's avatar image and
  display name.
- Click calls `openProfile(by.handle)` with `stopPropagation()` so the outer post
  card click does not also trigger thread navigation.
- New CSS: `.repost-author-link` renders as borderless inline-flex button; hover
  shows underline.

### Milestone 33: Mention Links in Posts ✅
- In `renderPostText()`, mention facets now render as
  `<span class="mention-text mention-link" role="button" tabindex="0" data-mention-did="{DID}">`.
  The DID is embedded directly from the facet — no handle-resolution step needed.
- In `buildPostCard()`, after the card's inner HTML is set, `querySelectorAll('[data-mention-did]')`
  wires `click` and `keydown` (Enter/Space) handlers that call `openProfile(did)` with
  `stopPropagation()`.
- New CSS: `.mention-link { cursor: pointer }` with hover underline.

### Milestone 38: Minor Interface Polish ✅
- **Logo click**: `$('nav-home-btn')` listener calls `showView('feed', true); loadFeed()` —
  clicking the Bsky Dreams title/cloud always returns to a fresh Discover feed.
- **Timestamp as external link**: In `buildPostCard()`, derive `rkey` from the AT URI
  and build a `bsky.app` URL; render the timestamp as
  `<a class="post-timestamp" href="..." target="_blank" rel="noopener">` wrapping
  `<time>`. Falls back to plain `<time>` if handle or rkey are unavailable.
- **Like button race condition**: Moved UI update before the `try` block (optimistic).
  Added full rollback in the `catch` block — restores `liked` class, SVG fill,
  `data-like-uri`, and count text. Button is disabled during the in-flight request.
- **PTR indicator clipping**: Added `overflow: hidden` to `#view-feed .view-inner`
  in `styles.css` so the `-52px` margin-top on the indicator is fully clipped above
  the scroll area on desktop.
- **Channels sidebar hidden by default**: Removed the desktop `@media (min-width: 768px)`
  rule that forced `.channels-sidebar { left: 0 }` and `.view { padding-left }` always.
  Replaced with `body.sidebar-open .view` and `body.sidebar-open .top-bar-inner` rules.
  `openSidebar()` / `closeSidebar()` add/remove `body.sidebar-open` on desktop and
  persist the preference in `localStorage` under `bsky_sidebar_open`. `enterApp()`
  restores the saved state on login.

### Milestone 20: Cross-Device Settings Sync (AT Protocol Repo) ✅
- **API additions**: `API.getRecord(repo, collection, rkey)` and `API.putRecord(repo,
  collection, rkey, record)` added to `api.js`, wrapping `com.atproto.repo.getRecord` and
  `com.atproto.repo.putRecord`. Both exported.
- **Prefs record schema**: Collection `app.bsky-dreams.prefs`, rkey `self`. Record
  contains `{ $type, savedChannels, uiPrefs: { hideAdult } }`.
- **Load on login**: `loadPrefsFromCloud()` called inside `enterApp()` after auth succeeds.
  Falls back to localStorage if the record doesn't exist yet.
- **Write on change**: `schedulePrefsSync()` (2-second debounce) called after every
  `channelsAdd`, `channelsRemove`, `channelsRename`, and adult-toggle change.
- **Privacy note**: The record is publicly readable by anyone who knows the DID +
  collection + rkey. Only non-sensitive prefs are stored.

### Milestone 29: GIF Playback in Timeline ✅
- **`isGifExternalEmbed(external)`**: Returns true when the external embed hostname is
  `tenor.com`, `c.tenor.com`, `media.giphy.com`, or `giphy.com`, or when the URL path
  ends in `.gif`.
- **`buildGifEmbed(external)`**: Returns `<div class="post-gif-wrap"><img class="post-gif">`
  with the GIF URL. For Tenor URLs ending in `.mp4` the extension is swapped to `.gif`
  to get the animated version.
- **Wiring**: In `buildPostCard()`, the external embed branch and the media portion of
  `recordWithMedia` both route through `isGifExternalEmbed` before falling through to
  the standard link card. Matching embeds use `buildGifEmbed` instead.
- **CSS**: `.post-gif-wrap` with border-radius; `.post-gif` with `max-height: 400px` and
  `object-fit: contain`.

### Milestone 30: Quote Post Interface ✅
- **Repost action sheet**: `showRepostActionSheet(btn, post)` creates a small dropdown
  (`.repost-action-sheet`) above the repost button with two options: "Repost/Undo repost"
  and "Quote Post". Dismisses on outside click.
- **Quote post modal**: `#quote-modal` in `index.html` with compose textarea (char count,
  error display), a read-only quoted-post preview (`buildQuotedPost()`), Cancel and
  "Quote Post" submit buttons.
- **API**: `API.createPost(text, null, [], { uri, cid })` sends
  `app.bsky.embed.record` embed. `API.createQuotePost(text, embedRef)` convenience wrapper
  added to `api.js`.
- **CSS**: `.repost-action-sheet`, `.repost-sheet-item`, `.quote-modal-preview`.

### Milestone 32: iOS Safari PWA Session Persistence ✅
- **PWA manifest**: `manifest.json` created with `"display": "standalone"`,
  `"start_url": "./index.html?view=feed"`, and `"theme_color": "#0085ff"`.
- **Apple meta tags**: `<meta name="apple-mobile-web-app-capable" content="yes">`,
  status bar style, title, and `theme-color` meta added to `index.html`.
- **Token refresh on visibility**: `handleVisibilityChange()` fires on
  `document.visibilitychange`. If the page becomes visible, the stored `accessJwt` expiry
  (`exp` field decoded from the JWT payload) is checked. If expired or within 15 minutes
  of expiry, `AUTH.refreshSession(refreshJwt)` is called proactively. If both tokens are
  expired, session is cleared and the auth screen is shown with a friendly message.
- **`getJwtExp(token)`**: Decodes the base64url JWT payload and returns `exp * 1000` (ms).

### Milestone 34: PTR Resistance + Scroll-to-Top Button ✅
- **Increased PTR threshold**: Changed `PTR_THRESHOLD` from `64` to `96` pixels.
- **Hold timer**: Added `PTR_HOLD_MS = 400`. A `ptrHoldTimer` must expire before
  `ptrReadyToRelease` is set to `true`, preventing accidental triggers during fast
  upward flicks.
- **Scroll-to-top button**: `#scroll-to-top-btn` added to `index.html` (fixed position,
  hidden by default). Scroll listeners on all view elements show it when `scrollTop ≥ 300px`
  in the active view. Clicking smoothly scrolls the active view to top.
- **View-switch reset**: `showView()` sets `scrollToTopBtn.hidden = true` on every view
  transition so the button is never orphaned when switching views.
- **CSS**: `.scroll-to-top-btn` fixed at `bottom: 80px`, centered on mobile; right of the
  content column on desktop (≥768px).

### Milestone 35: Inline Reply from Home Feed ✅
- **Feed reply override**: In `renderFeedItems()`, after building each post card, a
  `{ capture: true }` listener overrides the reply button's default thread-navigation
  behavior. It calls `expandInlineReply(card, post, feedRootRef, onSuccess)` instead.
- **Root reference**: `feedRootRef` = `{ uri: rootUri || post.uri, cid: rootCid || post.cid }`.
  `expandInlineReply` now accepts a fourth `feedRootRef` param and uses it in preference to
  `currentThread.rootUri/rootCid` when constructing the `replyRef`.
- **Success callback**: `onSuccess` is called on successful post instead of reloading the
  thread. The callback shows "Replied ✓" text on the reply button for 3 seconds, then
  restores the original label.
- **No navigation required**: Users can reply to any home-feed post without leaving the feed.

### Milestone 36: Bsky Dreams TV Enhancements ✅
- **Pause button**: `#tv-pause-btn` wired to toggle `tvPaused` state. Calls
  `activeVideo().pause()` or `activeVideo().play()`. `syncPauseBtn()` swaps the button icon
  between the ⏸ pause bars and ▶ play triangle. `advanceToNext()` skips auto-advance while
  paused so the video stays frozen at end-of-clip.
- **2× speed hold**: `pointerdown` on the video wrap (excluding buttons) sets
  `activeVideo().playbackRate = 2`. `pointerup` / `pointercancel` restores to `1`. Works on
  both touch and mouse; `pointerdown` is cross-device and cleaner than separate touch/mouse
  handlers.
- **Dual-feed queue** (no-topic mode): `fetchMore()` now fires `API.getTimeline(100)` and
  `API.getFeed(DISCOVER_FEED_URI, 50)` in parallel via `Promise.allSettled()`. Results are
  merged and deduped by URI before being passed to the video filter. Gives a much richer
  video queue for users who haven't set a topic.
- **Short-clip / GIF filter**: `loadVideoInSlot()` checks if the source URL ends in `.gif`
  and skips immediately. A `durationchange` listener skips videos with `duration < 5`
  seconds once the duration is known.
- **State reset**: `tvPaused` is reset to `false` in both `startTV()` and `tvStop()`.

### Milestone 40: Seen-Posts Deduplication ✅
- **Storage**: `bsky_feed_seen` in localStorage. Value: JSON object where keys are post
  URIs and values are `{ seenAt, likeCount, repostCount }`. Loaded into a `Map` on startup.
  FIFO eviction at 5,000 entries.
- **Marking**: After each `renderFeedItems()` call, `markFeedPostSeen(uri, likeCount,
  repostCount)` is called for every rendered item.
- **Filtering**: Before rendering, `isFeedPostSeen()` returns `true` if the post has been
  seen AND its current engagement (likes + reposts) hasn't grown by ≥ 50 interactions since
  first view. Viral posts resurface automatically.
- **Show-anyway hint**: `showFeedSeenHint(count)` injects a subtle bar below the feed
  results: "N posts filtered (show anyway)". Clicking sets `feedSeenBypass = true` and
  re-runs `loadFeed()` with the bypass active.
- **Scope**: Applies to both Following and Discover modes on the home feed.

---

## Upcoming Milestones

Milestones are ordered roughly by interdependency and implementation complexity.
Items marked **[RESEARCH]** need API/cost investigation before work begins.

---

### Milestone 12: Bsky Dreams TV (Continuous Video Feed) ✅
- **Entry**: "TV" nav tab (television icon).
- **Setup screen**: Topic/hashtag input + "▶ Start TV" button — ensures first user
  interaction fires before audio is requested.
- **Queue engine**: `searchPosts(topic, 'latest', 25)` → extracts posts with
  `app.bsky.embed.video#view` (or `recordWithMedia` with video media). Pre-fetches
  more when <5 remain. Skips non-playable entries automatically.
- **HLS player**: Reuses the same HLS.js-based loading pattern as the post-card video
  embed. `tvStop()` destroys the Hls instance and resets state.
- **Overlay**: Author avatar, name, handle, post text (2-line clamp). Like and Repost
  buttons on the right side update counts and toggle state in-place.
- **Controls bar**: Mute/Unmute, Skip, Stop, topic badge, queue count.
- **Navigation**: "Open post" button jumps to the full thread view. Navigating away
  from TV via any nav button automatically calls `tvStop()`.
- **Muted by default**: Audio starts muted after the first Start TV click; user
  unmutes intentionally to satisfy browser autoplay policies.

### Milestone 21: Reporting Bad Actors ✅
- **Report post**: Three-dot button on every post card (visible on hover/focus).
  Opens a modal with reason chips and optional free-text note.
- **Report account**: Three-dot button next to Follow on profile headers.
- **Modal**: Reason chips (Spam, Harassment, Misleading, Sexual, Rude, Other),
  optional textarea, Cancel / Submit. `API.createReport()` calls
  `com.atproto.moderation.createReport` with appropriate `$type` for post vs. account.
- **Confirmation**: Floating success banner for 3 seconds after submit.

### UX Improvements ✅
- **Default home view**: App opens to the Following feed instead of Search.
  `enterApp()` fallback changed to `showView('feed'); loadFeed()`. History seed
  updated to `?view=feed`.
- **Pull-to-refresh**: Feed refresh button replaced with pull-to-refresh gesture.
  `#ptr-indicator` element hidden above scroll area (`margin-top: -52px`). Touch
  handlers on `viewFeed` detect downward pull at `scrollTop === 0`, reveal and
  animate the indicator, trigger `loadFeed()` on release past 64px threshold.

### Bsky Dreams TV Enhancements ✅
- **TikTok-style redesign**: Auto-hiding overlay (3-second timer; any touch/click
  resets it). Post metadata (avatar, name, text) in a left column; icon-only
  controls (mute, stop) in the right column. Author name/handle tappable to open
  their profile via `openProfile()`.
- **Two-slot slide animation**: `#tv-slide-a` and `#tv-slide-b` containers sit
  `position: absolute; inset: 0` with their own `<video>` elements. On advance or
  back, `slideTransition(direction, cb)` snaps the incoming slide off-screen (no
  transition), forces a reflow, then animates both slides simultaneously at 320ms
  cubic-bezier. `tvSliding` flag prevents overlapping transitions.
- **Back navigation**: Swipe-down or scroll-up decrements `tvIndex` and calls
  `playAt(tvIndex - 1, 'down')`, restoring the previous video.
- **Dual topic search**: For custom-topic queries, `Promise.allSettled()` fires
  both a hashtag search (`#topic`) and a plain-text search (`topic`) in parallel.
  Results are merged with an inline dedup `Set`. Fixes the bug where custom
  searches found no videos because text results rarely included video posts.
- **Watch history**: Seen video URIs stored in `localStorage` under `bsky_tv_seen`
  (max 1,000, FIFO eviction). `markSeen(uri)` called before `showOverlay()`.
  `fetchMore()` skips seen URIs alongside video/adult checks. "Clear watch history
  (N seen)" button shown at the TV setup screen bottom.
- **Adult content filter**: Toggle on the setup screen; `isAdultPost()` helper
  checks `post.labels` for `sexual` / `nudity` label values.

### Home Feed: Discover Tab + Overscroll Fix ✅
- **Discover tab**: Home feed header replaced with a "Following | Discover" tab
  bar (`role="tablist"`). "Discover" calls `API.getFeed(DISCOVER_FEED_URI)` using
  BlueSky's What's Hot generator
  (`at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot`).
  "Following" calls `API.getTimeline()`. `setFeedMode()` swaps active-tab styling
  and `aria-selected`. `loadFeed()` branches on `feedMode` state variable. Feed
  cursor resets on tab switch.
- **API addition**: `API.getFeed(feedUri, limit, cursor)` added to `js/api.js`,
  wrapping `app.bsky.feed.getFeed`, and exported.
- **Overscroll fix**: Added `overscroll-behavior: none` to `.view` in
  `styles.css`. `body` already had it, but `.view` is the actual scroll container
  for thread, profile, notifications, and feed pages — the elastic rubber-banding
  was occurring inside those inner containers.

---

### Milestone 13: Horizontal Event Timeline Scrubber

**Goal:** Swipeable left-to-right timeline view for a topic, with timestamps prominent.

- **Entry**: A "Timeline" view mode toggle within search results (icon: horizontal
  bars / timeline icon).
- **Layout**: Posts are arranged horizontally on a scrollable rail. Each card shows
  timestamp large at top, then author + text snippet. Cards are chronologically ordered
  left-to-right (oldest left, newest right).
- **Scrubbing**: Mouse drag, trackpad swipe, or touch swipe scrolls left/right.
  A date/time axis runs below the cards. Clicking a card opens the full thread.
- **Zoom levels**: Toggle between "hours" and "days" grouping to control density.
- **Use case**: Enter a news event or hashtag, switch to Timeline mode to see how
  the story developed over time.

---

### Milestone 14: Network Constellation Visualization

**Goal:** Visual, interactive force-directed graph of user interactions on a topic.

- **Entry**: "Constellation" button/tab in the search results view.
- **Data**: Run `searchPosts(query, 'latest', 100)`, extract all author handles and
  `reply.parent.author` relationships. Build a graph: nodes = users, edges = replies.
- **Rendering**: D3.js (loaded locally, no CDN) force-directed layout. Node size
  proportional to post count on the topic. Edge weight proportional to reply count.
- **Interaction**: Click a node to center it and show only that user's connections.
  Hover shows username + post count tooltip. Double-click opens that user's profile.
- **Visual style**: Dark background, glowing nodes (accent color), subtle animated
  edge lines — evocative of a star constellation.
- **Performance**: Cap at 150 nodes; cluster smaller nodes into aggregate "others" ring.
- **Library**: D3.js v7, served locally as `/js/d3.min.js`.

---

### Milestone 15: Profile Interaction Graph (Frequent Contacts)

**Goal:** Show who a profile interacts with regularly, surfaced on their profile page.

- **Data source**: Fetch the last 100 posts from `getAuthorFeed` with
  `filter: 'posts_and_author_threads'` (includes replies). Extract handles from
  `reply.parent.author`. Count frequency.
- **Display**: Below the profile stats, a "Frequent conversations with" section shows
  the top 6–8 handles as avatar chips. Clicking one opens their profile.
- **Own profile**: On the logged-in user's own profile, this section is labeled
  "People you talk to most." On others: "Often replies to."
- **Mutual detection**: Flag mutual conversations (A replied to B, B replied to A)
  with a "↔ mutual" indicator.

---

### Milestone 16: Direct Messages (Native Chat API)

**Goal:** iMessage-style 1:1 chat using BlueSky's native `chat.bsky.convo.*` API.

- **Entry**: "Messages" nav tab (speech bubble icon with dot badge for unread).
- **Conversation list**: Left panel (or full screen on mobile) lists open convos,
  sorted by most recent. Each row: avatar, handle, last message snippet, timestamp.
- **Chat view**: Right panel (or full screen on mobile after selecting a convo).
  Messages displayed in bubble style — own messages right-aligned (accent), theirs
  left-aligned (surface). Timestamps grouped by day.
- **Compose**: Text input at bottom, send on Enter or button. Character count (1000
  char limit per AT Protocol spec).
- **New conversation**: "New message" button; search for a handle to start a convo.
- **Polling**: Refresh convo list every 30 s while Messages view is active.
- **API endpoints**: `chat.bsky.convo.listConvos`, `chat.bsky.convo.getMessages`,
  `chat.bsky.convo.sendMessage`, `chat.bsky.convo.getConvo`.
- **Note**: The BlueSky chat API requires a different base URL proxy
  (`https://api.bsky.chat/xrpc/`). Auth token is the same accessJwt.

---

### Milestone 17: Image Tools in Compose + Link Preview Control

**Goal:** Create stylized "text shots" and control link preview metadata in compose.

- **Text shot builder**: A "T" button in the compose toolbar opens a canvas-based
  editor. User types or pastes text; chooses background (solid color, gradient, or
  photo from a preset library), font size, and alignment. Output is a PNG rendered
  via Canvas API and attached as an image to the post.
- **Link preview control**: When a URL is pasted into the post text, fetch its
  OpenGraph metadata via a free CORS-compatible proxy (e.g., `allorigins.win` or
  similar zero-cost service). Show a preview card with editable title and description.
  The final OG data is embedded as `app.bsky.embed.external`.
- **GIF support**: A "GIF" button opens a Tenor GIF search (Tenor API has a free
  tier; key required). Selected GIF is attached as an image blob (GIF file).
  *Note: Tenor API key needed; document in README.*

---

### Milestone 18: Post Collections + Export

**Goal:** Save individual posts to named collections; export as shareable image.

- **Selection**: A bookmark icon (☆) appears on every post card. Clicking it adds
  the post to a "Quick collection" or prompts to choose/create a named collection.
- **Collections view**: Dedicated nav tab or accessible from profile menu. Lists
  all collections with post count and preview thumbnails.
- **Collection detail**: Grid of saved post cards. Can drag-reorder or remove posts.
- **Export as image**: "Export" button renders selected posts as a vertical
  image strip using Canvas API. Style matches the app's card design. A "Post to
  BlueSky" shortcut attaches the rendered image to a new compose draft.
- **Export as JSON**: "Download data" exports collection as a JSON file for
  backup/import.
- **Persistence**: Collections stored in localStorage (Milestone 20 adds AT Protocol
  sync).

---

### Milestone 19: Deep-Link URL Routing (Query-Param Based)

**Goal:** Every view in Bsky Dreams has a shareable URL that survives a page refresh.

- **Routing scheme** (query-param; GitHub Pages safe):
  - Search: `?q=query&filter=posts`
  - Post/thread: `?view=post&uri=at%3A%2F%2F...`
  - Profile: `?view=profile&actor=handle.bsky.social`
  - Channel: `?view=channel&id=channel-id`
  - Notifications: `?view=notifications`
- **On load**: `init()` reads `window.location.search`, parses params, and routes
  to the appropriate view + fetches the right data (re-login required if session
  expired).
- **On navigation**: `history.replaceState` (not push) updates the URL without
  creating a history entry for every click. `pushState` is used only for
  Back-navigable transitions (thread ↔ search, profile ↔ feed).
- **Shareable post link**: Each post card gains a "Copy link" option (⋯ menu) that
  copies the Bsky Dreams deep-link URL to the clipboard.
- **BSky post URL import** (also covers old Milestone 11): Pasting a `bsky.app`
  post URL into the search bar is detected and redirected to the thread view via
  the existing `resolvePostUrl` helper.

---

### Milestone 20: Cross-Device Settings Sync (AT Protocol Repo)

**Goal:** Persist channels, collections, and preferences across devices without a backend.

- **Storage record**: App state is serialized to JSON and written to the user's own
  AT Protocol repo via `com.atproto.repo.putRecord` with a custom lexicon collection
  `app.bsky-dreams.prefs` and a fixed rkey `self`.
- **Schema** (stored as the record value):
  ```json
  {
    "savedChannels": [...],
    "collections": [...],
    "uiPrefs": { "hideAdult": true, "theme": "light" }
  }
  ```
- **Read on login**: `init()` fetches the prefs record after auth succeeds
  (`com.atproto.repo.getRecord`). Falls back to localStorage if the record doesn't
  exist yet (first login on a new device).
- **Write on change**: Debounced 2-second write after any preference change.
  Conflicts are resolved by "last write wins" (no merge needed for this use case).
- **Privacy**: The record is in the user's own PDS. It is technically readable by
  anyone who knows the DID + collection + rkey. Avoid storing secrets; prefs only.

---

### Milestone 21: Reporting Bad Actors

**Goal:** Let users report posts or profiles to BlueSky from within Bsky Dreams.

- **Entry**: A "⋯" overflow menu on every post card and profile header. Option:
  "Report this post" / "Report this account."
- **Report form**: A small modal with reason chips:
  - Spam
  - Misleading / Misinformation
  - Harassment / Hate speech
  - Illegal content
  - Other (free text)
- **API**: `com.atproto.moderation.createReport` with `reasonType` matching the
  AT Protocol vocab (`com.atproto.moderation.defs#reasonSpam`, etc.).
  Reports go to the user's PDS (bsky.social) — the same destination as the native app.
- **Confirmation**: Brief success banner; no further action needed from the user.

---

### Milestone 22: Analytics Dashboard

**Goal:** Interactive metrics view for own posts and any searched profile/topic.

- **Entry**: "Analytics" nav tab (bar-chart icon). Default view is own profile stats.
- **Charts** (rendered via Chart.js, served locally as `/js/chart.min.js`):
  - Engagement over time (likes + reposts per post, plotted by date)
  - Top posts table (sorted by likes, reposts, or replies)
  - Follower count over time (requires storing snapshots in localStorage since
    AT Protocol doesn't expose historical follower counts)
  - Post frequency heatmap (GitHub-style contribution graph)
- **Actor switcher**: Search bar at top to switch the dashboard to any public profile.
- **Topic mode**: Enter a hashtag/query to see aggregate engagement stats across
  all posts in that search.

---

### Milestone 23: RSS/News Contextual Sidebar

**Goal:** Surface relevant news articles alongside search results for context.

- **Data source**: A curated list of CORS-friendly RSS feeds from major news outlets
  (BBC, Reuters, AP News, NPR — all serve RSS with permissive CORS headers).
  Configurable in settings.
- **Fetch**: Direct `fetch()` of RSS XML in the browser (no proxy needed for the
  above sources). Parse with the browser's built-in `DOMParser`.
- **Integration**: When a search returns results, a collapsible "In the news"
  sidebar panel shows up to 5 related articles (matching search terms in title/
  description). Each article links out to the source.
- **Relevance**: Simple keyword match (search terms vs. article title + description).
  Future enhancement: TF-IDF scoring.
- **Refresh**: News panel updates when the search query changes. Cached 15 min
  in memory to avoid hammering RSS servers.

---

### Milestone 24: Post-to-Image Export (Stylized Post Cards)

**Goal:** Convert any BlueSky post into a beautiful shareable image.

- **Entry**: "Share as image" option in the post card ⋯ menu and in the Lightbox.
- **Canvas renderer**: Draws a styled post card to an offscreen `<canvas>`:
  - Author avatar (loaded as Image), display name, handle, timestamp
  - Post text (word-wrapped, with hashtags in accent color)
  - Attached images (if any), rendered below text
  - Background options: white, dark, gradient (3–4 presets), or custom color picker
  - "Posted on BlueSky" footer with the Bsky Dreams logo and a link URL
- **Export**: `canvas.toBlob('image/png')` → download link or direct "Attach to
  new post" button (pre-fills compose with the image).
- **Annotation layer** (stretch goal): Thin drawing tool overlay on top of the
  rendered card for quick annotations before export. Feeds into Milestone 26 below.

---

### Milestone 25: Lightbox Remix / Annotation Tools

**Goal:** Annotate images in the lightbox and repost them with a reply to the original.

- **Entry**: "Annotate" button in the lightbox bottom bar (pencil icon).
- **Tools**: Freehand draw (pen tool, 3 stroke widths), text label (click to place),
  arrow, rectangle highlight. Eraser. Undo (up to 20 steps).
- **Color picker**: 8 preset colors + custom.
- **Save flow**: "Post annotation" button renders the annotated canvas to PNG,
  opens the compose view with the image pre-attached and a reply reference set to
  the original post.
- **Implementation**: Canvas 2D API overlay drawn on top of the original image.
  No external library needed.

---

### Milestone 26: Location-Based Content Discovery

**Goal:** Find posts related to a geographic area using content signals, not metadata.

- **Signals used** (in priority order):
  1. Profile location field (`actor.location` string) — parsed for city/country names
  2. Hashtags matching city/country names (e.g., `#NYC`, `#London`)
  3. Keyword detection in post text (city names, landmarks from a bundled lookup table)
- **Entry**: "Near" filter chip in the search bar. Opens a location picker
  (text input or map click via Leaflet.js + OpenStreetMap, both zero-cost).
- **Results**: Posts are ranked by location-signal match strength. Low-confidence
  matches are labeled "Possibly near [location]."
- **Bundled data**: A static JSON file (`/js/locations.json`) maps major city names
  and aliases to coordinates + country. No external geocoding API needed.

---

### Milestone 27: Deferred — Requires API/Cost Research

The following milestones need further investigation into available APIs, cost models,
and accuracy before implementation can be scoped:

#### 27a: Fact-Checking Integration (originally Milestone 14)
- Potential approaches:
  - Free: link out to Google Fact Check Explorer search for claims in post text
  - Paid: ClaimBuster API, PolitiFact API — need cost/quota assessment
  - Heuristic: detect known misinformation domains from a static blocklist (no API)
- **Blocker**: No zero-cost, automated fact-check API with acceptable accuracy exists today.

#### 27b: Political Bias / Spectrum Analysis (originally Milestone 21)
- Potential approaches:
  - Linked-domain bias: use AllSides or Media Bias/Fact Check open dataset (JSON)
    to rate domains in shared links — zero-cost, static, limited to known outlets
  - Profile-level NLP: requires an LLM API call per profile — not zero-cost
- **Partial implementation possible**: Domain-level bias rating for linked articles
  using a bundled static dataset. Profile-level spectrum analysis deferred.

#### 27c: AI-Generated Content Detection (originally Milestone 24)
- Potential approaches:
  - Text: No reliable zero-cost heuristic; most detectors are probabilistic and inaccurate
  - Images: Hive Moderation API (paid), Illuminarty (paid), or Content Credentials
    (C2PA) spec — check if BlueSky embeds C2PA metadata (promising, zero-cost)
- **Partial implementation possible**: Check for C2PA "Content Credentials" metadata
  in image uploads if BlueSky surfaces it in the blob record. Otherwise fully deferred.

---

### Milestone 28: Discover Feed as Default

**Goal:** Open the home feed to the Discover tab by default; Following remains one tap away.

- Change `feedMode` initial value from `'following'` to `'discover'` in `app.js`.
- Call `setFeedMode('discover')` inside `enterApp()` before `loadFeed()`.
- Update the "Following" tab label to be clearly secondary (no other visual change needed;
  the active-tab underline already communicates which is selected).
- **Rationale:** New and returning users benefit from a curated discovery feed on first
  load; Following is always reachable via one tap.

---

### Milestone 29: GIF Playback in Timeline

**Goal:** Animated GIFs play correctly in feeds and threads rather than appearing as
static images.

- **Direct BlueSky uploads**: Posts with `app.bsky.embed.images` where the blob MIME
  type is `image/gif` — detect and render as `<img src="...">` with no `object-fit`
  crop so the animation runs. The AT Protocol CDN serves GIF blobs at their original
  URL; animation is suppressed only if the app renders them inside a CSS-cropped grid
  cell that forces a repaint.
- **Embedded Tenor / Giphy GIFs**: These appear as `app.bsky.embed.external` link
  cards with hostnames like `tenor.com`, `c.tenor.com`, `media.giphy.com`, or
  `giphy.com`. Detect these hostnames and render the GIF URL as an `<img>` inline
  rather than a plain link card. Tenor media URLs end in `.gif` or `.mp4`; prefer
  the `.gif` URL for animated display.
- **Detection helper**: `isGifEmbed(embed)` — checks image MIME or external URL
  hostname/extension.
- **No autoplay policy issues**: `<img>` elements are not subject to browser autoplay
  rules; GIFs animate automatically without user gesture.

---

### Milestone 30: Quote Post Interface

**Goal:** Tapping "Repost" offers a choice between a plain repost and a quote post,
mirroring the native BlueSky client behavior.

- **Repost button action sheet**: Replace the immediate repost toggle with a small
  popup/bottom sheet offering two options: "Repost" (existing behavior) and
  "Quote Post." On desktop, a small dropdown; on mobile, a bottom sheet.
- **Quote post compose modal**: Selecting "Quote Post" opens a modal with a full
  compose textarea (character counter, image attach), and a read-only quoted-post
  preview card pinned at the bottom.
- **API embed**: On submit, `API.createPost()` with
  `embed: { $type: 'app.bsky.embed.record', record: { uri, cid } }`.
  If images are also attached, use `app.bsky.embed.recordWithMedia` instead.
- **Unrepost behavior unchanged**: The "Repost" option in the sheet still toggles
  unrepost if the post is already reposted (check `data-repost-uri`).

---

### Milestone 31: Reposter Name as Profile Link

**Goal:** The "Reposted by X" attribution bar is tappable and opens the reposter's profile.

- The repost bar is currently rendered as static text with an avatar `<img>`.
- Wrap the reposter's avatar and display name in a `<button class="author-link">` (or
  `<span role="button">`) with a click handler that calls `openProfile(reposter.handle)`.
- Ensure `stopPropagation()` so the click doesn't also open the post's thread.
- Apply consistent `cursor: pointer` and hover styling matching other `author-link`
  elements throughout the app.

---

### Milestone 32: iOS Safari PWA Session Persistence

**Goal:** Users who add Bsky Dreams to their iOS home screen should stay logged in
across app launches, matching the expected behavior of a native app.

- **Root cause investigation**: Safari standalone PWA mode uses a separate, persistent
  localStorage context (not session-scoped). The session likely expires because:
  1. `accessJwt` has a ~2-hour TTL.
  2. On `visibilitychange` or cold launch, the app may not be proactively refreshing
     the token before it expires.
- **Token refresh hardening**: In `auth.js`, on every `visibilitychange` event
  (`document.hidden === false`), check the age of the stored `accessJwt` (decode the
  JWT payload's `exp` field client-side). If expiry is within 15 minutes, proactively
  call `com.atproto.server.refreshSession` using the stored `refreshJwt` and write the
  new tokens back to localStorage.
- **Graceful expiry message**: If both tokens are expired, show a friendly "Your session
  expired — please sign in again" message instead of a silent blank screen.
- **Web App Manifest**: Verify `index.html` includes `<meta name="apple-mobile-web-app-capable" content="yes">` and a `<link rel="manifest">` with `"display": "standalone"` so iOS
  treats the icon as a full-screen web app rather than a Safari shortcut.
- **`refreshJwt` storage audit**: Confirm `bsky_session` in localStorage stores both
  `accessJwt` and `refreshJwt` (and not just the access token).

---

### Milestone 33: Mention Links in Posts

**Goal:** @mention spans in rendered post text open the mentioned user's profile when
tapped or clicked.

- `renderRichText()` already detects `app.bsky.richtext.facet#mention` facets and
  applies a CSS class for styling — but the click handler that calls `openProfile()`
  is missing or not wired.
- Add a `click` event listener to each mention `<span>` that calls
  `openProfile(facet.features[0].did)`. The DID is available directly in the mention
  facet; no handle-resolution step needed (existing `openProfile` already accepts DIDs).
- Add `cursor: pointer` and `role="button"` / `tabindex="0"` for accessibility.
- Add `stopPropagation()` so the click doesn't also open the post's thread view.

---

### Milestone 34: Pull-to-Refresh Resistance + Scroll-to-Top Button

**Goal:** PTR is harder to trigger accidentally while scrolling; a scroll-to-top button
provides an easy way to reach the top without over-scrolling.

- **Increased PTR resistance**: Require `scrollTop === 0` AND pull distance > 96px
  (up from 64px) AND the pull must be held for 400ms before the indicator locks into
  the "release to refresh" state. This prevents accidental triggers when the user flicks
  back to the top of a long feed.
- **Scroll-to-top overlay button**: A small circular arrow-up button, `position: fixed`
  at bottom-left (above the sidebar on desktop). Appears only after the user has scrolled
  more than 300px in the current view. Clicking it calls
  `viewFeed.scrollTo({ top: 0, behavior: 'smooth' })` (or the active view's container).
  Fades in/out with a CSS `opacity` transition. Works on all views (feed, thread, profile,
  notifications), not just the home feed. Once at the top, the button hides — the user
  can now pull to refresh normally.

---

### Milestone 35: Inline Reply from Home Feed

**Goal:** Tapping "Reply" on a home-feed post expands an inline compose box in the feed
itself, so users can reply without navigating away to the thread view.

- Reuse the existing `expandInlineReply(postCard, post)` mechanism from the thread view.
- The `reply.refs` passed to `API.createPost()` should point to the tapped post
  as both `parent` and (if no `item.reply` context) `root`; if the post is itself a
  reply, use `item.reply.root` as `root`.
- After successful posting, close the inline box and show a brief "Replied ✓" state
  on the Reply button without navigating or reloading the feed.
- Opening the full thread remains available via tapping the post card body (existing behavior).
- **Rationale**: Conversations are the engine of community. Frictionless in-feed replies
  lower the barrier to engagement and are more likely to produce meaningful exchanges
  than requiring full thread navigation.

---

### Milestone 36: Bsky Dreams TV — Enhancements

**Goal:** Make TV more reliable, richer in content, and more interactive.

- **Filter GIFs and very short clips**: After `loadVideoInSlot()`, listen to the
  `canplay` event and check `video.duration`. Skip (call `advanceToNext()`) if
  `duration < 5` seconds or if the source URL ends in `.gif`.
- **Fix inconsistent autoplay**: Likely cause is that `hls.loadSource()` and `video.play()`
  race with media segment availability. Fix: defer `video.play()` until the HLS
  `MANIFEST_PARSED` event, and add a `canplay` listener as a fallback. Ensure
  `hls.startLoad()` is called explicitly after attaching media.
- **Dual-feed queue**: Seed the TV queue from both `API.getTimeline()` and
  `API.getFeed(DISCOVER_FEED_URI)` in parallel. Deduplicate by post URI first, then
  by the embedded video's CID (catches reposts of the same video by different accounts).
  Topic/hashtag queue mode unchanged.
- **2× speed hold**: On `pointerdown` inside the video wrap, set
  `video.playbackRate = 2`. On `pointerup` or `pointercancel`, restore to `1`. All
  modern browsers including Safari on iOS 10+ support `HTMLMediaElement.playbackRate`.
- **Pause button**: Add a pause/resume control to the left-side icon column (between
  the mute and stop buttons). Toggles `video.paused ? video.play() : video.pause()`.
  Icon switches between ▶ and ⏸.

---

### Milestone 37: Image Browser ("Bsky Dreams Gallery")

**Goal:** A dedicated browsing view for images from both Following and Discover feeds,
styled like early Instagram — image-first, scrollable, interactive.

- **Entry**: New nav tab (camera or grid icon) or accessible via a toggle from the home
  feed header.
- **Data source**: Pull from both `API.getTimeline()` and `API.getFeed(DISCOVER_FEED_URI)`
  in parallel. Filter to posts containing `app.bsky.embed.images` or
  `app.bsky.embed.recordWithMedia` with image media only (exclude video, exclude GIF
  images detected by MIME or URL extension).
- **Deduplication**: Skip reposts of the same post URI; skip posts where an image blob
  CID has already appeared (catches cross-account reposts of the same image). Filter out
  posts already marked in `bsky_feed_seen` if M40 is implemented.
- **Layout**: Vertical scrolling feed. Each card shows the image grid (full-width for
  single images, 2×2 for multiple), a slim author strip below (avatar + handle + like/repost
  counts). No post text visible by default — tap the card body to expand the caption.
- **Interaction**: Tap image → lightbox carousel (existing `openLightbox()`). Like and
  Repost buttons below each image strip.
- **Pagination**: Infinite scroll — fetch more on reaching the bottom.

---

### Milestone 38: Minor Interface Polish

**Goal:** Fix several small but frequent annoyances identified during daily use.

- **PTR indicator clipping on desktop**: The `#ptr-indicator` uses `margin-top: -52px`
  to hide above the scroll area, but on desktop the top bar does not fully clip it.
  Add `overflow: hidden` to `.view-inner` (or specifically to the feed view container)
  so the indicator is truly invisible until actively pulled.
- **Channels sidebar hidden by default**: Change the initial sidebar state to collapsed
  on all screen sizes. The sidebar toggle button (hamburger/channels icon in the nav bar)
  opens it. On desktop (≥768px), remember the last open/closed state in localStorage
  under `bsky_sidebar_open`. Most first-time users will have no channels, so showing an
  empty sidebar wastes horizontal space.
- **Logo click refreshes homepage**: Add a click listener to the Bsky Dreams title/logo
  element in the nav bar that calls `showView('feed')` and `loadFeed()`.
- **Timestamp as external link**: The relative-time badge ("3h", "2d") on each post card
  is currently plain text. Wrap it in an `<a href="https://bsky.app/profile/{handle}/post/{rkey}" target="_blank" rel="noopener">` so tapping it opens the original post on bsky.app.
  Derive the rkey from the AT URI (`uri.split('/').pop()`).
- **Like button race condition**: The like button currently toggles the UI state
  optimistically before the API call resolves. If the API call fails, the UI is out of
  sync. Fix: disable the button during the in-flight request and roll back the UI state
  (count + filled/outline icon) on error. This also prevents the double-tap issue where
  a slow network causes the user to tap twice.

---

### Milestone 39: Feed Content Filters ("Advanced" Toggle on Home Feed)

**Goal:** Let users temporarily suppress broad topic categories from their feeds without
leaving the app or adjusting BlueSky's account-level preferences.

- **UI**: "Advanced ▾" toggle below the Following/Discover tab bar, mirroring the
  existing toggle on the search page. Expands a filter panel.
- **Filter categories** (checkboxes): Politics, Sports, Current Events, Entertainment,
  Other (free-text keyword list).
- **Implementation**: Client-side keyword matching. A static bundled file
  `/js/filter-words.json` holds arrays of keywords per category. After `renderFeedItems()`,
  scan each rendered post's text against enabled category word lists; hide matching posts
  with `display: none` and increment a "N posts filtered" counter shown in the panel.
  Posts are fetched in full — filtering is purely presentational.
- **Ephemeral by default**: Filter state is session-only unless the user explicitly saves
  it (a "Remember my filters" checkbox writes to localStorage under `bsky_feed_filters`).
- **Caveat note in UI**: Label the filters "Approximate — keyword matching may miss or
  misidentify some posts."

---

### Milestone 40: Seen-Posts Deduplication for Home Feeds

**Goal:** Posts the user has already scrolled past are not served again in subsequent
feed loads, mirroring the TV watch-history mechanism applied to the text feed.

- **Storage**: `bsky_feed_seen` in localStorage. Key: post URI. Value: `{ seenAt,
  likeCount, repostCount }` at time of first view. Cap: 5,000 entries (FIFO eviction).
- **Marking**: After each `renderFeedItems()` call, iterate rendered items and call
  `markFeedSeen(uri, likeCount, repostCount)`.
- **Filtering**: Before rendering, skip posts whose URI is in `bsky_feed_seen` unless
  their current like+repost count exceeds the stored count by ≥ 50 interactions —
  "gone viral since you saw it" posts resurface automatically.
- **"Show anyway" escape hatch**: At the bottom of the feed (above "Load more"), if any
  posts were hidden, show a subtle "N posts filtered (show anyway)" link that sets a
  session flag to bypass the filter for the current view.
- **Scope**: Applies to both Following and Discover modes.

---

## Open Questions

1. **Token refresh**: `withAuth` retries once on 401. If the refresh token is
   also expired the user must sign in again — no graceful expiry message yet.
2. **Adult content toggle**: Currently uses CSP labels from post/author. BlueSky
   has a richer labelling system (`com.atproto.label.*`) that could give finer
   control.
3. **video.bsky.app CORS**: The CSP was widened to `connect-src *` because HLS
   segment URLs may resolve to CDN subdomains not predictable at build time.
   This resolved video playback. No proxy needed.
4. **Image file size limit**: AT Protocol limits blobs to 1 MB. Auto-resize (M6)
   handles this client-side but GIF animation is lost on resize.
5. **Notification polling**: Notifications are loaded once per session open.
   There is no polling or WebSocket push; users must tap Refresh to see new ones.
6. **DM base URL**: `chat.bsky.convo.*` endpoints use `https://api.bsky.chat/xrpc/`
   not `bsky.social/xrpc/`. The auth.js `withAuth` wrapper will need a base-URL
   parameter or a separate helper in api.js.
7. **AT Protocol prefs record privacy**: The `app.bsky-dreams.prefs` record is
   publicly readable by anyone who knows the DID. This is acceptable for
   non-sensitive prefs but must be documented clearly to users.

## Blockers

None currently.

## Next Session Starting Point

Priority order for implementation (roughly):

### High priority — feature enhancements (next up)
1. **M37 — Image browser / Gallery** (dedicated image feed, dedup, lightbox reuse)
2. **M39 — Feed content filters** (keyword filter panel, ephemeral by default)
3. **M22 — Analytics Dashboard** (engagement over time, top posts, Chart.js)

### Larger features
4. **M13 — Horizontal Event Timeline Scrubber**
5. **M14 — Network Constellation Visualization**
6. **M16 — Direct Messages** (chat.bsky.convo.* API)
