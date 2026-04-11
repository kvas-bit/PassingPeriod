# Between Classes — Cursor Build Handoff
Last Updated: 2026-04-10
Platform: Native iOS (SwiftUI, iOS 17+)
Demo Deadline: 2026-04-19

This document is the complete technical specification for building "Between Classes." Load this alongside `.planning/PROJECT.md` before any build session.

---

## Quick Reference

- **Kavi's lane:** All SwiftUI views, design system, animations, camera UI, 3D graph, `SpeechService.swift`
- **Teammate's lane:** All service files (Canvas, iCal, Vision, Gemini, ElevenLabs, Keychain), `QuizSessionManager.swift`, SwiftData CRUD
- **Design token file:** `Extensions/Color+Theme.swift`
- **Glass modifier:** `Extensions/View+Glass.swift` + `Components/GlassCard.swift`
- **Do not change:** Stack decisions, color tokens, font choices — these are locked.

---

## File Tree

```
BetweenClasses/
├── App/
│   ├── BetweenClassesApp.swift       # @main, SwiftData container, AppState injection
│   └── AppState.swift                # @Observable global state
├── Models/
│   ├── Note.swift
│   ├── Subject.swift
│   ├── QuizSession.swift
│   └── QuizQuestion.swift
├── Services/
│   ├── VisionOCRService.swift
│   ├── GeminiService.swift
│   ├── ElevenLabsService.swift
│   ├── SpeechService.swift
│   ├── CanvasService.swift
│   ├── iCalService.swift
│   └── KeychainService.swift
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── SubjectCardView.swift
│   ├── NoteCapture/
│   │   ├── NoteCaptureView.swift
│   │   ├── OCRConfirmView.swift
│   │   └── NoteCardView.swift
│   ├── VoiceQuiz/
│   │   ├── VoiceQuizView.swift
│   │   ├── WaveformView.swift
│   │   └── QuizSessionManager.swift
│   ├── Schedule/
│   │   ├── ScheduleView.swift
│   │   └── ClassRowView.swift
│   ├── KnowledgeGraph/
│   │   ├── KnowledgeGraphView.swift
│   │   ├── GraphScene.swift
│   │   └── GraphDataBuilder.swift
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── CanvasConnectView.swift
│   └── Components/
│       ├── GlassCard.swift
│       ├── PulseRing.swift
│       └── TabBarView.swift
└── Extensions/
    ├── Color+Theme.swift
    └── View+Glass.swift
```

---

## SwiftData Models

```swift
// Note.swift
import SwiftData
import Foundation

@Model
class Note {
    var id: UUID
    var imageData: Data?
    var extractedText: String
    var subjectID: UUID
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var questions: [QuizQuestion]

    init(imageData: Data? = nil, extractedText: String, subjectID: UUID) {
        self.id = UUID()
        self.imageData = imageData
        self.extractedText = extractedText
        self.subjectID = subjectID
        self.createdAt = Date()
        self.questions = []
    }
}

// Subject.swift
@Model
class Subject {
    var id: UUID
    var name: String            // e.g. "CS 61A"
    var instructor: String
    var colorHex: String        // for graph node tint
    @Relationship(deleteRule: .cascade) var notes: [Note]

    init(name: String, instructor: String = "", colorHex: String = "#FFFFFF") {
        self.id = UUID()
        self.name = name
        self.instructor = instructor
        self.colorHex = colorHex
        self.notes = []
    }
}

// QuizSession.swift
@Model
class QuizSession {
    var id: UUID
    var subjectID: UUID
    var startedAt: Date
    var score: Int
    var totalQuestions: Int
    @Relationship(deleteRule: .cascade) var questions: [QuizQuestion]

    init(subjectID: UUID) {
        self.id = UUID()
        self.subjectID = subjectID
        self.startedAt = Date()
        self.score = 0
        self.totalQuestions = 0
        self.questions = []
    }
}

// QuizQuestion.swift
@Model
class QuizQuestion {
    var id: UUID
    var question: String
    var expectedAnswer: String
    var userAnswer: String?
    var wasCorrect: Bool?
    var noteID: UUID

    init(question: String, expectedAnswer: String, noteID: UUID) {
        self.id = UUID()
        self.question = question
        self.expectedAnswer = expectedAnswer
        self.noteID = noteID
    }
}
```

