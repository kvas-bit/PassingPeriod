# GSD State Bridge
Last Updated: 2026-04-10

This file is a thin bridge so GSD workflows find the expected state paths.
Canonical state lives in `STATE/` — do not duplicate content here, only reference.

## Active Sprint
- See: `STATE/now-next-later.md`
- Current focus: Phase 1 (Foundation) — Kavi building shell + design system

## Current Risk
- See: `STATE/current-focus.md`
- Primary risk: Voice loop latency (TTS → STT → Gemini evaluation adds up). Mitigation: pre-generate questions at note save time, use turbo_v2_5 for lowest TTS latency.

## Decision Log
- See: `STATE/decisions.md`
- New decisions from this session logged there.

## Active Phases
| Phase | Status | Owner |
|---|---|---|
| 1 — Foundation | In Progress | Kavi (UI) + Teammate (Backend) |
| 2 — Note Capture | Pending | Kavi + Teammate |
| 3 — Voice Quiz | Pending | Kavi + Teammate |
| 4 — Schedule + Notifications | Pending | Kavi + Teammate |
| 5 — 3D Knowledge Graph | Pending | Kavi |
| 6 — Integration + Polish | Pending | Both |
| 7 — Demo Prep | Pending | Both |

## GSD Plan Files
Phase plan files go in `.planning/phases/phaseN/PLAN.md` as they are created.
