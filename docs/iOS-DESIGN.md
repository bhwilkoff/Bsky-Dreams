# Bsky Dreams — iOS Design Contract

This is the **binding** design doc for the iOS app. Before adding any view,
sheet, picker, navigation level, or feature surface, find the rule below that
justifies it. If no rule fits, the change needs a **new rule here first**
(and a note in DECISIONS.md) — fix the doc, then fix the feature.

The doc is the source of truth. Architectural rationale lives in `DECISIONS.md`;
this doc is the practical checklist.

---

## 1. Navigation & Information Architecture

1.1 **One navigation stack.** All push navigation goes through the single
`NavigationStack(path: store.navigationPath)` at the app root. Never nest a
second `NavigationStack` for push flows (DMs proved `NavigationSplitView`
collapses poorly on compact iPhone — it was replaced with `NavigationStack` +
`NavigationLink`).
**One exception:** the iPhone Duo detail pane (§10.3) is the detail column of a
list/detail split and owns a small stack (`store.detailPanePath`) for drilling
into replies — exactly what `NavigationSplitView`'s detail column would own.
Only `DetailPaneView` may create it.

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

1.5 **Translucent nav bar everywhere.** Every view applies
`.toolbarBackground(.regularMaterial, for: .navigationBar)` +
`.toolbarBackground(.visible, for: .navigationBar)` so content never scrolls
unreadably behind the bar.

1.6 **All nav lives in the sidebar order** (Post, Home, Search, Notifications,
Messages, Gallery, TV, Stream, Reader, Analytics, Constellation, Timeline).
Match this order with web.

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

`Haptics.error` always accompanies a surfaced `NBErrorBanner`. Don't sprinkle
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

10.2 **Persistent sidebar.** On the open Duo the sidebar is an always-visible 260pt
column (web desktop parity: the web sidebar is always open ≥768px); the hamburger
hides (`\.sidebarIsPersistent`). Everywhere else it is the slide-in drawer, unchanged.

10.3 **List / detail — conversations and chats open BESIDE the list.** On the open Duo,
a post tapped in a reading surface (`AppTab.hostsPostPane`: Home, Search,
Notifications, Gallery, Reader, Analytics, Timeline) opens its conversation in a
right-hand detail pane; a chat tapped in Messages opens in the pane too. The list
keeps its scroll position and marks the open post (accent outline, `.isSelected`).
- **Views never append `PostDestination` / `Conversation` themselves** — they call
  `store.openPost(uri:post:fromDetailPane:)` / `store.openChat(_:)`, which push onto
  the main stack whenever the pane is off. A tap INSIDE the pane drills down within
  it (`\.isDetailPane`).
- At the pane's root, `NBBackButton` becomes a close (✕) button.
- **Continuity:** closing the Duo with a conversation open pushes it onto the main
  stack, so the outer display continues where the inner one was.
- **Geometry.** Landscape inner (~950pt): sidebar + two equal panes. Portrait inner
  (~670pt): while a conversation is open the sidebar returns to the drawer and the two
  panes split the screen exactly in half — on the center line, where the fold runs
  when the device is half-open like a book, so neither pane bends across it.
- TV, Stream, Constellation and Settings push as before (full-screen or tool surfaces).

10.4 **No screen references.** Never `UIScreen.main` (ambiguous on two displays,
slated for deprecation) — measure the container (`onGeometryChange`) and use
`@Environment(\.displayScale)`.

10.5 **Stream starts flat.** The inner display ignores interface orientation, so on
the open Duo Stream starts at once — no "turn your phone" step — and rotation
signals don't dismiss it.

10.6 **Art under the strip.** With the iOS 27.1 SDK, the status bar and system bars
sit in a strip down the trailing edge (closed Duo; inner display in landscape).
Full-bleed art that reaches that edge uses `.nbExtendsUnderBars()`
(`backgroundExtensionEffect`, iOS 26+). Controls stay inside the safe area; custom
bars (`NBNavBar`, `FeedNavBar`) sit inside it already.

10.7 **Build with the newest released SDK.** The edge-to-edge Duo layout needs the
iOS 27.1 SDK; older SDKs run "boxed". CI picks the newest non-beta Xcode on the
`xcode-27` image and logs the SDK.

10.8 **Deliberately NOT adopted (yet)** — revisit on a physical Duo:
- `ArrangementView` / `ReservedRegion` / `reservedRegions(kind:)` fold-aware APIs —
  not compiled or verified here; the centered split (10.3) covers the book pose.
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
- ❌ A second `NavigationStack` for push flows (the Duo detail pane, §10.3, is the one exception).
- ❌ `store.navigationPath.append(PostDestination…)` / `.append(convo)` in a view — use `store.openPost` / `store.openChat` (§10.3).
- ❌ `UIScreen.main` anywhere — measure the container; use `displayScale` (§10.4).
- ❌ Branching on device / idiom / orientation for layout — size classes and measured width only (§10.1).

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
- [ ] Open iPhone Duo (regular/regular): works beside the persistent sidebar and, if it opens posts/chats, through `openPost`/`openChat` (§10).
- [ ] Feature serves human learning/agency (see CLAUDE.md "Why We Build").
