# Team Git Guardrails
Last Updated: 2026-04-10
Why it exists: prevent velocity loss in 3-human + AI collaboration.

Enforce in GitHub:
- Protected `main` (PR required, no force push).
- Required checks + required approvals.
- CODEOWNERS on core paths.
- Optional actor-aware CI policy for stricter teammate-specific limits.

Operational pattern:
- Hermes handles conflict resolution, rebase cleanup, CI triage.
- Humans own product decisions and final merge approval.