---

## Design System

### Color Tokens (`Color+Theme.swift`)

```swift
import SwiftUI

extension Color {
    static let bgPrimary   = Color(hex: "#08090a")  // full-bleed background
    static let bgSurface   = Color(hex: "#0f1011")  // panels
    static let bgElevated  = Color(hex: "#191a1b")  // elevated cards
    static let textPrimary = Color.white
    static let textSecond  = Color.white.opacity(0.5)
    static let glassStroke = Color.white.opacity(0.08)
    static let glassFill   = Color.white.opacity(0.04)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

### Glass Card Modifier (`View+Glass.swift`)

```swift
import SwiftUI

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.glassStroke, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
```

### Typography Rules
| Role | Size | Weight | Tracking |
|---|---|---|---|
| Display | 34 | .semibold | -1.5 |
| Headline | 22 | .semibold | -0.8 |
| Body | 16 | .regular | -0.3 |
| Caption | 12 | .medium | +0.5 |

Font: Inter Variable (add via Xcode → Add Fonts to target)

### Animation Tokens
```swift
// Card entrances
.animation(.spring(response: 0.4, dampingFraction: 0.75), value: isVisible)

// Waveform bars
withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) { ... }

// 3D graph idle rotation (SceneKit)
SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 30))
```

---

## Screen Specs

### 1. Home / Dashboard (`HomeView.swift`)

**Layout (top to bottom):**
- Full bleed `Color.bgPrimary` background
- Top bar: greeting text (`"Good morning, Kavi · Thursday"`, Display style) + date chip (Caption, glass pill)
- **Next Class Card** (glass card, full width minus 32px inset):
  - Class name (Headline)
  - Time until (Body, textSecond)
  - Room (Caption, textSecond)
  - "Start Quiz" button — white fill (`Color.white`), black text, 14px bold, cornerRadius 12, full width within card
- **Recent Notes** label + horizontal scroll of `NoteCardView` (glass thumbnails, 80×100pt each)
- **Quick Stats** row: "3 day streak" + "2 sessions today" — glass chips (Caption)

**Tab bar:** `TabBarView` — 5 tabs: Home / Capture / Quiz / Schedule / Graph

### 2. Note Capture Flow

**`NoteCaptureView.swift`**
- Full-screen modal sheet
- `AVCaptureSession` live preview via `UIViewRepresentable`
- Circular shutter button (64pt white circle, black camera icon)
- On capture → show processing overlay: blur + spinner + "Extracting concepts…" label
- On success → push to `OCRConfirmView`

**`OCRConfirmView.swift`**
- Top: photo thumbnail (100×100pt, corner radius 12, glass border)
- Below: `TextEditor` in glass card — shows extracted text, editable inline
- Subject picker: `Menu` button styled as glass pill dropdown
- "Save Note" button: white fill, full width
- On save: haptic `.success`, dismiss sheet

**`NoteCardView.swift`**
- 80×100pt glass card
- Thumbnail image (if available) or gray gradient placeholder
- Subject label (Caption, textSecond) at bottom of card

### 3. Voice Quiz (`VoiceQuizView.swift`) — KEY SCREEN

**Full bleed `Color.bgPrimary` background — no navigation bar**

**Center glass card (~80% screen width, ~55% height):**
- Top: subject name (Caption, textSecond) + "Q 1 of 5" label (Caption, textSecond)
- Divider: `Color.glassStroke` 1pt line
- Middle: question text (Headline, white, tight letter-spacing -0.8)
- Bottom strip: `PulseRing` — 48pt ring, white, pulsing scale animation when mic active; flat when TTS playing

**Below glass card:**
- `WaveformView` — 20 thin vertical bars (2pt wide, 4pt gap), height animated 4–32pt, driven by audio amplitude
- Status label: "Listening…" or "Speaking…" — Caption, textSecond — `.opacity` animated in/out

**Session end overlay:**
- Score card rises from bottom (spring animation)
- "X / 5 correct" Display text, white
- SF Symbols confetti-style burst if score > 60%
- "Done" button → dismiss

### 4. Schedule View (`ScheduleView.swift`)

- `NavigationStack` with title "Schedule" (Headline)
- Refresh button `.toolbar` (top trailing)
- `List` of `ClassRowView` items grouped by day
- Pull-to-refresh → `CanvasService.refresh()`

**`ClassRowView.swift`:**
- HStack: color dot (8pt, subject color) + class name (Body) + time (Caption, textSecond)
- Trailing: "Free now" white pill badge when free window active
- Tap → sheet showing subject notes + "Start Quiz" CTA

### 5. 3D Knowledge Graph

**`KnowledgeGraphView.swift`** — `UIViewRepresentable` wrapping `SCNView`

**`GraphScene.swift` — SCNScene setup:**
```swift
// Subject node: large sphere, white emissive material
let subjectGeo = SCNSphere(radius: 0.3)
subjectGeo.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.6)
subjectGeo.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.15)

