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

## What This App Does

Bsky Dreams is a custom web app for the BlueSky social network that allows
users to get the most out of the platform without using the default
website/app. It addresses BlueSky's friction points around searchability,
conversation clarity, media handling, and analytics — while helping users
break out of information bubbles through truth/fact-checking visibility.

## Tech Stack

- **Rendering:** Vanilla HTML/JS — no framework, no build step required
- **Styling:** Custom CSS (mobile-first, CSS custom properties for theming)
- **API:** BlueSky AT Protocol HTTP API (https://bsky.social/xrpc/*) via fetch
- **Auth:** App password stored in localStorage (user-provided, never sent to any backend other than bsky.social)
- **Deployment:** GitHub Pages static hosting (branch: main, root: /)

## Key Directories

- `/` — Root: index.html, CLAUDE.md, SCRATCHPAD.md, DECISIONS.md, README.md
- `/css/` — Stylesheets (styles.css is the single main stylesheet)
- `/js/` — JavaScript modules (app.js, api.js, auth.js)
- `/assets/` — Static assets (icons, images)

## How to Run Locally

Open `index.html` directly in a browser:
```
open index.html
# or
python3 -m http.server 8080  # then visit http://localhost:8080
```

No build step required. The app runs as a static file.

## How to Deploy

1. Push changes to `main` branch
2. GitHub Pages serves from root of `main` automatically
3. Live URL: https://bhwilkoff.github.io/bskydreams

## Conventions

- All API calls go through `js/api.js` — never call `fetch` against bsky.social directly from other files
- Auth state (JWT session) is managed exclusively in `js/auth.js`
- CSS custom properties (variables) are defined in `:root` in `styles.css`
- Mobile-first: all media queries use `min-width` breakpoints
- Semantic HTML throughout — use `<article>`, `<section>`, `<nav>`, `<button>` appropriately
- No inline styles — all styling via CSS classes
- Error states must be user-visible (not just console logs)

## Important Constraints

- GitHub Pages static deployment only — no server runtime, no Node.js
- Zero-cost tools only — no paid APIs, no paid hosting
- No build pipeline — everything must work as plain HTML/CSS/JS
- User credentials (app password) stored in localStorage only, never transmitted anywhere except bsky.social
- AT Protocol base URL: `https://bsky.social/xrpc/` for all API calls

## Do Not Touch

- `.git/` directory
- GitHub Pages deployment settings (configured in repo settings, branch: main)

## Reference Repositories

When researching new features, API capabilities, or implementation patterns, consult
these repositories in addition to the official BlueSky documentation:

- **AT Protocol Python SDK + examples**: https://github.com/MarshalX/atproto
  Good for understanding AT Protocol record schemas, lexicon types, and API edge cases
  even when the implementation language differs.
- **Awesome AT Protocol**: https://github.com/beeman/awesome-atproto
  Curated list of AT Protocol tools, libraries, feed generators, and community projects.
  Useful for discovering existing solutions before building from scratch.
- **Awesome Bluesky**: https://github.com/fishttp/awesome-bluesky
  Curated list of Bluesky-specific apps, bots, utilities, and resources. Check here for
  prior art on any feature before implementing it.

When a feature request touches AT Protocol specifics (lexicons, record types, feed
generators, labelers, chat API), scan these repos first. They frequently contain
working code samples and gotchas not covered in the official docs.

## Current State

See @SCRATCHPAD.md for current session state.
See @DECISIONS.md for all architecture decisions.
