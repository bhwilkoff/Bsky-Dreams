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
- ❌ A second `NavigationStack` for push flows.

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
- [ ] Feature serves human learning/agency (see CLAUDE.md "Why We Build").
