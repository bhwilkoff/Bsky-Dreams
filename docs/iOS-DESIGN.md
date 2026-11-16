# Bsky Dreams — iOS Design Contract

This is the **binding** design doc for the iOS app. Before adding any view,
sheet, picker, navigation level, or feature surface, find the rule below that
justifies it. If no rule fits, the change needs a **new rule here first**
(and a note in DECISIONS.md) — fix the doc, then fix the feature.

The doc is the source of truth. Architectural rationale lives in `DECISIONS.md`;
this doc is the practical checklist.

---

## 1. Navigation & Information Architecture

1.0 **Navigation chrome is Apple's.** The shell is a system `TabView` with
`.sidebarAdaptable` (MainAppView): a tab bar on every iPhone — Home, Search,
Notifications, Messages, More — that the iPhone Duo moves into its vertical bar, and
the system's own collapsible sidebar listing every destination at regular width (the
open Duo). Screens use the system navigation bar: a title, Apple's back button, and
toolbar items that are each a `Label` (title + symbol). **Never a custom bar, drawer,
rail or button standing in for a system element** — custom chrome can't move into the
Duo's vertical bar or follow the system (owner, 2026-11-10).

1.1 **One navigation stack per tab.** Each tab owns a `NavigationStack` bound to
`store.pathBinding(tab)` (`store.paths`); the native TabView keeps each tab's place.
**The only exceptions are the open iPhone Duo's columns (§10.3):** the second column
(`store.secondaryPath`) and the detail pane (`store.detailPanePath`) each own a stack —
exactly what a split view's columns would own. Only `MainAppView.secondaryStack` and
`DetailPaneView` may create them.

1.2 **Destinations are `Hashable` structs.** Push `PostDestination(uri:post:)`,
`ProfileDestination(actor:)`, or `HashtagDestination(tag:)`. `PostDestination.post`
is optional so notification taps (URI-only) work without a prefetched `PostView`.

1.3 **Modal data via carrier struct.** Present data-carrying modals with
`fullScreenCover(item:)` / `sheet(item:)` using an `Identifiable` carrier
(e.g. `LightboxPresentation`, `StreamConversationPresentation`). **Never**
`fullScreenCover(isPresented:)` + separate `@State` arrays — SwiftUI may
evaluate the content closure before batched state mutations apply, producing
stale/empty data (Rule violated → empty lightbox).

1.4 **Conversation depth limit.** Conversation nesting stops at depth ≥ 4,
replaced with a "Continue this conversation →" link. Below that, indentation
overflows a 375px screen.

1.5 **System nav bar everywhere.** Every screen calls `nbNavBar(title:leading:trailing:)`,
which now configures the SYSTEM bar (NBNavBar.swift): `NBHamburger`/`NBBackButton` are
markers — tab roots get nothing (the tab bar/sidebar navigates), pushed screens get
Apple's back button, and a root that would go back (sheet, cover, Duo detail pane) gets
a system Close item. Trailing items are `Button(title, systemImage:)` / `Menu { } label:
{ Label(...) }` — never a styled custom view.

1.6 **More exists only at compact width.** At regular width the sidebar / Duo vertical
bar lists every place and the system's own "…" overflow covers what doesn't fit; a More
tab there is a duplicate overflow (owner, device).

