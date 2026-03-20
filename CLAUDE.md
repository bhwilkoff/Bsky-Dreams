# Bsky Dreams — Claude Code Project Context

## A Note on Why We Build

Before writing a single line of code, take a moment to understand the
orientation of this work. Every feature in this app is built in service of
human learning and growth — not to replace thinking, but to deepen it. At
each decision point, ask: Does this design invite the user to engage more
fully, think more critically, or connect more meaningfully? If a feature
makes a person more passive, reconsider it. If it opens a door to curiosity
or collaboration, prioritize it. The goal is never a slick product — it is a
tool that makes someone more human.

---

## Debugging and Diagnostic Philosophy

**Do not iterate blindly on behavior you cannot observe.** When a feature
does not work correctly and the root cause is not immediately clear from
reading the code, the first move is always diagnostics — not another
implementation attempt.

### Rule: Instrument before iterating

If a gesture, interaction, layout, or networking issue resists a first fix:

1. **Add console diagnostics immediately.** Print the values that matter:
   coordinates, sizes, state, what was found, what was nil. Ask the user to
   run and share the output. One round of real data is worth more than ten
   rounds of guessing.

2. **Design diagnostics to answer a specific question.** Before adding a
   print, write down what you expect to see vs. what would indicate the bug.
   "If `viewSize` matches `geo.size`, that theory is wrong. If `hitNode`
   returns nil for a tap that should hit, the math is wrong."

3. **Isolate layers.** For gesture issues: confirm the recognizer fires
   (`touchesBegan` print), then confirm the callback fires (print in
   `onTap`/`onPanChange`), then confirm the hit test result (print in
   `hitNode`). Don't assume all three layers work — verify each one.

4. **For iOS interaction bugs, add a temporary visual overlay** (a `Text`
   showing the last tap coordinate, size, or hit result) when the user
   cannot easily share a console. This surfaces diagnostic state directly
   on device without needing Xcode attached.

5. **Remove all diagnostics before considering a fix complete.**

### The lesson from 16 iterations on ConstellationView

Sixteen implementation attempts failed on the same tap/drag gesture problem
because each attempt changed the gesture infrastructure without first
verifying which layer was broken. A single round of `print` statements
revealed in one test that:
- The gesture recognizer WAS firing correctly
- `viewSize` and `geo.size` WERE identical
- `hitNode` WAS being called with the right coordinates
- But the closest node was 99pt away from where the user tapped

That data pointed immediately to a state/render mismatch: the physics
simulation was updating `nodes[idx].x/y` every frame but SwiftUI was not
re-rendering because `GraphNode.Equatable` compared only `id`. The visual
was frozen at initial positions; the hit test used simulation-updated
positions. One-line fix. None of the 16 earlier attempts touched this
because none had instrumented the right layer.

**Protocol for any future interaction/gesture bug:**
- Do not write a second implementation before adding diagnostics to the first.
- Share console output with the user after the first failed attempt, not the
  sixteenth.

---

## What This App Does

Bsky Dreams is a custom client for the BlueSky social network available as
both a **web app** and a **native iOS app**. It addresses BlueSky's friction
points around searchability, conversation clarity, media handling, and
analytics — while helping users break out of information bubbles through
truth/fact-checking visibility.

The two platforms are developed separately but maintain **feature parity**
as a goal. When adding a feature to one platform, note in SCRATCHPAD.md
whether the equivalent work is needed on the other.

---

## Platforms

### Feature Parity Model

Both platforms implement the same core feature set. Platform-specific
implementation choices are acceptable and expected (e.g., AVPlayer on iOS
vs. HLS.js on web; Keychain vs. localStorage for auth). What should stay
in sync:

- Which views/features exist
- Core UX flows (compose, thread navigation, reader modes)
- Design language: Neubrutalism + Memphis hybrid, same color tokens
- AT Protocol usage (same endpoints, same lexicon handling)

When a feature exists on one platform but not the other, it is tracked in
SCRATCHPAD.md under the per-platform status tables.

---

## Web App

### Tech Stack

