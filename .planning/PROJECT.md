# Between Classes — Project Spec
Last Updated: 2026-04-10
Milestone: MVP — Hackathon Demo (9 days, deadline 2026-04-19)

## What It Is
Voice-first active recall iOS app. Students snap photos of handwritten notes after class. Between classes (AirPods in, screen off, pocket), the app quizzes them via natural voice conversation.

## Demo Path (30 seconds, what judges see)
1. Open app → Home shows "CS 61A in 12 min" glass card
2. Tap "Start Quiz" → VoiceQuizView opens (lock-screen style)
3. 11 Labs speaks a question → waveform pulses
4. User answers aloud → STT captures → Gemini evaluates
5. 11 Labs speaks feedback + next question
6. Quiz ends → score summary

## Team
- **Kavi** — UI owner: SwiftUI views, design system, animations, 3D graph, camera/capture
- **Teammate** — Backend owner: all services (Canvas, iCal, Vision OCR, Gemini, ElevenLabs, Keychain), data layer

## Tech Stack (finalized — no changes)
| Layer | Choice | Why |
|---|---|---|
| Platform | Native iOS (SwiftUI) | Background audio, mic while backgrounded, screen-off |
| Voice TTS | ElevenLabs API (turbo_v2_5) | Premium natural voice |
| Voice STT | Apple SFSpeechRecognizer | Free, on-device, no latency |
| OCR | Apple Vision framework | Free, on-device |
| Quiz AI | Gemini 1.5 Flash | Cheap, fast, generous free tier |
| Schedule | Canvas API token + iCal URL | Covers all schools, live data |
| Storage | SwiftData (local) | Notes + questions, cached schedule |
| 3D Graph | SceneKit | Native iOS, no deps |
| UI Style | Monochrome glassmorphism (Grok/xAI inspired) | Premium futuristic aesthetic |

## Design System (locked)
- Background: `#08090a` (near-black)
- Surface: `#0f1011` (panels), `#191a1b` (elevated)
- Text: white / white 50% for secondary
- Glass: `white.opacity(0.04)` fill, `white.opacity(0.08)` stroke
- Typography: Inter Variable — Display 34/semibold/-1.5, Body 16/regular/-0.3, Caption 12/medium/+0.5
- Animations: `.spring(response: 0.4, dampingFraction: 0.75)` for cards

## Architecture
See `CURSOR_HANDOFF.md` for full file tree, SwiftData models, service interfaces, and screen-by-screen specs.

## Context References
- Identity/style: `MEMORY/00_identity.md`
- Past decisions: `STATE/decisions.md`
- Sprint state: `STATE/now-next-later.md`
- Git rules: `MEMORY/30_team_git_guardrails.md`
