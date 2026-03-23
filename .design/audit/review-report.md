# Bsky Dreams iOS — Design Review Report

**Date:** 2026-03-23
**Scope:** Full iOS app — Neubrutalist + Memphis system, dark mode, light mode cohesion
**Overall Heuristic Score:** 36/50

---

## Executive Summary

The light mode is genuinely excellent Neubrutalism: hard offset shadows, thick borders, tight Syne type, vivid accent pops. The Memphis diagonal stripe adds texture without clutter. However, **dark mode has three structural failures that break the entire design language**, and a handful of light-mode inconsistencies keep the system from feeling fully finished.

The core dark mode problem is not a color problem — it is a **surface hierarchy problem**. The app background and card surface both resolve to the same color (`#142033`). Without a distinct background, the offset shadow has nothing to land on. Cards float in a featureless sea of navy. The defining Neubrutalist device — the hard 3D block effect — disappears entirely.

---

## Critical Issues (must fix)

### 1. Card surface = App background in dark mode
**File:** `DesignSystem.swift:26-32`
**What:** Both the page background and card `nbWhite` resolve to `#142033`. There is no surface/depth distinction in dark mode.
**Why it matters:** The entire neubrutalist shadow system depends on three distinct layers: card surface → hard shadow offset → page background. When surface and background are the same value, the shadow is invisible regardless of its color. The 3D "block" illusion completely collapses.
**Fix:** Introduce a separate `nbBackground` semantic color. Dark mode: page background `#0C1520` (very deep navy-black), card surface `#172232` (distinct, lighter). Light mode: both stay `#FFFFFF` (no change). Every `ScrollView`, `List`, and `ZStack` root should use `nbBackground`; cards use `nbWhite`.

---

### 2. Shadow color is indistinguishable from card surface in dark mode
**File:** `DesignSystem.swift:46-52`
**What:** Shadow color in dark mode is `#3D5166` (slate). Card surface is `#142033`. The contrast ratio between these two is approximately 1.6:1 — barely perceptible.
**Why it matters:** Even after fixing issue #1, the shadow itself needs to read as a bold, graphic shape. At 1.6:1 contrast, the hard offset simply looks like a slight smear. Neubrutalism's shadow is not a drop shadow — it is a visible second surface.
**Fix:** In dark mode, change the shadow to `#5B8FAF` (medium slate-blue, ~3.5:1 on `#172232`) — or better, make the dark mode shadow **use the accent color at partial opacity**. Accent-colored shadows are the most distinctive and playful dark-mode Neubrutalism move. Example: `Color.nbAccent.opacity(0.7)`. This makes every card shadow carry the user's chosen accent color — lime cards cast lime shadows, coral cards cast coral shadows. Memphis + Neubrutalism.

---

### 3. Border color is nearly invisible in dark mode
**File:** `DesignSystem.swift:34-41`
**What:** `nbBorder` in dark mode is `#253448` on a card of `#142033`. Contrast ratio ≈ 1.3:1.
**Why it matters:** The bold 2-3px border is Neubrutalism's second defining feature after the shadow. It separates the card from the background and signals "this is an object." At 1.3:1 it is essentially invisible — cards look like borderless rounded rects (everything Neubrutalism rejects).
**Fix:** In dark mode, change `nbBorder` (the border/stroke color) to use `nbBlack` — i.e., the adapted `#CCD9E6` cool blue-white. This gives ~5:1 contrast on the card surface. Borders become clearly visible and structural. This is the standard dark-mode Neubrutalism approach: if your light mode uses near-black borders on white, your dark mode should use near-white borders on dark.

---

### 4. Secondary text fails WCAG AA contrast in dark mode
**File:** `PostCardView.swift:147`, `ContentView.swift:387`, throughout
**What:** Secondary text uses `Color.nbBlack.opacity(0.5)` and `.opacity(0.4)`. In dark mode, `nbBlack` resolves to `#CCD9E6` (L≈85). At 50% opacity on `#172232` (L≈8): contrast ≈ 2.1:1. At 40%: ≈ 1.8:1. Both fail WCAG AA (requires 4.5:1 for normal text).
**Why it matters:** Handle text (`@handle`), action bar icon labels, timestamps, and the sidebar handle footer are all rendered at illegal contrast in dark mode. These are not decorative elements — they are functional UI.
**Fix:** Do not use opacity-based fading in dark mode. Replace `Color.nbBlack.opacity(0.5)` with a dedicated `nbTextSecondary` semantic color:
- Light: `#5A5A5A` (6.3:1 on white)
- Dark: `#8BA0B5` (4.6:1 on `#172232`)

