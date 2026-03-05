```
╔══════════════════════════════════════════════════════════════╗
║  ██████╗ ███████╗██╗  ██╗██╗   ██╗                           ║
║  ██╔══██╗██╔════╝██║ ██╔╝╚██╗ ██╔╝                           ║
║  ██████╔╝███████╗█████╔╝  ╚████╔╝                            ║
║  ██╔══██╗╚════██║██╔═██╗   ╚██╔╝                             ║
║  ██████╔╝███████║██║  ██╗   ██║                              ║
║  ╚═════╝ ╚══════╝╚═╝  ╚═╝   ╚═╝                              ║
║                                                              ║
║  ██████╗ ██████╗ ███████╗ █████╗ ███╗   ███╗███████╗         ║
║  ██╔══██╗██╔══██╗██╔════╝██╔══██╗████╗ ████║██╔════╝         ║
║  ██║  ██║██████╔╝█████╗  ███████║██╔████╔██║███████╗         ║
║  ██║  ██║██╔══██╗██╔══╝  ██╔══██║██║╚██╔╝██║╚════██║         ║
║  ██████╔╝██║  ██║███████╗██║  ██║██║ ╚═╝ ██║███████║         ║
║  ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝         ║
╚══════════════════════════════════════════════════════════════╝
```

# Bsky Dreams

**A Bluesky Web App built for people who want more from their Bluesky experience.**

> *Every feature in this app is built in service of human learning and growth —
> not to replace thinking or community, but to deepen it. The goal is never a slick product or an exhaustive feature list.
> It is a tool that helps make social media more human and collaborative.*

---

## What Is This?

