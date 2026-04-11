# Between Classes — Requirements
Last Updated: 2026-04-10
Scope: Hackathon MVP (9-day sprint, demo on 2026-04-19)

## Must Ship (Demo Path Non-Negotiable)
These are required for the 30-second demo to land.

### R1 — Home Dashboard
- Display greeting + date
- Show "Next Class" glass card: class name, time until, room
- "Start Quiz" CTA on the card
- Recent Notes horizontal scroll
- Custom glass bottom tab bar (Home / Capture / Quiz / Schedule / Graph)

### R2 — Note Capture
- Full-screen camera sheet (AVCaptureSession)
- Processing overlay while OCR runs ("Extracting concepts…")
- OCR Confirm screen: photo thumbnail + extracted text (editable)
- Subject picker (glass dropdown) → save → haptic feedback → dismiss

### R3 — Voice Quiz (KEY SCREEN)
- Lock-screen style: full bleed near-black, centered glass card
- Card shows: subject name + question number + current question text
- PulseRing: white pulsing ring when listening, flat when speaking
- WaveformView: thin horizontal bars below card, synced to audio amplitude
- "Listening…" / "Speaking…" status label fades in/out
- 11 Labs TTS speaks questions and feedback
- SFSpeechRecognizer captures user answers
- Gemini Flash evaluates answer → returns correct/incorrect + feedback
- Session ends with score summary card

### R4 — Schedule View
- List of classes from Canvas / iCal
- Each row: class name, time, free-window badge ("Free now" white pill)
- Tap class → notes list + "Start Quiz" for that subject
- Refresh button pulls Canvas again

### R5 — 3D Knowledge Graph (SHOWPIECE)
- SceneKit embedded in SwiftUI (UIViewRepresentable)
- Subject nodes: large frosted spheres, emissive white glow
- Topic nodes: smaller spheres clustered around subjects
- Edges: thin white lines with slight glow
- Camera: pan to rotate, pinch to zoom, idle auto-rotation (30s/revolution)
- Tap node → glass tooltip (subject name, note count, quiz score)

### R6 — Onboarding
- Canvas token input + school domain entry
- iCal URL input (from university portal)
- Stored securely in Keychain (never in code or UserDefaults)

### R7 — Schedule-Triggered Quiz Notification
- Detect free window: next class > 15 min away
- Local notification: "Quiz time for [Subject]?"
- Tap → opens VoiceQuizView directly

## Nice-to-Have (only if core path is stable by Day 8)
- Quiz streak counter on Home
- Sessions-today chip on Home
- Per-subject quiz history list
- Dark/light mode toggle (default dark, probably unnecessary)

## Out of Scope (for this hackathon)
- Push notifications via server
- Multi-user / accounts
- Web or Android
- Offline Gemini fallback
- Sync across devices
