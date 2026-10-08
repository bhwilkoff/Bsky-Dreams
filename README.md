# Bsky Dreams

**A Bluesky client built for people who want more from their Bluesky experience.**

> *Every feature in this app is built in service of human learning and growth —
> not to replace thinking or community, but to deepen it. The goal is never a slick
> product or an exhaustive feature list. It is a tool that helps make social media
> more human and collaborative.*

---

## What Is This?

Bsky Dreams is a custom client for the [BlueSky](https://bsky.app) social network, available as both a **web app** and a **native iOS app**. It was built to address the parts of BlueSky that feel unfinished: conversation depth, content discovery, media handling, search power, and cross-device persistence.

Both platforms share the same design language, the same AT Protocol integration, and the same core feature set — with platform-appropriate implementation choices.

| | |
|---|---|
| **Web app** | [bskydreams.com](https://bskydreams.com) — open in any browser, no install |
| **iOS app** | [Download on the App Store](https://apps.apple.com/us/app/bsky-dreams/id6760909675) — native SwiftUI, iPhone |

Both are free to use. Sign in with a [BlueSky App Password](https://bsky.app/settings/app-passwords) — your credentials never leave your device.

---

## Why Build Another Client?

Most social apps optimize for time-on-platform. Bsky Dreams optimizes for something different.

At every design decision point, the question is: *does this invite deeper engagement, more critical thinking, or more meaningful connection?* Features that make users passive get reconsidered. Features that open doors to curiosity or collaboration get prioritized.

This means:
- Conversations you can trace from root to leaf, with visual nesting depth
- Search powerful enough to actually find things — with media filters, sort options, and saveable channels
- A TV mode that surfaces video from across BlueSky's network rather than looping one algorithm
- A gallery that deduplicates content so you see more, not the same things repeated
- A Network Constellation that maps who talks to whom in any topic space
- Cross-device preferences synced through your *own* AT Protocol repository — no third-party account needed

---

## Platforms

### Web App

A zero-cost, zero-server, zero-dependency interface. Runs as a static file — no backend, no Node.js, no build pipeline, no tracking. Just HTML, CSS, and JavaScript talking directly to the AT Protocol.

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
│       └── localStorage + AT Protocol repo               │
│           (session, channels, seen posts, prefs)        │
└─────────────────────────────────────────────────────────┘
         ▲
         │  served from
┌────────┴───────────┐
│   GitHub Pages     │
│   (main branch)    │
└────────────────────┘
```

**Tech stack:**

| Layer | Choice |
|---|---|
| Rendering | Vanilla HTML/CSS/JS — no framework, no build step |
| Styling | Single `styles.css` with CSS custom properties |
| API | AT Protocol XRPC via `fetch` — no SDK |
| Auth | App Passwords stored in `localStorage` |
| Video | HLS.js served locally (CSP `script-src 'self'`) |
| Sync | AT Protocol user repo |
| Hosting | GitHub Pages — free, automatic, no CI config |

**Just want to use it?** Visit [bskydreams.com](https://bskydreams.com) — no install, no account beyond your BlueSky credentials.

**Running a local copy:**

```bash
open index.html
# or
python3 -m http.server 8080
```

No installation required. The only third-party services called at runtime are `bsky.social`, `api.bsky.chat`, `api.klipy.com` (GIF picker), and `api.allorigins.win` (OG link preview only).

**Deploying your own fork:**

1. Fork this repository
2. Go to **Settings → Pages** — set source to branch `main`, folder `/`
3. Your copy is live at `https://<your-username>.github.io/Bsky-Dreams`

---

### iOS App

A native SwiftUI app targeting iOS 17+. No third-party Swift packages — pure Apple frameworks.

```
BskyDreams-iOS/
├── Bsky Dreams/               ← All Swift source
│   ├── App/                   ← Entry point, app configuration
│   ├── Auth/                  ← AuthManager, KeychainManager (Keychain-backed session)
│   ├── Models/                ← Codable AT Protocol types
│   ├── Networking/            ← ATProtocolClient (all API calls)
│   ├── Store/                 ← AppStore (@Observable global state, NavigationPath)
│   ├── Views/                 ← Feed, Search, Thread, Profile, Notifications, DMs,
│   │                             Gallery, TV, Reader, Analytics, Constellation,
│   │                             Compose, Timeline
│   └── Components/            ← PostCardView, AvatarView, RichTextView, ImageGridView…
└── ConstellationTests/        ← SPM package — 43 unit tests for the physics simulation
```

**Tech stack:**

| Layer | Choice |
|---|---|
| Language / UI | Swift 6, SwiftUI (`@Observable`, iOS 17+) |
| Persistence | SwiftData (`SeenPost`, `SavedSearch`, `CachedPreferences`) |
| Auth | Keychain via Security framework |
| API | AT Protocol via `URLSession` async/await — no SDK |
| Video | AVPlayer + HLS (single shared instance per TV session) |
| Fonts | Syne + Inter (loaded from bundle, registered in Info.plist) |

**Just want to use it?** [Download on the App Store](https://apps.apple.com/us/app/bsky-dreams/id6760909675) — free, no account beyond your BlueSky credentials.

**Building from source:**

Open `BskyDreams-iOS/Bsky Dreams/Bsky Dreams.xcodeproj` in Xcode, select an iOS 17+ simulator or device, and press Run. No dependencies to install.

---

## Feature Parity

Both platforms implement the same core feature set. Platform-specific implementation differences are expected and acceptable; the user experience should be equivalent.

| Feature | Web | iOS |
|---|:---:|:---:|
| Auth (app password, session persistence) | ✅ | ✅ |
| Home feed — Following + Discover tabs | ✅ | ✅ |
| Hybrid feeds — multi-source merging + trending score | ✅ | ✅ |
| Seen-post deduplication with session bypass | ✅ | ✅ |
| Cross-device seen-post sync (AT Protocol repo) | ✅ | ✅ |
| NSFW content filtering | ✅ | ✅ |
| Compose — rich text, images, video, GIF, link preview | ✅ | ✅ |
| Post settings — threadgate / postgate | ✅ | ✅ |
| @mention autocomplete | ✅ | ✅ |
| Conversation view — depth-colored nesting | ✅ | ✅ |
| Inline reply compose | ✅ | ✅ |
| Quote post | ✅ | ✅ |
| Profile view — feed, follow/unfollow, mute/block, report | ✅ | ✅ |
| Search — full-text, advanced filters | ✅ | ✅ |
| Saved channels — persist and sync | ✅ | ✅ |
| Notifications — type-coded, unread badge, tap navigation | ✅ | ✅ |
| Direct messages + new conversation | ✅ | ✅ |
| Gallery — image card feed, lightbox | ✅ | ✅ |
| Lightbox — pinch-to-zoom, paging, download | ✅ | ✅ |
| Dark mode | ✅ | ✅ |
| TV — TikTok-style video feed, topic selector, 2× speed | ✅ | ✅ |
| Inline video fullscreen | — | ✅ |
| Reader — Direct / Readable / Archive modes | ✅ | ✅ |
| Stream — full-screen post slideshow | ✅ | ✅ |
| Network Constellation — force-graph visualization | ✅ | ✅ |
| Timeline scrubber — horizontal time-offset view | ✅ | ✅ |
| Settings — accent color, default feed, clear history | ✅ | ✅ |
| Share Extension (system share → open app) | — | ✅ |
| Profile interaction graph | ✅ | ⏳ |
| Analytics dashboard | ✅ | ⏳ |

---

## Features

### Reading & Discovery

**Home Feed** — Following and Discover tabs, infinite scroll, pull-to-refresh. Each tab merges multiple AT Protocol feeds in parallel and ranks by a trending score, surfacing the best content from your network without bubbling the same posts repeatedly. Seen-post deduplication ensures the same post doesn't appear across TV, Gallery, and the feed simultaneously. Content filters (Politics, Sports, Entertainment) with free-text keyword blocking sync to your AT Protocol repo.

**Conversations** — Root-first navigation; depth-colored left borders (8 cycling colors); "Continue this conversation →" at depth 4; inline reply compose that keeps context visible.

**Search** — Full-text posts and people search. Advanced filters: sort by Latest or Top, media type chips. Saved searches as **Channels** — sidebar links that persist across sessions and sync across devices. Paste any `bsky.app` URL to open a post or profile directly.

**Network Constellation** — Force-directed graph showing who connects to whom in any topic space. Tap to inspect, drag nodes, pinch to zoom, pan. Full physics simulation; search-seeded so the graph reflects your interest, not just your follow graph.

**Timeline Scrubber** — Horizontal timeline view of any search topic across configurable zoom levels (7 days → 20 minutes). Shows engagement density in lanes with connector lines.

### Posting & Composing

**Compose** — Up to 4 images with per-image alt text; video upload (MP4/WebM/MOV up to 50 MB); GIF picker (Klipy); link preview with OG metadata; reply gate and quote gate controls; live 300-character count; @mention autocomplete.

**Quote Posts** — Repost button opens an action sheet: plain repost or quote post with full compose feature parity.

### Media

**Gallery** — Image-first card feed pulling from Following + Discover simultaneously. Deduplicates by URI and blob CID. Like, Repost, and thread navigation per card.

**Lightbox** — Pinch-to-zoom anchored at your fingers (not screen center), single-finger pan when zoomed, swipe left/right to page through images in a set, swipe up/down to dismiss. Download button saves to camera roll (iOS) or browser download (web). Alt text overlay with scrollable content. Animated dot series indicator.

**TV** — Fullscreen TikTok-style video browsing. Merges multiple video feeds including Bluesky's official trending video source. Two-slot slide system for seamless transitions. 2× speed on hold. Adult content filter.

**Reader** — Article cards from links in your feed, including a verified news feed source. Three modes: Direct (in-app browser), Readable (extracted article text), Archive (Wayback Machine). Seen tracking filters articles you've already viewed in the home feed.

**Stream** — Full-screen post slideshow that auto-advances through your feed. Configurable duration, content filters, and background colors. Conversation overlay lets you read and reply without leaving the stream.

### Direct Messages

Conversation list, full chat view, new conversation with handle search. 30-second polling for new messages.

### Cross-Device Sync

Your preferences live in your own BlueSky repository — not on any Bsky Dreams server (there isn't one).

- Saved channels sync across devices
- Feed filters sync across devices
- Seen-post history — 7-day rolling window of URIs

### Dark Mode

Full dark mode on both platforms. Web: `html[data-theme="dark"]` CSS token overrides with accent-colored shadows. iOS: `DesignSystem.swift` adaptive color tokens with `preferredColorScheme` where needed.

---

## Design

Bsky Dreams uses a **Neubrutalism + Memphis Design** hybrid — a deliberate signal that this is not the default BlueSky interface, while being warm and a little playful rather than cold and corporate.

```
COLOR SYSTEM
────────────────────────────────────
Coral accent    #FF5C35   Buttons, active states, logo (web default)
Electric blue   #0047FF   Links, hashtags, mentions, chips (iOS default)
Lime            #B8E04A   Channel active state, seen-post indicator
Near-black      #0A0A0A   ALL borders and shadows (light mode)
Background      #FFFFFF   Clean white base

DARK MODE
────────────────────────────────────
Surface         #0D1421   Deep navy background
Surface alt     #1A2840   Cards and panels
Border          #405570   Subtle borders
Shadows         accent-colored (not black) — matches the playful energy

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

Memphis touches — diagonal stripe sidebars, dot-grid auth screen — are kept subtle so they enhance rather than overwhelm.

---

## Authentication

Bsky Dreams uses BlueSky **App Passwords** — a scoped credential independently revocable from your main password.

1. Log into [bsky.app](https://bsky.app)
2. Go to **Settings → Privacy and Security → App Passwords**
3. Create a new password labeled "Bsky Dreams"
4. Enter your handle and that password in the Bsky Dreams login screen

Your credentials are stored only in your browser's `localStorage` (web) or device Keychain (iOS). They are transmitted only to `bsky.social` — never to any intermediate server, never to GitHub, never to this project's maintainers.

---

## Project Files

```
/
├── index.html              — Web app HTML
├── css/styles.css          — Single stylesheet; all design tokens in :root
├── js/
│   ├── app.js              — All application logic
│   ├── api.js              — All AT Protocol API calls
│   ├── auth.js             — Auth state management
│   ├── hls.min.js          — HLS.js v1.5.13 (served locally, no CDN)
│   ├── d3.min.js           — D3.js v7 (Constellation view)
│   ├── Readability.js      — Mozilla Readability (Reader view)
│   └── filter-words.json   — Curated keyword lists for content filters
├── assets/
│   ├── klipy-powered-by.svg / klipy-watermark.svg  — Klipy attribution (in-app)
│   └── klipy-brand/        — Klipy brand guidelines and logo files
├── favicon.svg             — Coral square + white cloud
├── manifest.json           — PWA manifest
├── privacy/index.html      — Privacy policy page
├── docs/
│   └── shortcut-setup.md   — iOS Shortcuts guide for users
│
├── BskyDreams-iOS/         — Native iOS app
│   ├── Bsky Dreams/        — Xcode project + all Swift source
│   ├── Bsky Dreams.xctestplan
│   ├── ConstellationTests/ — SPM package: 43 unit tests for the physics engine
│   ├── screenshots-generator/  — Next.js tool for App Store screenshots
│   └── docs/               — iOS-specific reference docs
│       ├── APP_STORE_COPY.md
│       ├── APP_STORE_GUIDE.md
│       └── POST_BUTTON_ROUNDED_RECT_HISTORY.md
│
├── CLAUDE.md               — Project context and conventions for Claude Code
├── DECISIONS.md            — Architecture and technology decision log
└── SCRATCHPAD.md           — Feature parity status and implementation notes
```

---

## Contributing

The architecture decisions that govern this project are documented in [DECISIONS.md](DECISIONS.md). The milestone log and current state are in [SCRATCHPAD.md](SCRATCHPAD.md).

Before contributing a feature, ask the same question the project asks internally: *does this make the user more curious, more thoughtful, or more connected — or does it make them more passive?*

Pull requests that add complexity without adding genuine value will be reconsidered. Pull requests that reduce friction for learning, discovery, or real conversation are very welcome.

---

## License

MIT — use it, fork it, improve it, share it.
