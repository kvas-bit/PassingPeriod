# Gungahacks

Lightweight team dashboard for hackathon execution.

## What it does
- Team roles + stack registry
- Project note feed (decisions, blockers, updates)
- Kanban board (Ideas / Todo / In Progress / Done)
- Local persistence in browser (no backend)
- JSON export/import for sharing snapshots

## Run
No install needed. Open `index.html` in a browser.

For local HTTP server:
```bash
python3 -m http.server 8080
```
Then open `http://localhost:8080`.

## Why this V1
Fastest path to team coordination without auth/devops overhead.

## Next upgrades
- GitHub Issues sync
- Per-user identity and auth
- Telegram/Discord status relay