1.7 **Destination order** (Home, Search, Notifications, Reader, then Gallery, TV,
Stream, Saved, Messages, Analytics, Constellation, Timeline, Channels, Settings). Reader and
Messages swapped (owner, 2026-11-10): Reader is a tab (in the Duo's vertical bar),
Messages a place (sidebar / overflow / More). Diverges from web's order — deliberate.
Tab bar = the first four + More (`AppTab.phoneTabs`); the rest are sidebar
places at regular width and rows in More at compact width (`AppTab.sidebarPlaces`).
Go anywhere with `store.select(_:)`, which knows where a destination lives.

---

## 2. The Four Required Feature States

Every surface that loads content (list, grid, search, sheet, feed) must define
behavior for **all four** states beyond the happy path. A surface missing any
of these is incomplete.

| State | When | Primitive | Notes |
|---|---|---|---|
| **Loading** (first load) | No content yet, request in flight | `NBSkeleton` / `NBSkeletonPostRow` | Shimmer; reduce-motion aware. Spinners only for short, non-list waits. |
| **Empty** (structural) | Request succeeded, genuinely nothing | `NBEmptyState` | "Nothing here yet" + optional CTA. NOT an error. |
| **Error** (attention) | A request just failed | `NBErrorBanner` (coral) | Retry + dismiss. Pair with `Haptics.error`. Never a bare `catch {}`. |
| **Offline** | Network unreachable | `NBOfflineBanner` (lime) | Driven by `NetworkMonitor`. Keep cached content visible; disable impossible retries. |

2.1 **Never swallow a `catch {}`.** Every catch surfaces a user-visible
`NBErrorBanner` (or equivalent) + `Haptics.error`. Console-only failures are
forbidden.

2.2 **Banner taxonomy is fixed** — do not invent new banner colors/meanings:
- Coral = error (`NBErrorBanner`)
- Lime = offline (`NBOfflineBanner`)
- Cyan/blue = first-run hint (`HintBanner`)

2.3 **First-run hints** use `HintsManager` + `HintBanner` — dismissible
permanently per-device, governed by the Settings "Show Tips" toggle and
"Reset All Tips". A hint is a one-time tip, categorically different from an
empty state or an error. Don't conflate them — it trains users to ignore both.

---

## 3. Color: Brand vs. Semantic

**Default accent is BLUE `#0047FF`.** Coral is NOT the iOS default — that is an
intentional per-platform divergence from web (web default is coral). Never
change the iOS default to coral.

| Token | Hex | Role |
|---|---|---|
| Accent (blue) | `#0047FF` | Default accent: button fills, active states, **launch screen background** |
| `Color.nbAccentLegible` | lightened accent in dark mode | Foreground accent: links, mentions, icon tints |
| Lime | `#B8E04A` | Active channel, seen-post indicator, **offline banner** |
| Coral | `#FF5C35` | **Error banner**, selectable accent (not default) |
| Near-black | `#0A0A0A` | ALL borders and shadows |
| Background | `#FFFFFF` | |

3.1 **Fill-accent vs. foreground-accent split.** Use the raw accent for fills;
use `Color.nbAccentLegible` for foreground (text/icon) elements. `#0047FF` is
too dark to read as text/icon on a dark background — using the same accent for
both makes links nearly invisible in dark mode.

3.2 **Semantic colors are reserved.** Lime and coral carry the offline/error
meanings above. Don't repurpose them for decoration.

---

## 4. Typography & Dynamic Type

4.1 **Syne 700/800** for headings/nav/buttons (uppercase, tight tracking);
**Inter 400/600** for body/UI labels. Post body content uses `.system(size:)`
(not Inter) so emoji and Unicode fall back correctly.

4.2 **Custom fonts MUST scale with Dynamic Type.** The `.syne()` and `.inter()`
helpers build fonts with `.custom(_, size:, relativeTo: .body)`. A custom font
without `relativeTo:` ignores the user's text-size setting entirely. Never use
bare `.custom(_, size:)`.

4.3 **System-font text scales too.** `.system(size:)` is a fixed size. Reading text
set in the system font (post bodies, names, bios, chat) uses `.scaledSystemFont(_:)`.
SF Symbol icons inside fixed-size controls may stay fixed.

---

## 5. Haptics Taxonomy

Use the `Haptics` enum's semantic cases — never ad-hoc
`UIImpactFeedbackGenerator`:

- `selection` — paging, toggles, tab/segment changes
- `light` / `medium` / `heavy` — discrete user actions, by weight
- `success` / `warning` / `error` — operation outcomes

`Haptics.error` always accompanies a surfaced `NBErrorBanner`.

**Storm breaker:** more than 6 haptics in a second is never intentional — `Haptics` drops
the rest for 5s and appends the call stack to `Documents/haptic-storm.log` (pull with
`devicectl device copy from --domain-type appDataContainer`). Never drive a haptic from
state that also changes on load or layout (`.sensoryFeedback(trigger:)` on a synced
value, a paging position in a hidden tab). Don't sprinkle
haptics where they add noise; pick the meaning, not the generator.

---

## 6. Accessibility (required, not optional)

6.1 **VoiceOver labels on every icon-only button** via `.accessibilityLabel`.
(Toolbar POST-style plain views also need `.accessibilityAddTraits(.isButton)`.)

6.2 **Dynamic Type** — see §4.2. Test at the largest accessibility text size;
dense rows should reflow, not clip.

6.3 **Reduce Motion** — honor it in *decorative* animations (Constellation /
Stream / TV transitions, skeleton shimmer). Do **NOT** disable the Constellation
physics simulation or gesture infrastructure — those are functional, not
decorative.

---

## 7. Image Loading

7.1 **Use `CachedImage` (not `AsyncImage`) in high-churn surfaces** (feed,
gallery, image grids). It downsamples off-main via ImageIO, shares an `NSCache`,
and re-checks the bound URL after the async load to prevent recycled-cell
wrong-image. `AsyncImage` decodes full-res on the main thread and shows the
wrong image in recycled `Lazy*` cells.

7.2 **Constrain BOTH dimensions before `.clipped()`.** In grids use
`.frame(maxWidth: .infinity, minHeight: H, maxHeight: H)` then `.clipped()`.
`scaledToFill()` without a width constraint overflows the column bounds.

7.3 `CachedImage.clearCache()` backs the Settings "Clear Image Cache" action.

---

## 8. Resilience

8.1 **SwiftData container falls back to in-memory** if the on-disk store fails
to open — launch must never crash on a corrupt/incompatible store.

8.2 **`NetworkMonitor`** (`@Observable`, `@Environment`-injected) is the single
source of connectivity truth. Offline = degrade gracefully, keep cache, show
`NBOfflineBanner`.

---

## 9. Build Gotcha (synchronized groups)

The Xcode project uses file-system-synchronized groups. **Brand-new standalone
`.swift` files are intermittently not picked up by the build** (confirmed via
`xcodebuild`, persists after clean + DerivedData wipe). Mitigation: **inline new
types into an already-compiled file** (`AppStore.swift`, `DesignSystem.swift`)
rather than creating a new `.swift` file. New `.xcassets` entries (colorsets,
imagesets) ARE picked up by `actool` regardless — new assets are safe.

---

## 10. iPhone Duo (foldable)

Apple's model, which this section follows: **iPhone Duo is an iPhone with two size
classes, not a third app.** The outer (closed) display is compact width; the inner
(open) display is regular width AND regular height in every orientation and pose
(flat, half-folded like a book, tabletop, standing). Never design per pose; never key
on device, idiom or orientation. Research + Archive Watch's experience:
DECISIONS.md "[iOS] iPhone Duo".

10.1 **Layout key.** `horizontalSizeClass == .regular && verticalSizeClass == .regular`
is the open-Duo layout. (A Pro Max on its side is regular width but compact height,
so it keeps the phone layout. The iPhone-only app runs phone-sized on iPad, so it
never sees regular/regular there.) Width-only decisions (e.g. Gallery's second
column) key on the view's MEASURED width, never the screen's.

10.2 **The sidebar is the system's.** At regular width (the open Duo) the
`.sidebarAdaptable` TabView shows Apple's sidebar with every destination; the person
shows/hides it with the system control, and may reorder/hide entries (system tab
customization, kept in `tabCustomization`). At compact width it is the tab bar.

10.3 **Columns — two views side by side.** The open Duo shows the PRIMARY column
(`selectedTab`, picked in the sidebar) and, on the right, either:
- **A second column (`store.secondaryTab`) showing ANY sidebar view** — Search beside
  Home, Following beside Trending, Gallery beside Reader, Notifications beside
  Messages… Chosen from **Right Side** (`NBColumnMenu`, a system `Menu` with a
  `Label`): always reachable — the leading item of whatever fills the right side (pane,
  empty state, second column), or a trailing item on full-display screens (TV, Stream…).
  Its first option, **Conversations**, is the default and turns the column back into the
  detail pane. **One Column** (`store.singleColumn`, remembered, never the default) removes
  the right side entirely: the primary takes the display, posts push in place as on the
  outer display, an open conversation moves onto the primary stack, and Right Side sits in
  the primary's trailing toolbar so the choice can be undone. Owner: "allow for a single
  column mode for when the screen is open (it shouldn't be the default, but it should
  still be possible)." (Build 55 put the picker only INSIDE the second column, so once closed a
  column could never be reopened — owner, device.) Remembered across launches; hidden (not lost) on the closed Duo.
  Each column has its OWN stack (`secondaryPath`): whatever you open in a column
  opens in that column. Home keeps a per-column feed (`store.secondaryFeedMode`,
  default Following) so two home feeds can differ.
