# Between Classes — Xcode Setup

## Option A: xcodegen (recommended, 30 seconds)

```bash
brew install xcodegen
cd BetweenClasses
xcodegen generate
open BetweenClasses.xcodeproj
```

## Option B: Manual Xcode

1. File → New → Project → App
2. Name: `BetweenClasses`, Interface: SwiftUI, Storage: SwiftData
3. Minimum deployment: iOS 17
4. Drag all folders (`App/`, `Models/`, `Services/`, `Views/`, `Extensions/`) into the project navigator
5. Delete the auto-generated `ContentView.swift`

## Required Xcode settings (both options)

In the target's **Signing & Capabilities**:
- Add **Background Modes** → check `Audio, AirPlay, and Picture in Picture`
- Add **Keychain Sharing** (default app group is fine)

In **Info** tab (or Info.plist):
- `NSCameraUsageDescription` — "Between Classes needs your camera to capture notes."
- `NSMicrophoneUsageDescription` — "Between Classes uses your mic to hear your answers."
- `NSSpeechRecognitionUsageDescription` — "Between Classes transcribes your spoken answers."
- `UIBackgroundModes` → `audio`

## API Keys (entered in app at first launch)

| Key | Where to get |
|---|---|
| Gemini | [aistudio.google.com](https://aistudio.google.com) → Get API key |
| Canvas token | Canvas → Account → Settings → Approved Integrations |

All keys are stored in Keychain via `KeychainService` — never hardcoded.

## TTS voice

Quiz speech uses `gemini-3.1-flash-tts-preview` with the `Aoede` voice via the same Gemini API key.
Change `voiceName` in `GeminiTTSService.swift` to switch voices.
