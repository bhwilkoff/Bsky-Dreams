# App Store listing — Bsky Dreams (iOS)

The source of truth for what's in App Store Connect. Edit here, then push with the API
(`tools/asc_release.py` for versions and What's New; the listing script pattern in DECISIONS.md
"App Store listing 1.50"). All copy is in Ben's voice (`LearningIsChange/BEN.md`): no em dashes,
"folks", plain and a little wry.

| Field | File / value |
|---|---|
| Name | Bsky Dreams |
| Subtitle | Bluesky, made for iPhone Duo |
| Promotional text | `promo.txt` |
| Description | `description.txt` |
| Keywords | `keywords.txt` (≤100 chars) |
| What's New (1.50) | `whats-new.txt` |
| Marketing URL | https://bskydreams.com |
| Support URL | https://github.com/bhwilkoff/Bsky-Dreams/issues |
| Privacy URL | https://bskydreams.com/privacy |

## Screenshots

- `screenshots/duo/` → **APP_IPHONE_DUO** (inner display, 2853×2007, landscape). Order tells the
  story: Stream as a screen saver → Stream's controls and filmstrip → exploring a post beside the
  stream → a text post as a pull quote → Home with the right pane → Search with a conversation
  beside it → the two-page conversation → the two-page profile → Constellation → Settings.
- `screenshots/iphone/` → **APP_IPHONE_67** (1290×2796; captured on the iPhone 12 at 1170×2532 and
  scaled, aspect within 0.2%).

## iPhone Duo support (what to tell reviewers and editors)

Bsky Dreams adapts to the open Duo's inner display (regular width and height, every pose) with
system navigation that moves into the Duo's vertical bar, and fold-aware layouts that split on
the hinge (`reservedRegions(kind: .division)`):

- Two views side by side (any view beside any other), or the conversation beside the list.
- One Column (whole display), a choice, not the default.
- Book pose: splits land on the fold. Rotated/tabletop: top and bottom, or side by side.
- Continuity: closing the Duo carries the open conversation, and a running Stream, to the outer display.
- Two-page conversation and profile spreads; article beside its Bluesky discussion; TV beside
  its conversation.
- Stream, a screen saver designed for the open Duo on a table.
- Built with the iOS 27.1+ SDK, so it runs edge to edge (not letterboxed).
Details: `docs/iOS-DESIGN.md` §10–§13.

## Capturing new screenshots

`tools/device_smoke.py duo <out> <view>` with the DEBUG launch doors: `BSKY_SECOND_COLUMN`,
`BSKY_SEARCH_QUERY`, `BSKY_STREAM_AUTOSTART`, `BSKY_STREAM_SEARCH`, `BSKY_STREAM_FILTER`,
`BSKY_STREAM_HOLD` (holds a post without the Paused pill), `BSKY_STREAM_CONTROLS`,
`BSKY_STREAM_EXPLORE`, `BSKY_STREAM_STEP=last`. Turn on Do Not Disturb first: a notification
banner ruined several takes.
