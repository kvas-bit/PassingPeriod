# Agent Context System (Zero-Bloat)

Purpose: give Claude/Hermes durable context without turning your repo into a junk drawer.

Design choices (based on PARA + atomic notes + ops playbooks):
- Keep only info that changes decisions.
- Separate stable memory from volatile state.
- One source of truth per topic.
- Small files, strict caps, aggressive archiving.

## Folder contract
- `CLAUDE.md` = behavior contract for coding agent in this project.
- `MEMORY/` = stable facts and preferences (weeks/months half-life).
- `STATE/` = current sprint/now context (hours/days half-life).
- `TEMPLATES/` = reusable execution templates.

## Anti-bloat rules
1. Any file above ~120 lines must be split.
2. `STATE/` is rewritten, not appended forever.
3. If a note hasn’t affected a decision in 30 days, archive/delete.
4. Never store raw logs in memory files.
5. Every memory note starts with `Last Updated` + `Why it exists`.

## Suggested weekly maintenance (10 min)
- Refresh `STATE/now-next-later.md`.
- Remove stale items from `MEMORY/20_projects.md`.
- Move completed context to archive in project repo if needed.
