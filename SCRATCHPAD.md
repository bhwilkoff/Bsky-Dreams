# Project Scratchpad — Bsky Dreams

## Current Status

The app is live and functional. Multiple sessions of work have completed
Milestones 1–3 and partially completed Milestone 4. A new Milestone 5
(Home/Following Timeline) is now in progress.

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

### Milestone 4: Media + Rich Text ✅ (display) / ⏳ (authoring)
- **Images**: full-size grid, click-to-lightbox overlay with alt text caption
- **Alt text**: displayed prominently below each image; shown below video too
- **Video**: HLS.js v1.5.13 poster + play-to-activate; muted autoplay; error
  fallback shows "Watch video ↗ (reason)" link
- **External link cards**: thumbnail + title + description + hostname
- **Rich text rendering**: AT Protocol facets with TextEncoder/TextDecoder for
  correct UTF-8 byte offsets; hashtags clickable, mentions styled, URLs linked
- **recordWithMedia**: images or video alongside a quoted post all render
- ⏳ Alt text *authoring* (compose/reply): deferred — requires image upload,
  which is not yet implemented

## Active Milestone

### Milestone 5: Home / Following Timeline ✅
- `API.getTimeline(limit, cursor)` — `app.bsky.feed.getTimeline`
- `API.followActor(subjectDid)` / `API.unfollowActor(followUri)` — follow graph
- Home nav button + `view-feed` section in index.html
- `renderFeedItems()` in app.js (repost bar, reply context)
- Follow/Unfollow toggle on actor cards in People search results
- Pagination ("Load more") on home feed

### Milestone 6: Author Profiles ⏳ (in progress)
Goal: clicking any author avatar or name opens a profile view showing
their bio, follower stats, follow/unfollow button, and recent posts.

Tasks:
- [x] `API.getActorProfile(actor)` — `app.bsky.actor.getProfile`
- [x] `API.getAuthorFeed(actor, limit, cursor)` — `app.bsky.feed.getAuthorFeed`
- [x] `view-profile` section in index.html (back button, header area, feed, load more)
- [x] `openProfile(handle, opts)` + `renderProfileHeader(profile)` in app.js
- [x] `loadProfileFeed(actor, append)` with pagination
- [x] `.author-link` click handlers on avatar + name in every post card
- [x] Profile follow/unfollow button wired in renderProfileHeader
- [x] Follow button pill redesign (removed conflicting `action-btn` class)

## Open Questions

1. **Image upload in Compose**: Milestone 4 authoring is blocked on this. The
   AT Protocol requires uploading a blob first (`com.atproto.repo.uploadBlob`),
   then embedding the resulting CID. Worth tackling as Milestone 6.
2. **Author profile click-through**: Clicking an author name/avatar should open
   a profile view showing their bio and post history. Planned as part of
   Milestone 6.
3. **Notifications**: `app.bsky.notification.listNotifications` would surface
   replies, likes, reposts, and follows. Useful but not yet scoped.
4. **Token refresh**: `withAuth` retries once on 401. If the refresh token is
   also expired the user must sign in again — no graceful expiry message yet.
5. **Adult content toggle**: Currently uses CSP labels from post/author. BlueSky
   has a richer labelling system (`com.atproto.label.*`) that could give finer
   control.
6. **video.bsky.app CORS**: The CSP was widened to `connect-src *` because HLS
   segment URLs may resolve to CDN subdomains not predictable at build time.
   This resolved video playback. No proxy needed.

## Blockers

None currently.

## Next Session Starting Point

1. **Milestone 6 — Image upload in Compose**: `uploadBlob` → embed CID + alt
   text input; image preview before posting. This completes M4 alt-text authoring.
2. **Milestone 7 — Notifications**: nav notification badge +
   `view-notifications` using `app.bsky.notification.listNotifications`.
3. Confirm that the `main` branch PRs are merged so the live GitHub Pages site
   reflects all completed work.
