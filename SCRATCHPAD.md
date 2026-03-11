# Project Scratchpad — Bsky Dreams

## Current Status

All milestones through M16 are complete. App is fully functional for daily Bluesky use.

**Next focus:** M17 (Text Shot Builder), M18 (Post Collections + Export).

---

## Completed Features (summary)

### Core (M1–M12, M19–M21, M28–M36, M38–M51)
- Auth (app password, localStorage session, iOS PWA refresh via `visibilitychange`)
- Home feed: Following + Discover tabs, infinite scroll, PTR, feed filters, seen-post dedup
- Search: post + actor, advanced filters (date, media type), load more, PTR
- Compose: rich text, images (up to 4), video upload, GIF picker (Klipy), link preview, post settings (threadgate/postgate), @mention autocomplete — in main compose, inline reply, and quote modal
- Thread view: depth-colored nesting, collapse/expand, depth ≥ 4 → "Continue this thread →"
- Profiles: feed, follow/unfollow, report, inline reply from feed
- Notifications: type-coded, unread badge, click-to-navigate
- TV: dual-feed, TikTok-style overlay, two-slot slide, pause, 2× hold, adult filter, watch history
- Gallery: combined feed, image-only filter, blob-CID dedup, infinite scroll, PTR
- Deep-link URL routing (`?view=...`) via History API; bsky.app URL import
- Cross-device prefs sync via AT Protocol repo (`app.bsky-dreams.prefs`)
- Settings panel: accent color picker, default feed tab, clear history, iOS Share shortcut
- Klipy brand attribution; GIF posted as `app.bsky.embed.external` (animation preserved)

### M22: Analytics Dashboard
Canvas API bar chart (last 25 posts, likes + reposts stacked), post-frequency heatmap (GitHub-style, 12 weeks), top-posts table (sortable), actor switcher. No external chart library.

### M15: Profile Interaction Graph
After header renders, fetches last 100 posts (with replies) for the viewed actor via `API.getAuthorFeedWithReplies`. Tallies reply-to author frequency (excluding self), shows top 6 as avatar chips in a "Frequent conversations with" section. Chips link to those profiles. Hidden if no replies found.

### M14: Network Constellation Visualization
- **Entry**: "Constellation" sidebar nav; `?view=constellation`
- Search-seeded: query → `searchPosts` 100 posts; nodes = unique authors, edges = reply relationships (AT URI DID extraction)
- Cap 150 nodes (highest-count kept); D3.js v7 force-directed layout, served locally as `/js/d3.min.js`
- Zoom/pan; drag nodes; click node → filter to direct connections; second click deselects; double-click opens profile; hover tooltip
- Avatar images clipped to circles on each node; handle labels below

### M16: Direct Messages
- **Entry**: "Messages" sidebar nav; `?view=dms`
- Two-panel layout: conversation list (left/full) + bubble chat (right/full on mobile)
- API: `chat.bsky.convo.*` at `https://api.bsky.chat/xrpc/`; `chatGet`/`chatPost` helpers in api.js
- Conversation list: avatar, name, handle, last-message preview, timestamp, unread dot
- Chat: bubble UI (accent for own, surface for theirs), 30s polling for new messages, `updateRead` on open
- Compose: auto-grow textarea, 1,000-char limit with counter
- New conversation: "New" button → handle search via `searchActors` → `getConvoForMembers` to open/create

### M13: Horizontal Timeline Scrubber
Search → "Timeline" toggle. Posts positioned absolutely on horizontal rail by fractional time offset; 220px minimum step prevents overlap. Hours/Days zoom. Accessed via `openTimeline(query, posts)`.

### M-Reader: Article Reader View
- **Entry**: "Reader" sidebar nav; `?view=reader`
- **Filtering**: `getArticleEmbed(post)` — returns `external` embed only for readable link cards; excludes GIF hosts, social media, shopping, direct media extensions, titles < 12 chars
- **Cards**: thumbnail, domain (accent, uppercase), date (parsed from URL path `/YYYY/MM/DD/` etc., falls back to `indexedAt`), full Syne title (no line-clamp), description, author strip with like/repost/reply/mark-read actions
- **Mode toggle**: Direct | Readable | Archive. Archive uses `https://archive.ph/?url={encoded}`. Readable uses Mozilla Readability.js (bundled as `/js/Readability.js`) + three-proxy CORS fallback chain: **codetabs.com → corsproxy.io → allorigins.win** (each with 18s AbortController timeout); live step-by-step progress bar
- **Readability overlay toolbar**: ✕ close, reply/repost/like action buttons (wired to post object), domain label (hidden on mobile), "Archive ↗" + "Original ↗" links
- **Seen tracking**: `bsky_reader_seen` localStorage Set (max 10k URLs); marked on open OR per-card "✓" button; seen cards dimmed; "Mark all read" bulk action; seen URLs skipped on every `loadReaderBatch` call (reliable dedup across refreshes)
- **Article URL dedup**: within each batch, same URL → keep highest-engagement post only
- **Infinite scroll + PTR + scroll-to-top** (same pattern as Gallery)
- **PTR fix**: `#ptr-indicator` is now `position: fixed; top: -52px` (shared across all views); JS uses `style.top` instead of `style.marginTop`

---

## Planned Milestones

### M17: Text Shot Builder (partial — link preview + GIF in M41)
Canvas-based editor: background, font, alignment → PNG attached to compose

### M18: Post Collections + Export
Bookmark posts → named collections → export as image strip or JSON

### M23: RSS/News Contextual Sidebar
CORS-friendly RSS feeds (BBC, Reuters, AP, NPR) → keyword-matched "In the news" panel in search

### M24–M26: Post-to-Image Export, Lightbox Annotation, Location Discovery
(See earlier SCRATCHPAD versions for full specs)

---

## Deferred (paid API required)
- M27a: Fact-checking — no zero-cost API
- M27b: Political bias — domain-level static dataset possible; NLP not zero-cost
- M27c: AI content detection — C2PA partial; Hive/Illuminarty paid

---

## Open Questions
1. `isAdultPost()` uses label-string check; `com.atproto.label.*` offers finer control
2. Blob limit 1 MB — `resizeImageFile()` handles it but loses GIF animation
3. Notifications: no polling; stale until user navigates to view
4. `app.bsky-dreams.prefs` is publicly readable (non-sensitive prefs only)
5. Klipy not yet on Bluesky animated-GIF allowlist (issue #9728) — no code change needed when added