Replace `Color.nbBlack.opacity(0.4)` with `nbTextTertiary`:
- Light: `#7A7A7A` (4.5:1 on white)
- Dark: `#6D8499` (4.5:1 on `#172232`)

---

## Important Issues (fix in next iteration)

### 5. Memphis diagonal stripe is nearly invisible in dark mode
**File:** `DesignSystem.swift:151-178`
**What:** `DiagonalStripeBackground` uses `Color.nbAccent.opacity(0.08)` as base and `opacity(0.15)` for stripe lines. On `#172232` in dark mode, these are almost imperceptible.
**Why it matters:** The Memphis pattern is one of the two things that distinguish this design system from generic brutalism. If it's invisible in dark mode, dark mode feels generic.
**Fix:** In dark mode, increase to `opacity(0.18)` base and `opacity(0.30)` stripes. Alternatively, use a `colorSchemeAware` pattern: in dark mode, draw stripes using `Color.nbBlack` (the cool blue-white) at 0.08/0.15 rather than the accent color. White stripes on dark is the classic Memphis dark-mode treatment and reads much better.

---

### 6. Accent color swatches in Settings use circles, not neubrutalist squares
**File:** `ContentView.swift:645-655`
**What:** The color picker renders 32pt circles with circular borders. Circles are reserved for avatars per the design system.
**Why it matters:** Minor but breaks the "0 border-radius" rule that makes the system cohesive. Every other UI object (cards, buttons, badges, nav items) has sharp corners. Circular color swatches feel like a generic iOS Settings screen, not a Neubrutalist design system.
**Fix:** Replace `Circle()` with `RoundedRectangle(cornerRadius: 0)` (32×32 squares). Use `.overlay(Rectangle().strokeBorder(...))` matching the border convention. Selected state: 3px border + nbShadow(size: 2) offset. This turns the color picker into a row of little Neubrutalist cards.

---

### 7. Active sidebar nav item has no border in dark mode
**File:** `ContentView.swift:449-451`
**What:** The active sidebar item applies `Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2)` as overlay — which means in dark mode the border is `#CCD9E6` (cool blue-white) on an `nbAccent` fill. Depending on accent color, this can clash significantly (e.g., blue accent + blue-white border = near-invisible) or look fine (coral accent + cool border works better).
**Why it matters:** The active state border is a core piece of the nav affordance. It should always be legible.
**Fix:** For the active sidebar item, always use `Color.white` as the border color regardless of mode. On any solid accent fill, white at 2px is always legible. Inactive items use `Color.clear` border (no border), which is correct — they don't need one.

---

### 8. App/scroll background not set explicitly — inherits system default
**File:** Throughout all views
**What:** No view explicitly sets a scroll background or app background color. SwiftUI defaults to the system background (white/near-black), which neither matches `nbWhite` in light mode nor `nbBackground` (proposed) in dark mode.
**Why it matters:** Between cards in a LazyVStack feed, the background color leaks through. In light mode this is white so it's fine. In dark mode, it renders as iOS system dark (a slightly different shade than `#142033`), creating a visible mismatch.
**Fix:** Set `.background(Color.nbBackground)` on all `ScrollView` and `List` containers. After introducing `nbBackground` per issue #1, this becomes trivial.

---

### 9. DiagonalStripeBackground appears in only two places
**File:** `ContentView.swift:364`, `settingsHeader`
**What:** The Memphis stripe is only used in the sidebar header (a thin 14pt band) and the Settings page header. It is absent from: Profile banners (with no custom image), empty states, the compose sheet header, the TV splash screen, the Constellation empty state.
**Why it matters:** The design system spec says "Memphis accents" but they are nearly absent. The app currently relies entirely on borders and shadows for its personality — the Memphis half of the hybrid is undersold.
**Fix:** Add `DiagonalStripeBackground()` as a banner/header accent on Profile (when no banner image exists, currently uses plain gray), NBNavBar (a 3pt stripe at the very bottom, like the sidebar), and all empty state illustrations.

---