- **Rendering:** Vanilla HTML/JS — no framework, no build step required
- **Styling:** Custom CSS (mobile-first, CSS custom properties for theming)
- **API:** BlueSky AT Protocol HTTP API (`https://bsky.social/xrpc/*`) via fetch
- **Auth:** App password stored in localStorage (user-provided, never sent to any backend other than bsky.social)
- **Deployment:** GitHub Pages static hosting (branch: main, root: /)

### Key Directories

- `/` — Root: index.html, CLAUDE.md, SCRATCHPAD.md, DECISIONS.md, README.md
- `/css/` — Stylesheets (styles.css is the single main stylesheet)
- `/js/` — JavaScript modules (app.js, api.js, auth.js, Readability.js, hls.min.js, d3.min.js)
- `/assets/` — Static assets (icons, images)

### How to Run Locally

```
open index.html
# or
python3 -m http.server 8080  # then visit http://localhost:8080
```

No build step required. The app runs as a static file.

### How to Deploy

1. Push changes to `main` branch
2. GitHub Pages serves from root of `main` automatically
3. Live URL: https://bskydreams.com

### Web Conventions

- All API calls go through `js/api.js` — never call `fetch` against bsky.social directly from other files
- Auth state (JWT session) is managed exclusively in `js/auth.js`
- CSS custom properties (variables) are defined in `:root` in `styles.css`
- Mobile-first: all media queries use `min-width` breakpoints
- Semantic HTML throughout — use `<article>`, `<section>`, `<nav>`, `<button>` appropriately
- No inline styles — all styling via CSS classes
- Error states must be user-visible (not just console logs)
- **Navigation**: All nav items live inside `#channels-sidebar`. On desktop (≥768px) the
  sidebar is always open; on mobile it is a slide-in drawer. Do not add nav items to the
  top bar.
- **Compose**: Link preview, GIF picker, and post-settings panels are toggled by toolbar
  buttons inside the compose form. State lives in `composeLinkEmbed`, `composeImages`, and
  the gate `<select>` elements. Clean up on every successful post and on `showView('compose')`.
- **IntersectionObserver cleanup**: Any `IntersectionObserver` created for a view must be
  disconnected in `showView()` when leaving that view to prevent memory leaks.

### Web Constraints

- GitHub Pages static deployment only — no server runtime, no Node.js
- Zero-cost tools only — no paid APIs, no paid hosting
- No build pipeline — everything must work as plain HTML/CSS/JS
- User credentials (app password) stored in localStorage only, never transmitted anywhere except bsky.social
- AT Protocol base URL: `https://bsky.social/xrpc/` for all API calls
- Chat API base URL: `https://api.bsky.chat/xrpc/` for `chat.bsky.convo.*` endpoints
- GIF provider: Klipy (`api.klipy.com`) — key hardcoded as `KLIPY_KEY` in `app.js`; GIFs posted as `app.bsky.embed.external` (CDN URL) to preserve animation
- Reader: CORS proxy chain codetabs.com → corsproxy.io → allorigins.win (18s timeout each)

### Do Not Touch (Web)

- `.git/` directory
- GitHub Pages deployment settings (configured in repo settings, branch: main)

---

## iOS App

### Tech Stack

- **Language / UI:** Swift 6, SwiftUI (`@Observable`, iOS 17+)
- **Local persistence:** SwiftData (SeenPost, SavedSearch, CachedPreferences)
- **Auth storage:** Keychain via Security framework (`kSecAttrAccessibleAfterFirstUnlock`)
- **API:** AT Protocol HTTP API via `URLSession` async/await — no SDK
- **Video:** AVPlayer + HLS (single shared instance per TV session)
- **Reader:** `URLSession` fetch (no CORS on iOS) + off-screen `WKWebView` for DOM extraction
- **Fonts:** Syne + Inter loaded from `Resources/Fonts/` (registered in Info.plist)
- **Deployment:** Xcode build → TestFlight / App Store (not yet submitted)

### Key Directories