- **Otherwise, a detail pane:** a post tapped in a reading surface of the primary
  column (`AppTab.hostsPostPane`: Home, Search, Notifications, Gallery, Reader,
  Analytics) opens its conversation beside the list; a chat tapped in Messages opens
  there too, and a profile (`store.openProfile` — e.g. a follow notification, an author
  tap) opens there as well. Only when the right side is unoccupied (no second view). The list keeps its scroll position and marks the open
  post (accent outline, `.isSelected`). At the pane's root `NBBackButton` is ✕.
  **Continuity:** closing the Duo pushes the open conversation onto the main stack.
- **Routing rule:** views never append to a path themselves — they call
  `store.openPost(…, column:)` / `store.openChat(_:column:)` / `store.push(_:column:)`
  with their `@Environment(\.navColumn)`. One-shot handoffs from the sidebar or a
  notification (`pending*`) are consumed only by the primary column.
- **Container: `FoldSplitLayout`** (ContentView.swift) — ONE Layout in every state
  (closed, open, rotated, either Layout choice) with the primary always in the same
  slot, so opening/closing the Duo never rebuilds the column (switching containers did:
  every open/close reloaded the feed — owner, device). Halves; when folded, the halves
  meet at the fold's edges from Apple's `reservedRegions(kind: .division)` (the API for
  custom layouts), matching what ArrangementView measured on device.
