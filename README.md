# Between Classes

An iOS app for students that captures notes via camera, quizzes you with AI-generated TTS, and syncs your schedule with Canvas LMS.

## Features

- **Note Capture** — Snap a photo of a whiteboard or slides; OCR extracts the text and saves it as organized notes
- **Voice Quiz** — Generate a quiz from your notes and answer by speaking; the app reads questions aloud using Gemini TTS
- **Canvas Sync** — Pull your class schedule from Canvas LMS into the app
- **Knowledge Graph** — Visual web of your notes and their connections

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | SwiftUI (iOS 17+) |
| AI / TTS | Gemini API (gemini-3.1-flash, Aoede voice) |
| Schedule | Canvas LMS REST API |
| OCR | Apple Vision framework |
| Storage | SwiftData |
| Auth | Keychain (per-user API keys, never hardcoded) |

## Setup

> See [`BetweenClasses/setup.md`](./BetweenClasses/setup.md) for the full Xcode setup guide.

Quick version (requires XcodeGen):

```bash
brew install xcodegen
cd BetweenClasses
xcodegen generate
open BetweenClasses.xcodeproj
```

Then add your signing team in Xcode (Signing & Capabilities) and you're ready to run.

## Project Structure

```
BetweenClasses/
├── App/              # App entry point, root views, app state
├── Models/           # SwiftData models
├── Services/         # Canvas, Gemini, GeminiTTS, VisionOCR, iCal, Speech, Keychain
├── Views/            # All SwiftUI views organized by feature
├── Extensions/       # Utility extensions
└── Resources/        # Assets, fonts (optional)
```

## API Keys

API keys are entered at first launch and stored securely in the iOS Keychain — no hardcoding required.

| Key | Where to get |
|---|---|
| Gemini | [aistudio.google.com](https://aistudio.google.com) → Get API key |
| Canvas token | Canvas LMS → Account → Settings → Approved Integrations |

## License

See the `LICENSE` file in this repository.
