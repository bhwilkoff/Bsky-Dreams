# POST Button Rounded Rectangle — Fix History

## The Problem

There are **two separate but related** rounded rectangle issues in the iOS app:

### Issue A — FeedView toolbar POST button
The "POST" button in the home feed navigation bar has an unwanted system-rendered rounded
rectangle background appearing around the custom coral-colored button. The toolbar background
is `Color.nbWhite`. The custom button label has a coral fill + black border (neubrutalist style).
The system renders an additional gray/material rounded rect overlay on top of or around the
button frame, making it look out of place.

### Issue B — ComposeView toolbar POST button + character counter
The compose sheet's navigation bar has `.toolbarBackground(.hidden)`, making it transparent.
The POST button and the circular character counter sit in `.topBarTrailing` toolbar items.
A rounded rectangle (system-rendered, gray or material) appears around the POST button and/or
the area containing both items. The user describes this as "the rounded rectangle that holds
the post button and the character counter."

---

## Root Cause (Diagnosed)

SwiftUI maps `ToolbarItem` content to UIKit's `UIBarButtonItem`. In iOS 15+, UIKit uses
`UIButtonConfiguration` internally for bar button items. Even with `.buttonStyle(.plain)` on
the SwiftUI `Button`, UIKit still applies its own styled background to the `UIBarButtonItem`
hit area. This is a system-level rendering behavior — it is NOT part of the SwiftUI button
styling system.

Key facts:
- `.buttonStyle(.plain)` suppresses SwiftUI-level button backgrounds and highlights, but
  **does NOT affect the UIKit-level `UIBarButtonItem` rendering**.
- The rounded rect drawn is from UIKit, not from any SwiftUI modifier on the button label.
- `.toolbarBackground(.hidden, for: .navigationBar)` makes the nav bar itself transparent,
  but UIKit still renders its button item backgrounds on top.
- The rounded rect color/material adapts to light/dark mode and blur level — it is NOT a
  fixed color, so it cannot be reliably hidden by matching a background color.

---

## Attempts Made

### Attempt 1 — `.buttonStyle(.plain)` alone
**Status: Insufficient**

Applied `.buttonStyle(.plain)` to the SwiftUI Button inside the ToolbarItem. This suppresses
SwiftUI's default button highlight and press-state background, but has no effect on the UIKit
bar button item background. The rounded rect remained visible.

**Code state (both views):**
```swift
Button(action: ...) { /* label */ }
    .buttonStyle(.plain)
```

---

### Attempt 2 — Outer `.background(Color.nbWhite)` wrapper
**Status: Tried and then removed; problem persisted**

Added `.background(Color.nbWhite)` as an outer modifier on the ToolbarItem button to cover
the system rounded rect by matching the toolbar background color. This was noted in the
session summary as: *"POST toolbar button wrapped in `.background(Color.nbWhite)` to eliminate
iOS default rounded-rect highlight."*

However, this was **later removed** because the rounded rect was still visible — the system
draws the rounded rect at a different z-level or with a slightly different color/material than
`Color.nbWhite`, so the explicit white background did not fully cover it.

**Code state (FeedView at that point):**
```swift
Button(action: { showCompose = true }) { /* label */ }
    .buttonStyle(.plain)
    .background(Color.nbWhite)
```

---

### Attempt 3 — `.padding(.vertical, 6).background(Color.nbWhite)` (FeedView)
**Status: Current state — still visible per user**

Added vertical padding before the white background, reasoning that the system rounded rect
extends outside the button's natural frame and the padding would extend the white cover far
enough to completely obscure it.

**Current code (FeedView):**
```swift
Button(action: { showCompose = true }) {
    Text("POST")
        .font(.syne(12, weight: .bold))
        .tracking(1)
        .foregroundStyle(Color.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.nbAccent)
        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
}
.buttonStyle(.plain)
.padding(.vertical, 6)
.background(Color.nbWhite)
```

---

### Attempt 4 — `.padding(.vertical, 6).background(Color(.systemBackground))` (ComposeView)
**Status: Current state — still visible per user**