- **The left column cancels the vertical bar's inset.** On the Duo the bar's 84pt
  trailing inset is handed to EVERY screen's hosting controller under the tab view
  (device log: navigation controller 0, its screen 84) — so the left column's content was
  350pt in a 434pt column, under ArrangementView too. SwiftUI `ignoresSafeArea` can't
  remove it; `BarInsetCanceller` offsets it with `additionalSafeAreaInsets` on each
  screen of the primary column (root + every destination in `.withAppDestinations`, via
  `\.barInsetEdges`). Trailing when side by side, bottom when stacked; none without a
  right side.
- **Before 2026-11-10 it was Apple's `ArrangementView`** (`.split`, BOTH axes;
  `splitArrangementLayoutRatio` 0.34 min / 0.5 ideal on each axis) — side by side when
  the fold runs top to bottom (book), stacked top/bottom when the device is rotated and
  the fold runs across; in book pose the divider lands on the fold (device-verified).
  Never restrict to `.axes(.horizontal)`: rotated, the system then DROPS the right side
  rather than straddle the fold (device-verified 2026-11-10).
- **Rotated layout is the person's choice.** When the columns are taller than wide, Right
  Side shows a **Layout** section: Top & Bottom (default, `ArrangementView` along the
  fold) or Side by Side (`store.columnsSideBySideWhenTall`, remembered) — a plain HStack
  of the same two panes, since `ArrangementView` won't split across the fold. Owner:
  "I'd also like to be able to do side by side in the vertical layout." With nothing open the right side is a
  system-style empty state ("Tap a post and its conversation opens here"), as in Mail.
- **Shared destinations:** every stack registers the same destinations via
  `.withAppDestinations(myDid:)`.

10.4 **No screen references.** Never `UIScreen.main` (ambiguous on two displays,
slated for deprecation) — measure the container (`onGeometryChange`) and use
`@Environment(\.displayScale)`.

10.4b **Full-screen experiences own the display.** `AppTab.isFullScreenExperience`
(Stream, Constellation, Timeline): never offered as a right-side view, and with it in the left column the right
side and the Right Side menu are hidden; a chosen second view returns when you leave.
Owner: "Stream is a full screen experience" … "Timeline and Constellation are also full
screen experiences." TV is not on the list — it has its own full-screen toggle (§10.13).

10.5 **Stream is a screen saver you can step into.** The inner display ignores interface
orientation, so on the open Duo Stream starts at once — no "turn your phone" step — and
rotation signals don't dismiss it. Owner (2026-11-16): "the ultimate screen saver for the
iPhone Duo … great screensaver viewing AND great interactions for when you see a post
you'd like to dig into more." Two modes on one surface:
- **Watching (calm).** One post at a time as a pull quote: the largest type that fits
  (`fittedFontSize`; floor 19pt scaled with Dynamic Type), lines revealed one by one
  (`LineReveal`, a `TextRenderer`), who said it beneath, quiet counts. Behind it a slow
  `MeshGradient` of the post's own colors (sampled 3×3 from its image or the author's
  avatar). A clock (setting) and a hairline of progress — nothing else. Scenes dissolve
  through a blur. After a post with replies, a **conversation beat**: the post small
  beside "What people are saying" (top replies by likes) and Join the Conversation.
