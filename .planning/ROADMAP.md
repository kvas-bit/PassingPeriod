# Between Classes — Roadmap
Last Updated: 2026-04-10
Milestone: MVP — Hackathon Demo
Demo Deadline: 2026-04-19 (9 days)

---

## Phase 1 — Foundation (Day 1–2)
**Goal:** Runnable app shell with design system, navigation, and data models wired up.

### Kavi (UI)
- [ ] Xcode project setup (SwiftUI, SwiftData container, minimum iOS 17)
- [ ] `Color+Theme.swift` — all design tokens
- [ ] `View+Glass.swift` — `.glassCard()` modifier
- [ ] `GlassCard.swift` — reusable glassmorphism card component
- [ ] `TabBarView.swift` — custom frosted glass bottom nav (5 tabs)
- [ ] `HomeView.swift` — skeleton layout (greeting, next class slot, recent notes slot)
- [ ] `SubjectCardView.swift` — glass card per subject
- [ ] `AppState.swift` — global `@Observable` state object
- [ ] `BetweenClassesApp.swift` — `@main`, SwiftData model container

### Teammate (Backend)
- [ ] `KeychainService.swift` — store/retrieve Canvas token + iCal URL
- [ ] `CanvasService.swift` — GET /courses, GET /calendar_events
- [ ] `iCalService.swift` — parse iCal URL → `[Subject]` array
- [ ] `OnboardingView.swift` + `CanvasConnectView.swift` — token + iCal input UI
- [ ] SwiftData schema: `Note`, `Subject`, `QuizSession`, `QuizQuestion` models

**Done when:** App launches, tab bar is visible, Home skeleton renders, SwiftData container has no compile errors.

---

## Phase 2 — Note Capture (Day 3–4)
**Goal:** Full note capture + OCR confirm flow works end-to-end; note saved to SwiftData.

### Kavi (UI)
- [ ] `NoteCaptureView.swift` — full-screen camera sheet (AVCaptureSession)
- [ ] `OCRConfirmView.swift` — photo thumbnail + extracted text (editable) + subject picker
- [ ] `NoteCardView.swift` — saved note thumbnail card
- [ ] Camera permission handling + processing overlay ("Extracting concepts…")
- [ ] Haptic feedback on save, sheet dismissal animation

### Teammate (Backend)
- [ ] `VisionOCRService.swift` — Apple Vision `VNRecognizeTextRequest` → extracted text string
- [ ] `GeminiService.generateQuestions(from:)` — extracted text → `[QuizQuestion]` array
- [ ] SwiftData CRUD: save Note + attach QuizQuestions on note save
- [ ] Canvas refresh + local cache in SwiftData

**Done when:** Photo → OCR → editable text → select subject → save → note appears in HomeView recent notes scroll.

---

## Phase 3 — Voice Quiz (Day 5–6)
**Goal:** Full voice quiz loop runs: 11 Labs speaks → user answers → Gemini evaluates → repeat.

### Kavi (UI)
- [ ] `VoiceQuizView.swift` — lock-screen style layout (full bleed, glass card centered)
- [ ] `WaveformView.swift` — thin horizontal bars, amplitude-synced animation
- [ ] `PulseRing.swift` — white pulsing ring for mic-active state
- [ ] `SpeechService.swift` — SFSpeechRecognizer wrapper: start/stop, live transcription
- [ ] Status label: "Listening…" / "Speaking…" fade in/out
- [ ] Score summary card on session end

### Teammate (Backend)
- [ ] `ElevenLabsService.swift` — POST to turbo_v2_5 stream → `AVAudioPlayer`
- [ ] `GeminiService.evaluateAnswer(question:expected:userAnswer:)` → `{ correct: Bool, feedback: String }`
- [ ] `QuizSessionManager.swift` — orchestrates: load questions → TTS → STT → evaluate → loop
- [ ] `QuizSession` + score persistence to SwiftData
- [ ] Background audio session configuration (`AVAudioSession` category `.playAndRecord`)

**Done when:** Full loop runs 3+ questions with real TTS + STT + Gemini evaluation. Score saves to SwiftData.

---

## Phase 4 — Schedule + Notifications (Day 6–7 overlap)
**Goal:** Schedule renders from Canvas/iCal; free window detection triggers local notification.

### Kavi (UI)
- [ ] `ScheduleView.swift` — class list, time column, "Free now" pill badge
- [ ] `ClassRowView.swift` — individual class row component
- [ ] Tap class → notes + "Start Quiz" for that subject

### Teammate (Backend)
- [ ] Free window detector: next class > 15 min away → `UNUserNotificationCenter` local notification
- [ ] Notification payload → deep link to `VoiceQuizView` for that subject
- [ ] Canvas refresh on pull-to-refresh in ScheduleView

**Done when:** Schedule shows real classes from Canvas/iCal. With no class in <15 min, notification fires. Tap notification opens quiz for correct subject.

---

## Phase 5 — 3D Knowledge Graph (Day 7)
**Goal:** SceneKit graph renders with subject/topic nodes, interactions working.

### Kavi (UI + SceneKit)
- [ ] `GraphDataBuilder.swift` — SwiftData subjects + notes → node/edge model
- [ ] `GraphScene.swift` — `SCNScene`: subject nodes (large spheres), topic nodes (small), white edge lines, emissive glow materials
- [ ] `KnowledgeGraphView.swift` — `UIViewRepresentable` wrapping `SCNView`
- [ ] Pan gesture → camera orbit
- [ ] Pinch gesture → zoom
- [ ] Idle auto-rotation: `SCNAction.repeatForever(rotateBy y: .pi*2, duration: 30)`
- [ ] Node tap → glass tooltip card (SwiftUI overlay): subject name, note count, quiz score

**Done when:** Graph renders with at least 2 subject nodes and their topic children. Rotation, zoom, and tooltip all work.

---

## Phase 6 — Integration + Polish (Day 8)
**Goal:** All services wired to UI; glassmorphism and animations pass everywhere; full demo path works end-to-end.

### Both
- [ ] Wire CanvasService → ScheduleView + HomeView next-class card
- [ ] Wire QuizSessionManager → VoiceQuizView (replace any stubs)
- [ ] Wire NoteCapture → OCR → Gemini question generation (pre-generate on save)
- [ ] Glassmorphism audit: every screen uses GlassCard, correct colors, correct blur
- [ ] Card entrance spring animations on all primary views
- [ ] Waveform animation tuned to real audio amplitude
- [ ] HomeView: real next class data + real recent notes
- [ ] End-to-end demo path test (snap note → quiz fires → voice loop → score)
- [ ] Fix any crashes found in test run

**Done when:** Demo path runs clean, start to finish, no stubs, on device.

---

## Phase 7 — Demo Prep (Day 9)
**Goal:** Bug-free, rehearsed, polished for 30-second judge demo.

- [ ] Fix Day 8 bugs only — no new features
- [ ] Preload Gemini questions at note save time (reduce quiz start latency)
- [ ] Lock screen demo mode: hide status bar, full glass card
- [ ] Rehearse demo path 3x (Kavi + teammate dry run)
- [ ] Confirm AirPods background audio works on demo device
- [ ] Archive: tag `v1.0-hackathon-demo` in git

**Done when:** Demo runs in under 30 seconds, no crashes, AirPods work, both team members can run it.

---

## Phase Dependency Map
```
Phase 1 → Phase 2 → Phase 3
Phase 1 → Phase 4
Phase 2 → Phase 5 (needs notes in SwiftData)
Phase 3 + Phase 4 + Phase 5 → Phase 6
Phase 6 → Phase 7
```