Bsky Dreams is a zero-cost, zero-server, zero-dependency alternative interface for the [BlueSky](https://bsky.app) social network. It runs entirely in your browser as a static file — no backend, no Node.js, no build pipeline, no tracking. Just HTML, CSS, and JavaScript talking directly to the AT Protocol.

It was built to address the parts of BlueSky that feel unfinished: conversation depth, content discovery, media handling, search power, and cross-device persistence. But more than fixing friction — it was built with a belief that social software should make you *more curious*, not less.

**Live app:** [https://bskydreams.com](https://bskydreams.com)

---

## Why Build Another Client?

Most social apps optimize for time-on-platform. Bsky Dreams optimizes for something different.

At every design decision point, the question is: *does this invite deeper engagement, more critical thinking, or more meaningful connection?* Features that make users passive get reconsidered. Features that open doors to curiosity or collaboration get prioritized.

This means:
- Threads that let you trace a conversation from root to leaf, not just see a single reply in isolation
- Search that's powerful enough to actually find things, with media filters, sort options, and channel saves
- A TV mode that surfaces video from across BlueSky's network — not just an algorithmic feed loop
- A gallery that deduplicates content across all interfaces so you see more, not the same things over and over
- Cross-device preferences synced through your *own* AT Protocol repository — no third-party account needed

---

## The Architecture: Serverless by Principle

Bsky Dreams has **no backend**. This is a deliberate choice, not a limitation.

```
┌─────────────────────────────────────────────────────────┐
│                    YOUR BROWSER                         │
│                                                         │
│  index.html ──► css/styles.css                          │
│       │         js/app.js                               │
│       │         js/api.js         ┌──────────────────┐  │
│       │         js/auth.js   ───► │  bsky.social     │  │
│       │         js/hls.min.js     │  AT Protocol API │  │
│       │                           └──────────────────┘  │
│       └── localStorage                                  │
│           (session, channels, seen posts, prefs)        │
└─────────────────────────────────────────────────────────┘
         ▲
         │  served from
┌────────┴───────────┐
│   GitHub Pages     │
│   (main branch)    │
└────────────────────┘
```

**Why this works:**

- **BlueSky's AT Protocol uses open CORS** — any browser can call `bsky.social/xrpc/*` directly, no proxy needed
- **App Passwords provide scoped auth** — credentials only ever touch `bsky.social`, never a third-party server
- **Your AT Protocol repo is your sync backend** — preferences and saved searches live in your own Bluesky repo at `app.bsky-dreams.prefs`, readable by any device you're logged into
- **GitHub Pages is free and permanent** — the whole app deploys on every push to `main`, with zero CI configuration
- **No npm, no bundler, no build step** — `open index.html` is a valid and complete way to run this app

The only third-party services called at runtime are:
- `bsky.social` / `api.bsky.chat` — AT Protocol (your own social graph)
- `api.klipy.com` — GIF search (GIF picker only)
- `api.allorigins.win` — CORS proxy for OG link preview metadata only

---

## Features

### Reading & Discovery

**Home Feed**
- Following and Discover tabs (BlueSky's `whats-hot` curated feed)
- Infinite scroll with intelligent Discovery loop-back when the first page exhausts
- Pull-to-refresh (48px drag threshold, mobile-friendly)
- Seen-post deduplication across all interfaces — the same post won't appear in TV, Gallery, and your feed simultaneously
- Content filters for Politics, Sports, Current Events, and Entertainment — with free-text custom keyword blocking
- Filter settings sync to cloud via your AT Protocol repository

**Conversation Threads**
- Root-first navigation — replies always open from the top of the conversation
- Reddit-style collapsible branches with a circle `−` button
- Depth-colored left borders (8 cycling colors) for visual nesting clarity
- "Continue this thread →" at depth 4, with browser Back support
- Inline reply compose — write directly beneath the post you're replying to, keeping context visible

**Search**
- Full-text post and people search
- Advanced filters: sort by Latest or Top; media type chips (Image / Video / Link)
- Saved searches as **Channels** — sidebar links that persist across sessions and sync across devices
- Unread counts on each channel, checked once per login session
- "Load more" pagination on search results
- Paste a `bsky.app` URL directly into search to open any post or profile

**Notifications**
- Type-coded icons for likes, reposts, replies, mentions, and follows
- Unread badge clears and `updateSeen` fires on first visit

### Posting & Composing

**Rich Compose**
- Up to 4 images with per-image alt text; auto-resized to stay under 1 MB
- Video upload (MP4/WebM/MOV up to 50 MB / 180s) with daily limit tracking
- GIF picker powered by Klipy — GIFs posted as animated external embeds (animation preserved in Bsky Dreams, thumbnail card shown in native clients)
- Link preview with OG metadata, editable title/description, and uploaded thumbnail for rich native cards
- Post settings: reply gate and quote gate controls
- Live character count; 300-character limit

**Inline Rich Reply**
- Same image and GIF capabilities available when replying directly inside a thread
- Per-instance state — multiple inline boxes handled independently

**Quote Posts**
- Repost button opens an action sheet: plain repost or quote post
- Quote modal has full compose feature parity (images, GIF, link preview, post settings)

**@Mention Autocomplete**
- Debounced actor search while typing `@` — arrow-key navigation, click to select

### Media

**Lightbox**
- All images in a post browsable via carousel (arrows, dot indicators, keyboard ← →, touch swipe)
- Swipe-to-dismiss (vertical swipe ≥ 80px)
- Pinch-to-zoom recognized and separated from dismiss gesture

**Video Player**
- HLS.js streaming player (served locally, no CDN)
- Poster + click-to-activate prevents autoplay without gesture
- Muted by default; unmute button with visual state indicator
- Error fallback links to source

**GIF Playback**
- Tenor, Giphy, and Klipy GIFs rendered as animated `<img>` in-feed — no autoplay policy restrictions

### Bsky Dreams TV

A TikTok-style fullscreen video browsing mode for BlueSky video content.

- Topic input or open browsing (pulls from Following + Discover simultaneously)
- Two-slot slide system — outgoing and incoming video animate simultaneously
- Swipe up for next, swipe down or scroll up for previous
- Pause button; 2× speed while holding video
- Adult content filter (enabled by default)
- Watch history stored locally (max 1,000 entries, FIFO)
- Like and Repost from the overlay; "Open post" jumps to thread view

### Gallery

An image-first browsing view that pulls from Following and Discover in parallel.

- Deduplicates by URI and by blob CID (same image from different reposts shown once)
- Respects seen-post map — already-seen images are skipped
- Infinite scroll with a 400px pre-load zone
- Like, Repost, and thread navigation per card
- End-of-feed notification when all available images are loaded

### Profiles

- Full author profile with follow/unfollow toggle
- Author feed with "Load more" pagination
- Pull-to-refresh
- Three-dot report menu on every post card and profile header

### Cross-Device Sync (via AT Protocol)

Your preferences live in your own BlueSky repository — not on any Bsky Dreams server (there isn't one).

- Saved channels sync across devices
- Feed filters (categories + custom keywords) sync across devices
- Seen-post history syncs a 7-day rolling window of URIs across devices
- 2-second debounce on preference writes; seen-post sync fires immediately on tab close

### iOS PWA Support

- Add to Home Screen for standalone app experience
- `visibilitychange` listener proactively refreshes session tokens before expiry
- Silent re-login with saved credentials on foreground after suspension

### Settings

- Default feed tab (Following or Discover)
- Clear seen posts / TV watch history
- "Forget saved login" for shared devices
- Account info (handle + DID, read-only)

---

## Design

Bsky Dreams uses a **Neubrutalism + Memphis Design** hybrid — chosen because it signals clearly that this is *not* the default BlueSky interface, while being warm and a little playful rather than cold and corporate.

```
COLOR SYSTEM
────────────────────────────────────
Coral accent    #FF5C35   Buttons, active states, logo
Electric blue   #0047FF   Links, hashtags, mentions, chips
Lime            #B8E04A   Channel active state, accents
Near-black      #0A0A0A   ALL borders and shadows
Background      #FFFFFF   Clean white base

NEUBRUTALIST RULES
────────────────────────────────────
border-radius: 0          No rounded corners anywhere
border: 2-3px solid #0A0A0A    Every card and input
box-shadow: 3px 3px 0 #0A0A0A  Offset shadow on cards
Hover: translate(-2px,-2px)    Shadow grows
Active: translate(1px,1px)     Shadow shrinks

TYPOGRAPHY
────────────────────────────────────
Syne 700/800    Headings, nav, logo, tabs, buttons (uppercase)
Inter 400/600   Body text, UI labels
```

Memphis touches — diagonal stripe sidebars, dot-grid auth screen, geometric accent shapes — are kept subtle so they enhance rather than overwhelm.

---

## Running It

### Locally

No installation required.

```bash
# Option 1: open directly
open index.html

# Option 2: local server (useful if you hit any CORS issues with file:// protocol)
python3 -m http.server 8080
# then visit http://localhost:8080
```

### Deploying Your Own Copy

1. Fork this repository
2. Go to **Settings → Pages** in your fork
3. Set source to: `Deploy from a branch`, branch `main`, folder `/`
4. Your copy is live at `https://<your-username>.github.io/Bsky-Dreams`

No build step. No environment variables. No secrets. Push to `main` and it's deployed.

---

## Authentication

Bsky Dreams uses BlueSky **App Passwords** — a scoped credential that can be revoked independently from your main password.

1. Log into [bsky.app](https://bsky.app)
2. Go to **Settings → Privacy and Security → App Passwords**
3. Create a new password and label it "Bsky Dreams"
4. Enter your handle and that password in the Bsky Dreams login screen

Your credentials are stored only in your browser's `localStorage`. They are transmitted only to `bsky.social` — never to any intermediate server, never to GitHub, never to this project's maintainers.

---

## Tech Stack

| Layer | Choice | Why |
|---|---|---|
| Rendering | Vanilla HTML/CSS/JS | No build step; GitHub Pages compatible |
| Styling | Single `styles.css` with CSS custom properties | Mobile-first, themeable, no tooling needed |
| API | AT Protocol XRPC via `fetch` | No SDK required; BlueSky CORS is open |
| Auth | App Passwords in `localStorage` | Scoped, revocable, zero server needed |
| Video | HLS.js (served locally) | CSP `script-src 'self'`; no CDN dependency |
| Sync | AT Protocol user repo | Zero-cost; user-owned; no backend |
| Hosting | GitHub Pages | Free; automatic; no CI config |

---

## Project Files

```
/
├── index.html          — All HTML structure
├── css/
│   └── styles.css      — Single stylesheet; all design tokens in :root
├── js/
│   ├── app.js          — All application logic
│   ├── api.js          — All AT Protocol API calls (only file that calls fetch to bsky.social)
│   ├── auth.js         — Auth state management
│   ├── hls.min.js      — HLS.js v1.5.13 (served locally)
│   └── filter-words.json — Curated keyword lists for content filters
├── assets/             — Icons and static images
├── favicon.svg         — Coral square + white cloud favicon
├── manifest.json       — PWA manifest
├── CLAUDE.md           — Project context for Claude Code
├── DECISIONS.md        — Architecture and technology decision log
└── SCRATCHPAD.md       — Current milestone status and implementation notes
```

---

## Contributing

The architecture decisions that govern this project are documented in [DECISIONS.md](DECISIONS.md). The milestone log and current state are in [SCRATCHPAD.md](SCRATCHPAD.md).

Before contributing a feature, ask the same question the project asks internally: *does this make the user more curious, more thoughtful, or more connected — or does it make them more passive?*

Pull requests that add complexity without adding genuine value to the human using the app will be reconsidered. Pull requests that reduce friction for learning, discovery, or real conversation are very welcome.

---

## License

MIT — use it, fork it, improve it, share it.