- **Interacting (tap).** The post eases back (a visual scale, so type isn't refitted);
  its actions appear in place of the quiet counts (reply, repost, like, save, share,
  Conversation — labels then counts drop to fit, never truncate); a **filmstrip** of recent
  and upcoming posts (tap to go back to one you just missed); prev / play-pause (progress
  ring) / next. Controls auto-hide after 6s of no use.
- **Gestures:** double-tap likes (heart burst); a finger on the screen holds the post;
  swipe left/right changes it; swipe up opens its conversation.
- **Digging in never loses your place.** Words / reply cards / Conversation → the
  conversation BESIDE the post (`FoldSplitLayout`, `.explore` NavColumn +
  `store.explorePath`); author → profile there, long-press → stream that person; a
  hashtag → stream that tag; image → lightbox; link → article + discussion (§10.12). Save
  keeps a post for later; **Saved** is a source. Anything open holds the clock; Resume
  continues the same post; the panel follows if you move to another post.
- **One post = one scene; media is whole** (fit, framed, prefetched with its colors and
  replies). Layout from the measured canvas: wide → media beside the words; tall → above.
  Folded, splits land on the fold (`FoldGeometry`); words alone become a two-page spread.
- **Looks:** Ambient (default — dark, colored by each post), Bold (brand palette), Paper
  (light); typeface Editorial (New York) or Modern (SF) — system fonts for emoji.
- **Liquid Glass** for every floating control (`glassEffect`, `GlassEffectContainer`;
  material below iOS 26). Status bar and home indicator hidden. Paused under VoiceOver;
  next/previous/pause/show controls are accessibility actions.
- **The stream outlives the screen.** Session state lives in `StreamSession.shared` and
  the player is presented by MainAppView (`StreamView(role: .player)`), never by the
  Stream screen: closing the Duo swaps the sidebar for the tab bar, which rebuilds the
  Stream screen inside More, and a cover owned by it was dismissed with it (owner,
  device). Rule for any full-screen experience that must survive open/close: present it
  from the root, keep its state out of the view.
- Seen posts are skipped only in Discover/Following; a topic, a person or Saved shows
  everything asked for. Setup offers Resume / Start Over, a live preview of the look.

10.6 **Art under the strip.** With the iOS 27.1 SDK, the status bar and system bars
sit in a strip down the trailing edge (closed Duo; inner display in landscape).
Full-bleed art that reaches that edge uses `.nbExtendsUnderBars()`
(`backgroundExtensionEffect`, iOS 26+). Controls stay inside the safe area; custom
bars (`NBNavBar`, `FeedNavBar`) sit inside it already.
The system bars avoid the display's rounded corners and the status bar on their own.

10.9 **Narrow and wide columns.** A Duo column can be ~310pt (portrait, two
columns) or ~860pt (landscape, sidebar hidden). Both must read well:
- **Counts are compact and never wrap:** `nbCompactCount` (398 · 1.2K · 12K · 1.3M)
  with `.lineLimit(1).fixedSize()`; VoiceOver keeps the exact number. (Build 52 wrapped
  "398" onto two lines.)
- **Segmented toggles size their labels together** from the measured width — never a
  per-label `minimumScaleFactor` that shrinks only the longest word ("CONVERSATIONS").
  Icons drop out before the text gets small.
- **Reading lists cap at ~680pt and centre** (`.nbReadableWidth()`) — long lines and
  giant images in a wide column are as hard to read as cramped ones in a narrow one.

10.10 **The vertical bar is the system's.** With the iOS 27.1+ SDK the Duo puts the
status bar in a vertical strip down one edge (closed Duo; inner display in landscape)
and moves the tab bar and toolbar items into it — automatically, because they are the
system TabView and system toolbar items (§1.0, §1.5). Nothing of ours is drawn there.
(Build 54's custom `NBStripRail` was removed: it drew into the content, not the strip.)

10.11 **Reply in context.** A Reply with no reply box of its own opens the post's
conversation with the reply box already open (`store.openReply(to:column:)` →
`pendingReplyURI`, consumed by ThreadView). On the open Duo, Home's Reply does the same
instead of its inline box, so the conversation opens BESIDE the list: the person reads
what others have said before adding to it. (Before this, Reply did nothing outside
Home, Profile and a conversation.)

10.12 **An article beside its discussion.** On the open Duo, an article (Reader card or a
post's link card) opens full screen as an `ArrangementView` split: the article on one
page, the sharing post's conversation on the other. A link card learns its post from
`\.embedPost` (set by PostCardView). The discussion is a `.companion` column with its
own stack (`store.companionPath`); the article side owns Close.

10.13 **TV pairs the video with its conversation.** On the open Duo with TV on its own
(no second column), the video and the current video's conversation split the display:
side by side when TV is wider than tall (book pose), video above conversation when it
is taller than wide (rotated, tabletop — the replies land on the flat half). One
layout in every pose; only the axis follows the measured shape (§10.1). The
conversation follows the video on screen. It has NO stack of its own — TV is
already inside its tab's stack, and a NavigationStack nested in a NavigationStack is
ignored (device: its title surfaced in TV's hidden bar). Opening a reply or profile
from it pushes onto TV's stack, full width; Back returns to the video. Rule: a
companion stack is only valid as a SIBLING of the content's stack (the article cover),
never inside it. **Full screen is the person's choice:** a FULL SCREEN / CONVERSATION
button (top-right of the video, open Duo only; `store.tvFullScreen`, remembered) gives
the video the whole display — no conversation and no right side. Full screen, the
video's overlay buttons pad by the window's trailing inset so the vertical bar doesn't
cover them. Owner: "You should be able to do TV as a full screen experience, but I
really like the side-by-side view of it as well."

10.14 **Timeline takes the whole display** (like Constellation; not a pane host). At
≥700pt measured width: 220×100 cards with readable type, controls in one row, and a
tapped card opens in a bottom panel (full post + Open Conversation) so the timeline
keeps its place. Narrower, the phone timeline is unchanged (tap → conversation).

10.7 **Build with the newest released SDK.** The edge-to-edge Duo layout needs the
iOS 27.1 SDK; older SDKs run "boxed". CI picks the newest non-beta Xcode on the
`xcode-27` image and logs the SDK.

10.8 **Deliberately NOT adopted (yet)** — revisit on a physical Duo:
- `ReservedRegion` / `reservedRegions(kind:)` for custom views — nothing custom needs
  it now that the split is `ArrangementView` and the chrome is the system's.
- Hinge-angle effects (`onHingeChange`) — Apple: effects only, never layout; none
  worth adding.
- Tabletop-specific TV/Stream layout — Apple says use the same controls in every
  pose; revisit with the device.
- A second window on the inner display — `AppStore` is app-global (one navigation
  path, one compose sheet), so two windows would mirror each other. Needs per-scene
  state first.
- Duo screenshots (1398×2034 outer / 2007×2853 inner) — required from April 2027
  for iOS 27.1-SDK builds; make them in Xcode 27.1's Device Hub.

---

## 11. Design Language 2 (learned from Stream, 2026-11-16)

Owner: "take all that you have learned from this redesign for the Stream interface and
make updates across all surfaces for the far more sophisticated design language and
interface elements … especially for the iPhone Duo screen size and functionality."
The shared pieces live at the end of `DesignSystem.swift`.

11.1 **Post text is reading.** Every post body uses `.nbReadingFont(base)`: the reading
typeface from Settings → Reading (Editorial = New York, default; Modern = SF; system
fonts so emoji render), scaled with Dynamic Type AND with the column it sits in
(`\.nbColumnWidth`, measured by `.nbColumnWidthReader()` on each Duo column, the
explore panel, two-page halves): +2pt at ≥560pt, +4pt at ≥760pt. Headlines (Reader
titles, profile names, pull quotes) use `nbReadingFace`. The article reader's HTML uses
the same face (`ui-serif`). UI chrome stays Syne/Inter.

11.2 **Color from content.** Where a surface is ABOUT one thing, its background is that
thing's own palette: `NBContentField(url:tone:)` samples 3×3 colors from an avatar or
image and drifts them slowly as a `MeshGradient` (`.pale` in light mode, `.deep` in dark
or over media; still under Reduce Motion). Used by: profile headers, the conversation's
post page, the lightbox, the Duo's empty right pane, TV/Stream heroes. Never behind a
scrolling list of many things.

11.3 **Glass for what floats.** Controls over content (video, photos, Stream) are
Liquid Glass: `.nbGlass(in:)`, `NBGlassButton`, `NBGlassCapsule`, grouped in
`NBGlassGroup` (iOS 26+; material fallback). Content keeps its neubrutalist frames and
shadows; glass is never a card background.

11.4 **Two pages when there's room.** At ≥760pt measured width (One Column on the open
Duo, a wide pushed screen) a view about one thing becomes a spread, split on the fold
when folded (`FoldGeometry`):
- **Conversation:** the post (and what it answers) at feature size on its author's
  colors | "What people are saying".
- **Profile:** who they are on their colors | what they've posted.
Each page sizes its reading type to its own width.

11.5 **The right pane invites.** With nothing open, the Duo's right side is
`RightPanePlaceholder`: a color field and one sentence about what goes there. Not an
uppercase "NOTHING".

11.6 **Keep it, stream it.** `SavedPosts` (device-local URIs) is app-wide: Save for Later
in every post's ••• menu, TV and Stream; the **Saved** place lists them. "Stream this"
is offered wherever there's a natural set: a profile (Stream tool), a post's author
(menu), a search or #hashtag (toolbar), Saved (toolbar). `StreamSession.shared.play(_:)`
starts it from anywhere; the player is presented at the root (§10.5).

11.7 **Lines arrive, things dissolve.** `NBLineReveal` (a `TextRenderer`) and
`.nbBlurDissolve` are for a single featured thing changing (Stream), never for lists.

11.8 **Words.** Every string on screen is in Ben's voice (see the pre-ship checklist).

---

## 12. Editorial Native (2026-11-16)

Owner, after §11 shipped beside the old chrome: "the harsh difference between the old and
new across columns is pretty glaring … update all of the interface elements for this new
approach to editorial and modern interface elements that take full advantage of the
latest APIs and design patterns on iOS." Chosen direction (owner): **editorial native**:
neubrutalism retires on iOS; the brand lives in the blue accent, the cloud mark, color
from content and the reading face. Web keeps neubrutalism for now (a deliberate
divergence, like circular avatars).

12.1 **Type is San Francisco text styles.** `Font.inter(size)` maps to the nearest system
text style (Dynamic Type for free); `Font.syne(size)` is SF **Expanded** at that style,
for small section labels and the few wide caps that remain. Post text: §11.1. Nav
titles: New York semibold (UINavigationBar appearance), title case (`nbTitleCase`, so
"CONVERSATION" reads "Conversation").

12.2 **Containers are soft.** `nbBorder()` = continuous 14pt corners (`NBMetrics.corner`)
that clip their content + a hairline (`Color.nbBorder`, or a passed tint at 45%).
`nbShadow()` draws nothing. No hard offset shadows, no 2–3pt black outlines, no square
corners on containers.

12.3 **Posts are rows.** `PostCardView` is an editorial row: no box, 14pt insets, a
hairline under it, a rounded depth rule for replies, an accent wash (not an outline)
for the post open in the Duo pane. Galleries and Reader keep cards (a picture or
article is a thing), now soft.

12.4 **System controls.** Segmented choices are `Picker(.segmented)` (feed, search
mode/sort, typeface, Stream pace/content); Settings is a `Form` with `Picker`,
`Toggle`, `LabeledContent`, `Link`; empty states are `ContentUnavailableView`
(`NBEmptyState` wraps it, sentence case); text fields are filled rounded fields; primary
actions are filled capsules or accent buttons; floating controls are glass (§11.3).

12.5 **Media is framed softly**: rounded 18pt corners and a soft shadow (Stream), not
a black frame with an offset block.

12.6 **Retired**: `DiagonalStripeBackground` (renders a pale content field now),
the neubrutalist button press travel, uppercase empty-state titles.

---

## 13. Bsky Dreams personality on native controls (2026-11-16)

Owner: "the app has lost a lot of its personality … The whole point of having Bsky Dreams
look different … is to differentiate it from the default app." Then, on scattered
decorative shapes: "It is AI slop. We need an actual design pattern." The brand is a
SYSTEM with rules, not decoration. Owner chose **magazine typography**.

13.1 **Magazine typography.** Personality is typographic. `NBMasthead` = `NBKicker`
(accent rule + Syne small caps: the place, and the mode) + Syne headline (≤ 6 words) +
serif deck (one sentence, Ben's voice). One per screen, at the top of the content,
scrolling away with it; never sticky. Used on Home (per feed), Reader, Gallery,
Notifications, Saved; the Duo's empty pane is a cover built from the same parts.
Counts that matter are `NBStat` (big Syne numeral + small caps label): profile stats,
the conversation's replies/reposts/likes.

13.2 **Syne is the voice; SF is the interface.** `Font.syne` is Syne again (scaled to the
nearest text style) for kickers, headlines, numerals and buttons. System controls
(pickers, Form, search) stay SF.

13.3 **The signature lift.** `nbShadow()` is the old hard offset shadow, rounded and tinted
with the accent (22% light / 38% dark) instead of black. Post cards, gallery and reader
cards, primary buttons.

13.4 **Posts are cards again** (§12.3 superseded): each post a white card on the paper,
14pt corners, hairline, signature lift, ~14pt between cards, so posts are easy to tell
apart. The post open in the Duo pane gets an accent outline.

13.5 **Accent-tinted paper.** `Color.nbBackground` is a 6% (dark: 7%) wash of the
person's accent, applied to every navigation screen with `.nbPaper()`
(`containerBackground(for: .navigation)`).

13.6 **Columns blend.** Where a content field meets paper (the empty pane, two-page
conversation and profile), `nbBlendsIntoPaper(edge:)` softens the field toward the paper
and fades it out along the shared edge; no hard divider there.

13.9 **Two rules, two meanings** (owner: "if they represent different things, I don't want
them to look identical"). Both come from the accent rule (the kicker's dash):
- **Column gutter** (`NBColumnGutter`), between two independent views: a 1pt accent rule
  (35%) that fades in and out along its length, capped by a solid 3×18 accent dash level
  with the masthead kicker. None where a content field blends into paper (§13.6).
- **List rule** (`NBListRule`), between items in a sequence: a dotted rule, inset to
  where the text starts. Unread items carry `NBUnreadMark` (the dash, upright, at the
  leading edge) instead of a tinted row.
Never `Divider()` or a plain gray line between columns or list items.

13.10 **Paper reaches UIKit.** Each screen's hosting controller and its navigation
controller also get the paper color (set in `BarInsetCanceller`): otherwise their default
white flashed and redrew while the Duo's inset was applied (owner, Reader).

13.11 **Three type roles, one job each** (owner: "at least four different competing fonts
and interface elements across the full screen"):
- **Display = Syne**: screen titles (UINavigationBar appearance), kickers, masthead
  headlines, big numerals.
- **Reading = the reading face** (Editorial/Modern, §11.1): posts, decks, articles.
- **Interface = SF**: lists, controls, metadata, everything else.
No fourth face. A screen with a masthead shows no bar title until the masthead scrolls
away (`NBMasthead(onVisibleChange:)` via `onScrollVisibilityChange`), so the screen's
name is never shown twice and never missing. Messages has a masthead like every place.

13.7 **Never**: scattered or "confetti" shapes, decoration without a job, graphics on
reading content.

13.8 **Why chips** say something new or nothing: "Reposted by", "Followed by … you
know", "Popular in your network", "Matches your interest in #…". Never "From someone
you follow" (that's what Home is) or "Active conversation · N replies" (the count is
under the post).

---

## Anti-Patterns (never)

- ❌ Bare `catch {}` that only logs — always surface `NBErrorBanner` + `Haptics.error`.
- ❌ `fullScreenCover(isPresented:)` + separate `@State` data arrays — use `item:`.
- ❌ Bare `.custom(_, size:)` custom fonts — always `relativeTo:`.
- ❌ Same accent for fills and dark-mode foreground — use `nbAccentLegible` for foreground.
- ❌ Coral as the iOS default accent — default is blue `#0047FF`.
- ❌ `AsyncImage` in feed/gallery grids — use `CachedImage`.
- ❌ `scaledToFill()` without a width constraint in a grid cell.
- ❌ Ad-hoc `UIImpactFeedbackGenerator` — use the `Haptics` taxonomy.
- ❌ Disabling Constellation physics/gestures for Reduce Motion (decorative only).
- ❌ A new standalone `.swift` file when the type can be inlined into a compiled file.
- ❌ A custom bar, drawer, rail or styled button in place of the system TabView, sidebar, navigation bar, back button or toolbar items (§1.0).
- ❌ A toolbar item that isn't a `Label` (title + symbol) — it can't move into the Duo's vertical bar.
- ❌ A `NavigationStack` outside a tab, the Duo's second column or detail pane (§1.1, §10.3).
- ❌ `store.navigationPath.append(…)` in a view — use `store.openPost` / `openChat` / `push` with `\.navColumn` (§10.3).
- ❌ `UIScreen.main` anywhere — measure the container; use `displayScale` (§10.4).
- ❌ Branching on device / idiom / orientation for layout — size classes and measured width only (§10.1).
- ❌ Black hard offset shadows, thick black outlines or square-cornered containers on iOS (§12.2); the lift is accent-tinted and rounded (§13.3).
- ❌ Decorative shapes or "confetti" with no job (§13.7).
- ❌ A hand-rolled segmented toggle where `Picker(.segmented)` fits (§12.4).
- ❌ Post text in Inter or a fixed `.system(size:)` — use `.nbReadingFont` (§11.1).
- ❌ A flat fill or black behind a surface about one thing, when its own colors are available (§11.2).
- ❌ Styled squares/pills floating over video or photos — glass (§11.3).
- ❌ A full-screen experience presented by a view that can be rebuilt (a tab's screen) — present at the root (§10.5).

---

## Pre-Ship Checklist

For any new/changed feature surface:

- [ ] All four states defined (loading skeleton, empty, error banner, offline banner).
- [ ] No swallowed `catch {}` — every failure surfaces a banner + haptic.
- [ ] Icon-only buttons have VoiceOver labels.
- [ ] Custom fonts scale with Dynamic Type (`relativeTo:`); tested at largest size.
- [ ] Dark mode: links/icons use `nbAccentLegible` and are legible.
- [ ] Decorative animations honor Reduce Motion (functional ones do not).
- [ ] Images use `CachedImage`; grid cells constrain both dims before `.clipped()`.
- [ ] Modals carry data via `item:` + `Identifiable` carrier.
- [ ] Haptics use the semantic taxonomy.
- [ ] Default accent is blue, not coral.
- [ ] New types inlined into compiled files (synchronized-group gotcha).
- [ ] A Reply button always does something (local box, or `openReply`) (§10.11).
- [ ] Open iPhone Duo (regular/regular): works as a primary AND a second column, at ~310pt AND ~860pt wide (§10.9); opens go through `openPost`/`openChat`/`push` with `\.navColumn`; any shared store state it reads is per-column or primary-only (§10).
- [ ] Post text uses `.nbReadingFont`; floating controls are glass; wide (≥760pt) views about one thing are two pages (§11).
- [ ] Feature serves human learning/agency (see CLAUDE.md "Why We Build").
- [ ] Every word on screen is in Ben's voice (`LearningIsChange/BEN.md`): plain, a little wry, the why in one clause, "folks", no em dashes (owner, 2026-11-16).
