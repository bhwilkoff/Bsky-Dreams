# Project Scratchpad — Bsky Dreams

## Current Status

The app is live and functional. Milestones 1–7 are complete.

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

### Milestone 7: Notifications ✅
- `API.listNotifications(limit, cursor)` — `app.bsky.notification.listNotifications`
- `API.updateSeen(seenAt)` — marks all notifications as seen
- Notification nav button (bell icon) with unread count badge
- `view-notifications` section: type-coded icon, author avatar, action label,
  post preview text, timestamp
- Click notification → opens profile (follow) or thread (like/repost/reply/mention/quote)
- Badge clears + `updateSeen` fires on first view

## Open Questions

1. **Token refresh**: `withAuth` retries once on 401. If the refresh token is
   also expired the user must sign in again — no graceful expiry message yet.
2. **Adult content toggle**: Currently uses CSP labels from post/author. BlueSky
   has a richer labelling system (`com.atproto.label.*`) that could give finer
   control.
3. **video.bsky.app CORS**: The CSP was widened to `connect-src *` because HLS
   segment URLs may resolve to CDN subdomains not predictable at build time.
   This resolved video playback. No proxy needed.
4. **Image file size limit**: AT Protocol limits blobs to 1 MB. The compose UI
   does not yet validate file size client-side before upload; users will see an
   API error if they exceed the limit.
5. **Notification polling**: Notifications are loaded once per session open.
   There is no polling or WebSocket push; users must tap Refresh to see new ones.

## Blockers

None currently.

## Next Session Starting Point

1. **Milestone 8 — Image size validation**: Warn the user if a selected image
   exceeds 1 MB before attempting upload. Add a client-side check in the file
   input change handler.
2. **Milestone 8 — GIF / video in Compose**: `com.atproto.repo.uploadBlob` for
   video requires a different embed type (`app.bsky.embed.video`). Scope this
   carefully — video upload is complex (transcoding may be needed server-side).
3. **Milestone 9 — Notification polling**: Add a periodic `listNotifications`
   call (e.g., every 60 s) to update the unread badge without requiring manual
   refresh.
4. **Milestone 9 — Token expiry UX**: Surface a friendly "Session expired —
   please sign in again" message instead of a generic API error when both JWTs
   have expired.
5. Confirm that the `main` branch PRs are merged so the live GitHub Pages site
   reflects all completed work.