- `BskyDreams-iOS/Bsky Dreams/` — All Swift source
  - `App/` — Entry point, app delegate config
  - `Auth/` — AuthManager, KeychainManager
  - `Models/` — Codable AT Protocol types (Post, Actor, Notification, etc.)
  - `Networking/` — ATProtocolClient (all API calls go here)
  - `Store/` — AppStore (@Observable global state, navigation path)
  - `Views/Feed/` — FeedView, InlineReplyView
  - `Views/Search/` — SearchView
  - `Views/Thread/` — ThreadView
  - `Views/Profile/` — ProfileView
  - `Views/Notifications/` — NotificationsView
  - `Views/DMs/` — DMsView, ChatView, NewConversationView
  - `Views/Gallery/` — GalleryView, GalleryCardView
  - `Views/TV/` — TVView, TVVideoCell, TVOverlayView, AVPlayerFillView
  - `Views/Reader/` — ReaderView, ArticleReaderSheet, ArticleWebView
  - `Views/Analytics/` — AnalyticsView
  - `Views/Constellation/` — ConstellationView
  - `Views/Compose/` — ComposeView
  - `Components/` — PostCardView, AvatarView, RichTextView, ImageGridView, etc.
  - `ContentView.swift` — RootView, MainAppView, SidebarView, DetailView, SettingsView

### How to Run Locally

Open `BskyDreams-iOS/BskyDreams.xcodeproj` in Xcode, select an iOS 17+
simulator or device, and press Run. No build scripts or dependencies to
install — all third-party code is absent (pure Apple frameworks only).

### iOS Conventions

- All AT Protocol API calls go through `ATProtocolClient.shared` — never call `URLSession` directly from views
- Auth state is owned exclusively by `AuthManager` — views read via `@Environment(AuthManager.self)`
- Global navigation state lives in `AppStore.navigationPath: NavigationPath` — push `PostDestination`, `ProfileDestination`, or `HashtagDestination`
- All views use `.toolbarBackground(.regularMaterial, for: .navigationBar)` + `.toolbarBackground(.visible, for: .navigationBar)` to prevent content scrolling behind the nav bar
- Avatars are **circular** everywhere (`.clipShape(.circle)`) — this is an intentional divergence from the web app's square neubrutalist style, chosen for native iOS ergonomics
- Post author header layout: name on top, @handle below (stacked VStack), tappable relative time badge at trailing edge
- Action bar "..." menu contains: Share, Open in Bluesky, Report — no standalone share button
- `RichTextView` uses `.system(size: 15)` as base font (not `.inter`) to ensure emoji and Unicode render correctly; the Inter font family does not include emoji glyphs
- `PostDestination.post` is optional — notification tap navigation provides only a URI
- TV: single shared `AVPlayer` instance; mute briefly on item swap to prevent audio pop; `containerRelativeFrame([.horizontal, .vertical])` for full-screen paging (not GeometryReader)
- Reader: strip external resources (img, script, link, iframe, video) from fetched HTML before loading into extractor WKWebView — prevents network churn and WEBP errors in the extractor process
- **Conversation view** (formerly "Thread view"): all user-visible text uses "Conversation" — toolbar title, loading indicator, and "Continue" link. Never use "Thread" in UI labels.
- **Share Extension → open containing app**: Traverse the UIResponder chain with `NSSelectorFromString("openURL:options:completionHandler:")` and pass `nil` for options — full implementation in DECISIONS.md. **Never retry:** `extensionContext?.open()` (returns `false`), deprecated `openURL:` selector (force-blocked), or any dictionary for options (crashes on `universalLinksOnly`). The Share Extension's Info.plist must declare `LSApplicationQueriesSchemes: [bskydreams]`.
- **Sidebar header**: use `VStack` with `.background(Color.nbWhite)` modifier — never a `ZStack` with a `Color` sibling. `Color` views as ZStack siblings are layout-greedy and cause the ZStack to expand to fill all available height. All children must have fixed heights.
- **Lightbox / fullScreenCover with data**: use `fullScreenCover(item:)` with an `Identifiable` carrier struct (e.g., `LightboxPresentation(images:startIndex:)`). Never use `fullScreenCover(isPresented:)` + separate `@State` arrays — SwiftUI may evaluate the content closure before batched state mutations are applied, producing stale/empty data.
- **Image grid cells**: always constrain both width AND height before `.clipped()`. `scaledToFill()` without a width constraint overflows column bounds in a `LazyVGrid`. Use `.frame(maxWidth: .infinity, minHeight: H, maxHeight: H)` then `.clipped()`.
- **Link cards** (`LinkCardView`): compact horizontal layout — 72pt square thumbnail on left, domain + title on right, fixed 72pt height. Tap opens `ArticleReaderSheet` in Readable mode (not `UIApplication.shared.open` to Safari).
- **`ArticleReaderSheet`**: `post` parameter is optional (`var post: PostView? = nil`) so it can be called from `LinkCardView` in feed cards (no post context available).
- **URLCache**: configured at app launch in `BskyDreamsApp.init()` — 100 MB memory / 500 MB disk — to persist `AsyncImage` and `URLSession` responses across sessions. Do not remove this configuration.
- **Seen posts**: mark via SwiftData `SeenPost` insert in `.onAppear` — applies to FeedView, GalleryView, and ReaderView. Always guard with `seenURIs.contains(post.uri)` before inserting to prevent duplicates.

