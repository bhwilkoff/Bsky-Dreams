# Bsky Dreams

A custom web app for the BlueSky social network that gives you more control
over your experience — better search, clearer conversations, and frictionless
posting — without requiring the default app or any server infrastructure.

## What it does

- **Search** — Full-text and advanced search across BlueSky posts with filters
- **Conversation View** — Threaded post viewer with collapsible replies and inline reply composition
- **Posting** — Compose and publish posts to BlueSky from within the app

## How to run locally

No build step required. Open `index.html` directly in your browser:

```bash
open index.html
```

Or serve it with any static file server:

```bash
python3 -m http.server 8080
# then open http://localhost:8080
```

## How to deploy

This app is deployed via GitHub Pages from the `main` branch root.

1. Push your changes to the `main` branch
2. GitHub Pages serves the site automatically
3. Live URL: https://bhwilkoff.github.io/bskydreams

## Authentication

Bsky Dreams uses BlueSky **App Passwords** — not your main account password.

1. Log in to [bsky.app](https://bsky.app)
2. Go to **Settings → Privacy and Security → App Passwords**
3. Create a new app password for "Bsky Dreams"
4. Enter your handle and the app password in the Bsky Dreams login screen

Your credentials are stored only in your browser's `localStorage` and are
sent only to `bsky.social` — never to any third party.

## Tech stack

- Vanilla HTML, CSS, JavaScript — no framework, no build step
- BlueSky AT Protocol HTTP API via native `fetch`
- Zero external dependencies (no npm, no CDN scripts)
- GitHub Pages static hosting

## Development

All significant decisions are documented in [DECISIONS.md](DECISIONS.md).
Current session state is in [SCRATCHPAD.md](SCRATCHPAD.md).
Persistent project context for Claude Code is in [CLAUDE.md](CLAUDE.md).

## License

MIT
