# AGENTS.md

## Cursor Cloud specific instructions

### Project Overview

This is **PassingPeriod / BetweenClasses**, a pure iOS/SwiftUI app (Swift 5.9, iOS 17+) for university students. It has **zero third-party dependencies** — only Apple first-party frameworks (SwiftUI, SwiftData, Vision, Speech, AVFoundation, SpriteKit, Security).

### Linux Cloud Agent Limitations

- **Cannot build or run the app** — requires macOS + Xcode 15+ with iOS 17+ SDK and a simulator. There is no server-side component, no web UI, and no Docker infrastructure.
- **Can lint** — SwiftLint is installed at `/usr/local/bin/swiftlint` (static binary). Run from the `BetweenClasses/` directory:
  ```
  cd BetweenClasses && swiftlint lint --quiet
  ```
  The dynamic binary (requiring `LD_LIBRARY_PATH`) also works for SourceKit-enabled rules; see below.
- **Can compile Swift** — Swift 6.0.3 toolchain is at `/opt/swift-6.0.3-RELEASE-ubuntu24.04/`. Add to PATH: `export PATH=/opt/swift-6.0.3-RELEASE-ubuntu24.04/usr/bin:$PATH`. Note: the project's Swift files cannot be compiled on Linux because they import iOS-only frameworks (SwiftUI, SwiftData, Vision, etc.).

### Linting

Run SwiftLint from the `BetweenClasses/` directory:

```bash
cd /workspace/BetweenClasses
swiftlint lint --quiet
```

For SourceKit-enabled rules (dynamic binary), also set:
```bash
export LD_LIBRARY_PATH=/opt/swift-6.0.3-RELEASE-ubuntu24.04/usr/lib/swift/linux:$LD_LIBRARY_PATH
```

The codebase currently has ~200 lint violations (mostly `identifier_name` and `line_length`). These are pre-existing in the repo.

### Project Structure

See `README.md` for the full structure. Key paths:
- `BetweenClasses/project.yml` — XcodeGen spec for generating the `.xcodeproj`
- `BetweenClasses/App/` — App entry point and root views
- `BetweenClasses/Models/` — SwiftData models (Note, Subject, QuizSession, etc.)
- `BetweenClasses/Services/` — API integrations (Canvas, Gemini, ElevenLabs, Vision OCR, iCal, Speech, Keychain)
- `BetweenClasses/Views/` — SwiftUI views organized by feature
- `BetweenClasses/Extensions/` — Design system and utility extensions

### Testing

There are no automated tests in this repository. Testing requires running the app in an iOS Simulator on macOS.

### API Keys

API keys (Gemini, ElevenLabs, Canvas) are entered by the user at first launch and stored in iOS Keychain. None are hardcoded. See `BetweenClasses/setup.md` for details.
