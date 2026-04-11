# Model Routing (Concrete)
Last Updated: 2026-04-10
Why it exists: pick models fast without debate.

## Task-class routing
- Architecture / tricky debugging / merge-conflict reasoning:
  - Primary: strongest reasoning model available (Claude Opus/Sonnet tier)
  - Fallback: top GPT reasoning model
- Feature implementation (normal coding):
  - Primary: fast coding model (Claude Sonnet tier)
  - Fallback: GPT coding model
- UI copy, docs, PR text:
  - Primary: cheapest good-enough model
  - Fallback: any available general model
- Test generation / lint fixes / mechanical refactors:
  - Primary: cheapest coding-capable model
  - Fallback: next-cheapest coding model

## Fallback chain (default)
1) Claude Sonnet-tier
2) GPT coding/reasoning-tier
3) Any available model with tool-use support

If primary fails twice (rate limit/errors), auto-fallback immediately.

## Escalation rules
- Escalate to strongest model when:
  - bug survived 2 attempts
  - architecture decision affects >3 files/components
  - PR is blocking team merge queue
- De-escalate to cheaper model for:
  - formatting, docs, repetitive edits, test boilerplate

## Cost guardrail
If a task is under ~20 minutes of straightforward work, do not use premium model first.
