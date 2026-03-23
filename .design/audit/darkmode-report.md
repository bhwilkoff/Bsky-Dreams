# Dark Mode Audit Report

**Date:** 2026-03-23
**Files Scanned:** 20
**Issues Found:** 10 (8 fixed, 2 intentional / acceptable)

---

## Summary

| Sin | Type | Issues Found | Fixed |
|-----|------|-------------|-------|
| 1 — Hardcoded Colors | Hex literals not in DesignSystem | 8 | 8 |
| 2 — Inverted Contrast | Dark bg / light text patterns | 1 | 1 (DM bubbles) |
| 3 — Semi-Transparent | Opacity on assumed-dark backgrounds | 1 | 1 |
| 4 — Border Colors | Invisible borders in dark mode | 3 | 3 |
| 5 — Shadow Opacity | (Addressed in prior review session) | 0 | — |
| 6 — Image/Icon Contrast | Icons on dark without background | 0 | — |
| 7 — Status Colors | (ProgressView.tint, red/green semantic) | 0 | — |

---

## Issues Fixed

### 1. Login screen background hardcoded warm white
**File:** `Views/Auth/LoginView.swift:176`
**Was:** `Color(hex: "#FFFDF8")` — always warm white regardless of mode
**Fix:** `Color.nbBackground` — adapts: `#FAFAFA` light, `#0D1421` dark
**Why:** Login screen appeared completely white in dark mode; dot grid dots (`nbBlack.opacity(0.12)`) were near-invisible on white

### 2. Login screen logo title hardcoded `Color.black`
**File:** `Views/Auth/LoginView.swift:26`
**Was:** `Color.black` — always pure black
**Fix:** `Color.nbBlack` — adapts to near-white in dark mode
**Why:** Black text on `#0D1421` dark background was readable but stylistically inconsistent; `nbBlack` correctly inverts

### 3. DM received bubble — hardcoded gray and inverted text
**File:** `Views/DMs/DMsView.swift:640`
**Was:** Background `Color(hex: "#5A6473")` with `Color.white` text
**Fix:** Background `Color.nbMessageBubble` (new token: `#E8EEF4` light / `#243040` dark); text `isOwn ? Color.white : Color.nbBlack`
**Why:** Two failures: (a) `#5A6473` is a flat medium gray that doesn't adapt to theme; (b) `Color.white` on the `#E8EEF4` light-mode bubble was invisible (white on near-white)

### 4. Constellation view background hardcoded near-black
**File:** `Views/Constellation/ConstellationView.swift:385`
**Was:** `Color(hex: "#0A0A14")` — near-black with blue tint, always
**Fix:** `Color.nbBackground` + `.preferredColorScheme(.dark)` on the view
**Why:** The graph is always intended as a dark-canvas view. Adding `.preferredColorScheme(.dark)` makes the design intent explicit, forces all design tokens to resolve to dark values, and eliminates the risk of white text becoming invisible if someone switches to light mode

### 5. Constellation search bar separator hardcoded
**File:** `Views/Constellation/ConstellationView.swift:376`
**Was:** `Rectangle().fill(Color(hex: "#E0E0E0"))`
**Fix:** `Rectangle().fill(Color.nbBorder)` — adapts: `#E0E0E0` light, `#405570` dark

### 6. Constellation profile card drag handle hardcoded
**File:** `Views/Constellation/ConstellationView.swift:902`
**Was:** `Color(hex: "#E0E0E0")`
**Fix:** `Color.nbBorder`

### 7. Constellation profile card dismiss button border hardcoded
**File:** `Views/Constellation/ConstellationView.swift:935`
**Was:** `Color(hex: "#E0E0E0")`
**Fix:** `Color.nbBorder`

### 8. Analytics heatmap zero-count cell hardcoded light gray
**File:** `Views/Analytics/AnalyticsView.swift:375, 385`
**Was:** `Color(hex: "#EBEDF0")` — always light gray, invisible/flat in dark mode
**Fix:** `Color.nbHeatmapZero` (new token: `#EBEDF0` light / `#1E2D40` dark)
**Why:** Light gray on dark background loses the subtle "no activity" cell distinction the heatmap relies on; the dark token provides appropriate contrast while staying visually quiet

### 9. RichTextView link color inline hardcode
**File:** `Components/RichTextView.swift:17`
**Was:** Inline `colorScheme == .dark ? Color(hex: "#5DB8D0") : Color.nbBlue`
**Fix:** `Color.nbLinkColor` (new token with same values, centralized in DesignSystem)
**Why:** One-off hex outside the design system makes the color invisible to future theme changes; `nbLinkColor` can now be updated in one place

---

## New DesignSystem.swift Tokens Added

| Token | Light | Dark | Used In |
|-------|-------|------|---------|
| `nbLinkColor` | `#0047FF` | `#5DB8D0` | RichTextView |
| `nbMessageBubble` | `#E8EEF4` | `#243040` | DMsView chat bubbles |
| `nbHeatmapZero` | `#EBEDF0` | `#1E2D40` | AnalyticsView heatmap |

---

## Intentional / Acceptable Hardcodes (not fixed)

### TV view — `Color.white` text on forced-dark background
**Files:** `Views/TV/TVView.swift` (many lines)
**Status:** Acceptable — TVView applies `.preferredColorScheme(.dark)` which forces all content into dark mode. All white text is on video/dark backgrounds and is intentional.

### Sidebar dim overlay — `Color.black.opacity(dimOpacity)`
**File:** `ContentView.swift:124`
**Status:** Intentionally hardcoded. Dim overlays should ALWAYS be black regardless of color scheme. Using `Color.nbBlack` in dark mode (which resolves to near-white) would create a white/bright overlay — the opposite of dimming content. Pure black is the correct choice for scrim overlays.

### Post card depth colors (8 cycling colors for reply nesting)
**File:** `Components/PostCardView.swift:34-37`
**Status:** Acceptable — these are semantic accent colors for thread depth visualization, not adaptive UI. They're vivid on both light and dark backgrounds as 3pt accent bars.

---

## Remaining Minor Items (not fixed in this pass)

- `Analytics/AnalyticsView.swift:703` — debug test output panel uses `Color.black` background with `.white` text. This is a developer/diagnostic view not exposed to users in standard flows.
- `Views/TV/TVView.swift:581` — `UIColor.black.cgColor` for AVPlayer background. Correct — video player layers always need black backgrounds.

---

## Verification

All opacity-based text colors replaced in prior session (101 call sites migrated to `nbTextSecondary`/`nbTextTertiary`). Remaining `nbBlack.opacity()` uses are at 0.2 or below — decorative only.

Run `/KUI:review` for full design heuristic audit if needed.