### 10. Sidebar channel section header is too invisible
**File:** `ContentView.swift:288-293`
**What:** "CHANNELS" label uses `Color.nbBlack.opacity(0.4)` — a very faint treatment. In both modes this reads as barely-there ghost text.
**Why it matters:** Section headers in a sidebar serve as wayfinding landmarks. They need enough presence to scan quickly without dominating.
**Fix:** Use `nbTextTertiary` (from fix #4) — a concrete color value, not opacity. Pair with the existing `tracking(2)` and Syne 10pt treatment. Also increase top padding from 4 to 8pt to give the section more breathing room above.

---

## Polish (nice to have)

### P1. NeubrutalistButtonStyle resting offset is only -2px
**File:** `DesignSystem.swift:130-132`
The resting state is offset -2px (up-left), pressed is +1px (down-right). The total travel is only 3px, which is subtle enough that the press animation can feel like a jitter rather than a satisfying mechanical "click." Increase to -3px resting / +1px pressed for more tactile drama — 4px total travel reads much more clearly as a physical button.

### P2. Action bar icon contrast is too uniform
**File:** `PostCardView.swift:168-230`
Reply, repost, and like icons all use `nbBlack.opacity(0.6)` in inactive state. The like icon with `.heart` is what users care most about interacting with. Consider giving the inactive like icon a slightly different base treatment (perhaps `nbBlack.opacity(0.7)` + slightly larger size) to make it more obviously interactive before being tapped.

### P3. Sidebar footer handle opacity too low
**File:** `ContentView.swift:387`
`"@\(handle)"` at `nbBlack.opacity(0.7)` is fine in light mode but dips to borderline contrast in dark mode (same issue as #4). Use `nbTextSecondary` instead.

### P4. The badge dot (8pt circle) is too small and ambiguous
**File:** `ContentView.swift:439-443`
The unread indicator in sidebar nav items is an 8pt filled circle with no count. Compare to the channel unread badge (shows count in a bordered rectangle). The nav badge should either show a count (for 1-9) or match the bordered rectangle style for consistency with channel badges.

### P5. Settings section headers use `.inter(14, weight: .semibold)` inside rows
**File:** `ContentView.swift:637`, throughout
These row-level labels ("Accent Color", "Appearance", "Default Feed") should use `.syne(13)` to distinguish them from the Inter body values. Currently they use Inter semibold — same weight as value labels in the `settingsRow()` helper. The typographic distinction between labels and values is too subtle.

---

## Heuristic Scores

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of system status | 4/5 | Loading states good; pull-to-refresh clear |
| 2 | Match between system and real world | 4/5 | "Conversation" rename complete; natural language throughout |
| 3 | User control and freedom | 4/5 | Back, cancel, confirm dialogs all in place |
| 4 | Consistency and standards | 3/5 | Circle swatches, opacity-based fading break system rules |
| 5 | Error prevention | 4/5 | Confirmations for destructive actions; good |
| 6 | Recognition over recall | 4/5 | Icons labeled in sidebar; action bar icons self-evident |
| 7 | Flexibility and efficiency | 3/5 | No power-user shortcuts; acceptable for social app |
| 8 | Aesthetic and minimalist design | 3/5 | Dark mode structural failures drag this down hard |
| 9 | Error recovery | 3/5 | Retry on foreground; some silent catch {} in networking |
| 10 | Help and documentation | 4/5 | Empty states mostly present; no onboarding needed |

**Total: 36/50**

---

## Dark Mode Issues Summary

| # | Issue | Severity | File |
|---|-------|----------|------|
| 1 | Card and background are same color — shadow has no surface to land on | Critical | DesignSystem.swift:26 |
| 2 | Shadow color `#3D5166` vs card `#142033` = 1.6:1 contrast — invisible | Critical | DesignSystem.swift:46 |
| 3 | Border color `#253448` vs card `#142033` = 1.3:1 contrast — invisible | Critical | DesignSystem.swift:34 |
| 4 | Secondary text opacity-based = fails WCAG AA in dark mode | Critical | Throughout |
| 5 | Memphis diagonal stripes invisible at 0.08/0.15 opacity | Important | DesignSystem.swift:151 |
| 7 | Active nav border color may clash with accent on dark backgrounds | Important | ContentView.swift:449 |

---

## Recommended Fix Order for Maximum Impact

1. **Fix the surface hierarchy** (issues #1 + #3 together) — add `nbBackground`, fix border color. This alone will make dark mode feel architecturally correct. ~30 minutes.

2. **Fix the shadow** (issue #2) — switch dark mode shadow to accent-colored. This restores the defining Neubrutalist device and adds a burst of playfulness unique to each user's accent choice. ~15 minutes.

3. **Fix text contrast** (issue #4) — introduce `nbTextSecondary` and `nbTextTertiary`. This is the most labor-intensive change (many call sites) but critical for accessibility and dark mode polish. ~45-60 minutes.

4. **Fix Memphis visibility** (issue #5) — increase stripe opacity in dark mode. ~10 minutes.

5. **Fix color swatches to squares** (issue #6) — quick win, reinforces system cohesion. ~15 minutes.

---

## Next Steps

- Run `/KUI:darkmode` for a deeper per-screen dark mode audit after implementing the critical fixes
- Run `/KUI:a11y` for a full WCAG accessibility audit focused on contrast ratios
