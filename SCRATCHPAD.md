# Project Scratchpad — Bsky Dreams

## Current Status

The app is live and functional. Milestones 1–10 are complete, plus the repost/quote-post rendering fixes.

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

---

## Upcoming Milestones

Milestones are ordered roughly by interdependency and implementation complexity.
Items marked **[RESEARCH]** need API/cost investigation before work begins.

---

### Milestone 9: Inline Reply Compose (Context-Preserving)

**Goal:** Let users reply without losing sight of the post they're replying to.

- **Inline compose box**: Clicking "Reply" on any post in the thread view expands
  an inline compose textarea *directly beneath that post card* rather than scrolling
  to the bottom. The post being replied to stays visible above the input.
- **Sticky post preview**: The post being replied to is shown as a small read-only
  quote above the textarea so it's always in view while writing.
- **Dismiss**: Clicking elsewhere or pressing Escape collapses the inline reply box.
- **Mobile**: The inline box is full-width and scrolls into view automatically
  (`scrollIntoView({ behavior: 'smooth', block: 'nearest' })`).
- **Bottom reply area**: The global reply-at-bottom area (currently the only option)
  is removed; all replies go through the inline flow.

---

### Milestone 11: Saved Searches as Channels (Sidebar)

**Goal:** Slack/Discord-style saved searches with unread-count badges.

- **Left sidebar**: A collapsible sidebar panel holds all saved searches ("channels").
  On desktop (≥768px) it is pinned open alongside the main content area. On mobile
  it slides in as a full-height drawer via a hamburger/channel-list button in the nav.
- **Saving a search**: A "Save as channel" button appears after any search. User
  can optionally rename the channel (default: the search query).
- **Unread count badge**: Each channel shows how many new posts have appeared since
  the user last viewed it. The last-seen cursor (or ISO timestamp) is stored per channel.
- **Channel view**: Clicking a channel runs the search, shows results, and clears
  its badge. Results are sorted "latest" for channels.
- **Persistence**: Channels are stored in localStorage first (Milestone 17 will add
  AT Protocol repo sync for cross-device persistence).
- **Reorder / delete**: Long-press or ⋮ menu per channel to rename, reorder, or delete.

---

### Milestone 12: Bsky Dreams TV (Continuous Video Feed)

**Goal:** TikTok/TV-channel-style continuous video feed on a topic.

- **Entry**: Dedicated "TV" nav tab (television icon). Opens to a full-screen video
  player view.
- **Channel selector**: A search/hashtag input at the top lets the user set the
  "channel" (e.g., `#nature`, `travel`). Default to an empty prompt asking for a topic.
- **Start screen**: A prominent "▶ Start TV" splash button is shown before any video
  plays, ensuring the first user interaction enables audio. Audio is on by default
  after that.
- **Queue**: Fetches posts with videos via `searchPosts(q, 'latest')`, extracts
  video embeds, plays them sequentially. When the last video in the queue is reached,
  a background refetch loads more and continues seamlessly.
- **Controls**: Mute/unmute, skip to next, pause. Post author + text overlay at bottom
  (semi-transparent, dismissible).
- **Like/repost in-view**: Like and repost buttons visible during playback without
  leaving TV mode.

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

1. **Milestone 9 — Inline Reply Compose** (context-preserving reply flow)
2. **Milestone 19 — Deep-Link URL Routing** (enables shareable links; unblocks other features)
3. **Milestone 11 — Saved Searches / Channels** (sidebar + unread counts)
4. **Milestone 12 — Bsky Dreams TV** (continuous video feed)
5. **Milestone 21 — Reporting Bad Actors** (moderation integration)