// Topic node: smaller sphere
let topicGeo = SCNSphere(radius: 0.12)
topicGeo.firstMaterial?.emission.contents = UIColor.white.withAlphaComponent(0.3)

// Edge: SCNGeometry line between node positions (cylinder trick)
// Use thin SCNCylinder(radius: 0.008, height: distance) rotated to connect two points

// Idle rotation
let spin = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 30))
rootNode.runAction(spin)
```

**`GraphDataBuilder.swift`:**
- Input: `[Subject]` from SwiftData (each with `.notes`)
- Output: `GraphData` struct with `[GraphNode]` and `[GraphEdge]`
- One subject node per Subject; one topic node per Note
- Edges: subject → its notes; cross-subject edges where note text shares keywords

**Gestures:**
- `UIPanGestureRecognizer` → rotate camera node around origin
- `UIPinchGestureRecognizer` → adjust camera `fieldOfView` (clamp 20–90°)
- `UITapGestureRecognizer` → `sceneView.hitTest()` → identify tapped node → show SwiftUI overlay tooltip

**Tooltip overlay (SwiftUI, positioned above tapped node):**
- Glass card 200×80pt
- Subject name (Body), note count (Caption), avg quiz score (Caption, textSecond)

### 6. Onboarding

**`OnboardingView.swift`**
- Full screen, `Color.bgPrimary`
- App name + tagline (Display)
- Two-step flow: Canvas token → iCal URL
- "Connect Canvas" → `CanvasConnectView` sheet

**`CanvasConnectView.swift`**
- `TextField` for school domain (e.g. `berkeley`)
- `SecureField` for Canvas access token
- `TextField` for iCal URL
- "Connect" → validates → stores via `KeychainService` → dismiss

---

## Service Interfaces

### `VisionOCRService.swift`
```swift
func extractText(from imageData: Data) async throws -> String
// Uses VNRecognizeTextRequest, recognitionLevel: .accurate
// Returns all text joined by "\n"
```

### `GeminiService.swift`
```swift
// Endpoint: POST https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent
func generateQuestions(from text: String) async throws -> [QuizQuestion]
// Prompt: "Generate 5 active recall Q&A pairs from these notes. Return JSON array: [{question, expectedAnswer}]. Notes: {text}"