### iOS Constraints

- iOS 17+ minimum deployment target
- No third-party Swift packages — use only Apple frameworks
- Keychain for all credential storage — never UserDefaults for secrets
- AT Protocol base URL: `https://bsky.social/xrpc/`
- Chat API base URL: `https://api.bsky.chat/xrpc/`
- GIF provider: Klipy — same as web app, same embed approach
- App password auth only (same as web) — AT Protocol OAuth not yet stable

---

## Shared: AT Protocol & Design

### API Endpoints (both platforms)

- All standard XRPC endpoints at `https://bsky.social/xrpc/`
- Chat endpoints at `https://api.bsky.chat/xrpc/` (`chat.bsky.convo.*`)
- Blob upload: `com.atproto.repo.uploadBlob` — raw binary POST, Content-Type set to file MIME type
- Blobs must be uploaded before `createPost` — AT Protocol requires CIDs at creation time
- AT Protocol facets use **byte offsets** (UTF-8), not character indices

### Design Tokens (both platforms)

```
Accent (coral):  #FF5C35   — buttons, active states, logo
Blue:            #0047FF   — links, mentions, hashtags, chips
Lime:            #B8E04A   — channel active, seen-post indicator
Near-black:      #0A0A0A   — ALL borders and shadows
Background:      #FFFFFF
Border/separator:#E0E0E0
```

Neubrutalist rules: `border-radius: 0`, `border: 2-3px solid #0A0A0A`,
`box-shadow: 3px 3px 0 #0A0A0A`. Hover grows shadow, active shrinks it.
Memphis accents: diagonal stripe in sidebar header, dot-grid on auth screen.

Typography: **Syne 700/800** for headings/nav/buttons (uppercase, tight tracking);
**Inter 400/600** for body/UI labels. On iOS, `RichTextView` post content uses
`.system(size:)` instead of Inter to ensure emoji fallback.

### Default accent color

iOS default accent: `#0047FF` (blue). Web default accent: `#FF5C35` (coral).
Never change the iOS default to coral — this is an intentional per-platform
choice documented in memory.

---

## Reference Repositories

When researching new features, API capabilities, or implementation patterns:

- **AT Protocol Python SDK + examples**: https://github.com/MarshalX/atproto
- **Awesome AT Protocol**: https://github.com/beeman/awesome-atproto
- **Awesome Bluesky**: https://github.com/fishttp/awesome-bluesky

When a feature request touches AT Protocol specifics (lexicons, record types,
feed generators, labelers, chat API), scan these repos first.

---

## Current State

See @SCRATCHPAD.md for per-platform feature status and planned work.
See @DECISIONS.md for all architecture decisions (web and iOS).
