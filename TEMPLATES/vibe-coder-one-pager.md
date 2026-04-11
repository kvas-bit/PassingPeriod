# Vibe Coder One-Pager (Read this first)

Your lane:
- UI polish, loading/error/empty states, docs, tests, fixture/mock data, QA repros.

Not your lane (unless assigned):
- Auth, DB schema, infra, deployment, core architecture.

Branch + PR flow:
1) `git checkout main && git pull origin main`
2) `git checkout -b fix/<short-name>` (or `feat/<short-name>`)
3) Keep PR <= 150 changed lines when possible
4) Push + open PR early
5) Include in PR: what changed + what tested + screenshot (if UI)

Hard rules:
- Never push to `main`
- No force push shared branches
- No dependency upgrades without approval

If blocked >15 min:
- Post exact error + what you tried + ask for unblocking help.

Definition of done:
- Works locally
- CI passes
- Reviewer can understand the change in under 2 minutes