func evaluateAnswer(question: String, expected: String, userAnswer: String) async throws -> (correct: Bool, feedback: String)
// Prompt: "Question: {q}\nExpected: {expected}\nStudent said: {userAnswer}\nRespond: {correct: bool, feedback: string} as JSON"
```

### `ElevenLabsService.swift`
```swift
// Endpoint: POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream
// Header: xi-api-key: {key}
// Body: { text, model_id: "eleven_turbo_v2_5", voice_settings: { stability: 0.5, similarity_boost: 0.75 } }
func speak(_ text: String) async throws
// Streams audio/mpeg → write to temp file → AVAudioPlayer.play()
// Reports amplitude via @Published var amplitude: Float (0–1) for WaveformView
```

### `SpeechService.swift`
```swift
// Wraps SFSpeechRecognizer + AVAudioEngine
func startListening() throws
func stopListening() -> String   // returns final transcript
@Published var liveTranscript: String
@Published var amplitude: Float  // mic input level 0–1 for WaveformView
```

### `CanvasService.swift`
```swift
// Base: https://{school}.instructure.com/api/v1
// Auth: Authorization: Bearer {token}
func fetchCourses() async throws -> [Subject]
func fetchCalendarEvents(courseID: String) async throws -> [ClassTime]
```

### `iCalService.swift`
```swift
func parseSchedule(from url: URL) async throws -> [ClassTime]
// Downloads iCal, parses VEVENT blocks → [ClassTime] with DTSTART, DTEND, SUMMARY
```

### `KeychainService.swift`
```swift
func save(_ value: String, for key: String) throws
func retrieve(_ key: String) throws -> String
func delete(_ key: String) throws
// Keys: "canvas_token", "canvas_school", "ical_url"
```

---

## Voice Quiz Conversation Loop

`QuizSessionManager.swift` orchestrates:

```
1. Load QuizQuestions for subject from SwiftData
2. session = QuizSession(subjectID:) → insert into context
3. For each question:
   a. ElevenLabsService.speak(question.question)
      → UI: status = "Speaking…", PulseRing flat, waveform shows TTS amplitude
   b. SpeechService.startListening()
      → UI: status = "Listening…", PulseRing pulses, waveform shows mic amplitude
   c. Wait for silence detection (1.5s no speech) or manual stop
   d. transcript = SpeechService.stopListening()
   e. result = GeminiService.evaluateAnswer(question:, expected:, userAnswer: transcript)
   f. question.userAnswer = transcript
      question.wasCorrect = result.correct
   g. ElevenLabsService.speak(result.feedback)
   h. session.score += result.correct ? 1 : 0
4. Save session to SwiftData
5. Emit sessionComplete signal → VoiceQuizView shows score card
```

---

## API Cost Reference
| Service | Tier | Cost |
|---|---|---|
| ElevenLabs turbo_v2_5 | ~$0.30/1K chars | 10-question quiz ≈ 500 chars = $0.15/session |
| Gemini 1.5 Flash | $0.075/1M input tokens | Effectively free for hackathon volume |
| Canvas API | Free | Rate limit: 200 req/min |
| Apple Vision OCR | Free | On-device |
| SFSpeechRecognizer | Free | On-device |

---

## Xcode Project Setup Checklist

- [ ] Minimum deployment: iOS 17.0
- [ ] Enable background modes: `Audio, AirPlay, and Picture in Picture`
- [ ] Privacy keys in Info.plist:
  - `NSCameraUsageDescription` — "Between Classes needs your camera to capture notes."
  - `NSMicrophoneUsageDescription` — "Between Classes uses your mic to hear your answers."
  - `NSSpeechRecognitionUsageDescription` — "Between Classes transcribes your spoken answers."
- [ ] Add Inter Variable font files to target → register in Info.plist under `UIAppFonts`
- [ ] Keychain entitlement: `Keychain Sharing` (or just default app keychain)
- [ ] SwiftData container in `BetweenClassesApp.swift`:
  ```swift
  .modelContainer(for: [Note.self, Subject.self, QuizSession.self, QuizQuestion.self])
  ```

---

## Git Conventions (from `MEMORY/30_team_git_guardrails.md`)
- PR-only to `main`, squash merges, CI gate
- Branch naming: `kavi/feature-name` or `teammate/feature-name`
- Commit messages: `feat:`, `fix:`, `chore:`, `style:`
- No direct pushes to `main`