For ComposeView, where `.toolbarBackground(.hidden)` is set, used `Color(.systemBackground)`
to match the dynamic system background (white in light mode). Same padding extension logic
as Attempt 3.

**Current code (ComposeView):**
```swift
Button(action: post) { /* label */ }
    .buttonStyle(.plain)
    .disabled(!canPost)
    .padding(.vertical, 6)
    .background(Color(.systemBackground))
```

---

### Attempt 5 — `UIBarButtonItem.appearance()` global suppression
**Status: Current state — still visible per user (unclear if actually taking effect)**

Added to `BskyDreamsApp.init()`:
```swift
UIBarButtonItem.appearance().setBackgroundImage(UIImage(), for: .normal, barMetrics: .default)
UIBarButtonItem.appearance().setBackgroundImage(UIImage(), for: .highlighted, barMetrics: .default)
UIBarButtonItem.appearance().setBackgroundImage(UIImage(), for: .focused, barMetrics: .default)
```

**Why it likely doesn't work:** In iOS 15+, SwiftUI-generated `UIBarButtonItem` instances that
wrap custom SwiftUI views use `UIButtonConfiguration` rather than the legacy background image
system. `setBackgroundImage(_:for:barMetrics:)` is a pre-`UIButtonConfiguration` API that has
no effect on configuration-based buttons. The `UIAppearance` proxy cannot reach
`UIButtonConfiguration`-based rendering.

---

---

### Attempt 6 — Replace `Button` with plain view + `.onTapGesture` (CURRENT)
**Status: Implemented — awaiting test**

**Root cause insight:** SwiftUI specifically creates a `UIButton`-backed `UIBarButtonItem` when the
`ToolbarItem` content is a SwiftUI `Button`. The `UIButtonConfiguration` (and its rounded rect)
is applied by UIKit to `UIButton` instances, not to plain `UIView` instances. When the
`ToolbarItem` content is NOT a `Button` (any other SwiftUI view), UIKit creates a
`UIBarButtonItem(customView: UIView)` using a plain `UIView` — which never receives
`UIButtonConfiguration` treatment.

**Fix:** Remove the `Button` wrapper and replace with `.onTapGesture`. The content is now
a plain `Text` view (rendered by UIKit as a customView `UIBarButtonItem` without any
`UIButtonConfiguration`), so no rounded rect is rendered.

**FeedView (current code):**
```swift
ToolbarItem(placement: .topBarTrailing) {
    Text("POST")
        .font(.syne(12, weight: .bold))
        .tracking(1)
        .foregroundStyle(Color.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.nbAccent)
        .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { showCompose = true }
        .accessibilityLabel("POST")
        .accessibilityAddTraits(.isButton)
}
```

**ComposeView (current code):**
```swift
ToolbarItem(placement: .topBarTrailing) {
    Text(isPosting ? "Posting..." : "POST")
        .font(.syne(13, weight: .bold))
        .tracking(1)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(canPost ? Color.nbAccent : Color.nbBlue.opacity(0.4))
        .overlay(Rectangle().strokeBorder(Color.nbBlack.opacity(canPost ? 1 : 0.3), lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { if canPost && !isPosting { post() } }
        .accessibilityLabel(isPosting ? "Posting" : "POST")
        .accessibilityAddTraits(.isButton)
}
```

**BskyDreamsApp.init():** The legacy `UIBarButtonItem.appearance().setBackgroundImage()` calls
were removed. The `UIBarButtonItemStateAppearance.backgroundEffect` API referenced in Option 2
of this doc does NOT exist — compile error confirmed. The primary fix is the `.onTapGesture`
approach; no BskyDreamsApp changes needed.

---

## What Has NOT Been Tried

The following approaches are plausible and have not yet been attempted:

### Option 1 — `.tint(.clear)` on the ToolbarItem container
The system rounded rect uses the button's tint color for its highlight. Setting `.tint(.clear)`
or `.tint(Color.nbWhite)` on the container might make the rounded rect invisible by rendering
it as the same color as the background.

