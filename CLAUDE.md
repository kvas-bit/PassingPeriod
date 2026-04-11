CLAUDE.md — Kavi Build Mode

Who you are talking to
You are working with Kavi — the project lead and primary technical owner.
- Full access to all lanes: architecture, auth, db, infra, core logic, UI.
- Style: terse, no fluff, founder-speed. Prefer execution over explanation.
- Teammates have their own tools and do not use this Claude Code session. Lane rules for them are human-readable in TEMPLATES/vibe-coder-one-pager.md.

Context system — read these files
Load on every session:
- MEMORY/00_identity.md — Kavi's profile and working style.
- MEMORY/20_projects.md — active projects and priority order.
- MEMORY/40_model_routing.md — which model to use for which task.

Load when relevant:
- STATE/now-next-later.md — current sprint tasks. Load when starting any new feature or task.
- STATE/current-focus.md — main risk and mitigation. Load when making architecture decisions.
- STATE/decisions.md — past decisions. Load before proposing anything that affects architecture, stack, or team process. Append any new decisions made.
- MEMORY/30_team_git_guardrails.md — Git rules. Load when touching branches, PRs, or CI.

Load when executing:
- TEMPLATES/task-card.md — fill this before starting any non-trivial task.
- TEMPLATES/pr-checklist.md — run through this before every PR.

---

Active Project: Between Classes — Active Recall Study App
Project context (Last Updated: 2026-01 — Why it exists: Hackathon app for student study tool)
The Product
Between Classes is a voice-first active recall app that quizzes students on their notes between classes. You snap a photo of handwritten notes after class, then between classes (or anytime) you put in your AirPods and talk to the app — it quizzes you via natural voice conversation.

Core Features
1. Schedule Sync
   - Connect Canvas via Canvas API
   - Export iCal from Blue (university portal) to understand schedule
   - Knows class times, passing periods, free windows

2. Note Capture
   - Snap photo of handwritten notes after class
   - OCR/process to extract studyable content

3. Voice Quiz (Active Recall)
   - 11 Labs API for natural voice conversation
   - AirPods in → quiz starts → hands-free, pocket-friendly
   - Listens to your spoken answers without needing to open the app
   - Background audio capable (native iOS required — web won't work)

4. The Hook: Sick UI
   - Dark, minimal, editorial animations
   - Grok/Linear inspired aesthetic
   - Beautiful UI is the differentiator — judges care about this more than feature depth
   - Smooth transitions, micro-interactions, premium feel

Technical Stack
- Platform: Native iOS app (SwiftUI) — required for background audio + AirPods in pocket
- Voice: 11 Labs API via URLSession
- Schedule: Canvas API + iCal parsing
- Storage: SwiftData or SQLite for local notes + schedule
- Design: Dark minimal (Grok/Linear style), editorial animations

Design Direction (locked in)
- Background: #08090a (Linear-style near-black)
- Surface: #0f1011 (panels), #191a1b (elevated)
- Accent: Single brand color — something distinctive (not yet decided)
- Typography: Inter Variable with tight letter-spacing at display sizes
- Animations: Spring-based, smooth, editorial feel — not flashy, just right

Why Native iOS (not web)
| Requirement | Web | Native iOS |
|-------------|-----|------------|
| Background audio (AirPods in pocket) | ❌ | ✅ |
| Mic access while app backgrounded | ❌ | ✅ |
| Works with screen off | ❌ | ✅ |

Web was considered for MVP speed — rejected because core use case (hands-free quiz between classes) requires background audio.

---

Mission
Ship fast, high-signal product work with clean Git collaboration and minimal tool sprawl.

Core priorities
1. Ship user-visible value fast.
2. Protect team velocity (small PRs, clean merges, green CI). (1/3)