```swift
ToolbarItem(placement: .topBarTrailing) {
    Button(action: { showCompose = true }) { /* label */ }
        .buttonStyle(.plain)
}
.tint(Color.nbWhite)  // apply on the ToolbarItem itself
```

### Option 2 — `UINavigationBar.appearance()` with `compactAppearance`
The standard + compact + scrollEdge appearances all need to be configured to suppress button
highlights. Setting `buttonAppearance` on `UINavigationBarAppearance` is the modern API that
affects `UIButtonConfiguration`-based bar buttons:

```swift
let barAppearance = UINavigationBarAppearance()
barAppearance.configureWithOpaqueBackground()
barAppearance.backgroundColor = UIColor(Color.nbWhite)
var buttonAppearance = UIBarButtonItemAppearance()
buttonAppearance.normal.backgroundEffect = nil
buttonAppearance.highlighted.backgroundEffect = nil
barAppearance.buttonAppearance = buttonAppearance
barAppearance.doneButtonAppearance = buttonAppearance
UINavigationBar.appearance().standardAppearance = barAppearance
UINavigationBar.appearance().compactAppearance = barAppearance
UINavigationBar.appearance().scrollEdgeAppearance = barAppearance
```

### Option 3 — Move POST button out of the toolbar entirely
Use `.safeAreaInset(edge: .top)` or a `ZStack` overlay to position a custom button over
the navigation bar area, bypassing UIKit's bar button item system entirely. This gives full
control over rendering at the cost of manual safe area handling.

### Option 4 — Custom `UIViewRepresentable` button
Wrap the POST button in a `UIViewRepresentable` that creates a plain `UIView` with a
`UIButton` using `.plain` configuration and no background — then place this in the
`ToolbarItem`. Plain UIButton with no configuration should render no rounded rect.

### Option 5 — Replace NavigationStack toolbar with inline custom header
Remove `.toolbar` entirely from ComposeView and build a custom header bar as a `VStack`
sibling to the content. This is the nuclear option but guarantees no UIKit interference.

---

## Current State of Code

**FeedView** (`Views/Feed/FeedView.swift`, `toolbarContent`):
```swift
ToolbarItem(placement: .topBarTrailing) {
    Button(action: { showCompose = true }) {
        Text("POST")
            .font(.syne(12, weight: .bold))
            .tracking(1)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.nbAccent)
            .overlay(Rectangle().strokeBorder(Color.nbBlack, lineWidth: 2))
    }
    .buttonStyle(.plain)
    .padding(.vertical, 6)
    .background(Color.nbWhite)
}
```

**ComposeView** (`Views/Compose/ComposeView.swift`, toolbar):
- `.toolbarBackground(.hidden, for: .navigationBar)`
- `characterCounter` in one `.topBarTrailing` item (ZStack of two circles, no background)
- POST Button in second `.topBarTrailing` item:
```swift
Button(action: post) {
    Text(isPosting ? "Posting..." : "POST")
        .font(.syne(13, weight: .bold))
        .tracking(1)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(canPost ? Color.nbAccent : Color.nbBlue.opacity(0.4))
        .overlay(Rectangle().strokeBorder(Color.nbBlack.opacity(canPost ? 1 : 0.3), lineWidth: 2))
}
.buttonStyle(.plain)
.disabled(!canPost)
.padding(.vertical, 6)
.background(Color(.systemBackground))
```

**BskyDreamsApp** (`BskyDreamsApp.swift`, `init()`):
```swift
UIBarButtonItem.appearance().setBackgroundImage(UIImage(), for: .normal, barMetrics: .default)
UIBarButtonItem.appearance().setBackgroundImage(UIImage(), for: .highlighted, barMetrics: .default)
UIBarButtonItem.appearance().setBackgroundImage(UIImage(), for: .focused, barMetrics: .default)
```

**Test view** (`Views/PostButtonTest.swift`):
`PostButtonTestView` with `#Preview` — renders POST button on bright green toolbar background
to make any residual rounded rect visually obvious.
