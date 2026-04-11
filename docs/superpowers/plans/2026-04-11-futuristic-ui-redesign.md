# Futuristic UI Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Elevate Between Classes' visual identity with a monochrome refractive aesthetic: a morphing crystal on the voice quiz screen, iridescent borders on key cards, and a liquid tab indicator.

**Architecture:** Four independent surgical changes layered onto the existing codebase. The crystal is a `TimelineView`+`Canvas` 2D polygon morpher (no SceneKit/Metal needed). Iridescent borders are a new `View` modifier. Tab indicator uses `matchedGeometryEffect` with a spring.

**Tech Stack:** SwiftUI (`Canvas`, `TimelineView`, `matchedGeometryEffect`), existing `BCDesignSystem`, `QuizSessionManager`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `Views/VoiceQuiz/CrystalMorphEngine.swift` | Shape math: vertex positions, liquid displacement, morph lerp |
| Create | `Views/VoiceQuiz/MorphingCrystalView.swift` | SwiftUI `Canvas` renderer + glow + orbit rings |
| Modify | `Views/VoiceQuiz/VoiceQuizView.swift` | Replace center `GlassCard`+`PulseRing` with `MorphingCrystalView` |
| Modify | `Extensions/View+Glass.swift` | Add `.iridBorder(cornerRadius:)` modifier |
| Modify | `Views/Home/HomeView.swift` | Apply `.iridBorder` + ambient glow to `NextClassCard` |
| Modify | `Views/Home/SubjectCardView.swift` | Apply `.iridBorder` to card |
| Modify | `Views/Components/TabBarView.swift` | Liquid indicator dot via `matchedGeometryEffect` |

---

## Task 1: CrystalMorphEngine

**Files:**
- Create: `BetweenClasses/Views/VoiceQuiz/CrystalMorphEngine.swift`

The engine uses **48 vertices** sampled at evenly-spaced angles around a unit circle. Each shape is defined by a radius function `r(angle)`. Morphing lerps radii with a cubic ease; during the transition a sin-envelope liquid displacement is added.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

// MARK: - Shape definitions

enum CrystalShape: Equatable {
    case gem, sphere, diamond, cube, prism, pentagon, octagon, star
}

struct CrystalMorphEngine {
    static let vertexCount = 48

    // Radius for a regular N-gon at angle θ
    private static func nGonRadius(_ n: Int, angle: Double) -> Double {
        let sector = 2.0 * .pi / Double(n)
        let ang = angle.truncatingRemainder(dividingBy: sector)
        let normalized = (ang + sector).truncatingRemainder(dividingBy: sector)
        return cos(.pi / Double(n)) / cos(normalized - .pi / Double(n))
    }

    // Radius for a star (outerR / innerR alternating, `points` tips)
    private static func starRadius(angle: Double, points: Int = 5,
                                   outer: Double = 1.0, inner: Double = 0.42) -> Double {
        let halfSector = .pi / Double(points)
        let ang = angle.truncatingRemainder(dividingBy: 2 * halfSector)
        let norm = (ang + 2 * halfSector).truncatingRemainder(dividingBy: 2 * halfSector)
        let t = abs(norm - halfSector) / halfSector  // 0 = valley, 1 = tip
        return inner + (outer - inner) * pow(t, 0.65)
    }

    /// Base radius (no liquid) for a shape at a given angle
    static func baseRadius(for shape: CrystalShape, angle: Double) -> Double {
        switch shape {
        case .gem:
            // Elongated: taller top/bottom, slight 6-fold faceting
            let yComponent = abs(cos(angle))
            let facet = 0.96 + 0.04 * abs(cos(3 * angle))
            return (0.72 + 0.42 * pow(yComponent, 0.55)) * facet
        case .sphere:
            return 1.0
        case .diamond:
            let taper = sin(angle)
            return 0.35 + 0.78 * abs(taper)
        case .cube:
            return nGonRadius(4, angle: angle) * 0.84
        case .prism:
            return nGonRadius(3, angle: angle) * 0.90
        case .pentagon:
            return nGonRadius(5, angle: angle) * 0.90
        case .octagon:
            return nGonRadius(8, angle: angle) * 0.92
        case .star:
            return starRadius(angle: angle)
        }
    }

    /// Sample all vertices for a shape as unit-circle fractions
    static func vertices(for shape: CrystalShape, in size: CGSize) -> [CGPoint] {
        let cx = size.width / 2, cy = size.height / 2
        let r = min(cx, cy) * 0.88
        return (0..<vertexCount).map { i in
            let angle = Double(i) * 2 * .pi / Double(vertexCount) - .pi / 2
            let radius = baseRadius(for: shape, angle: angle) * r
            return CGPoint(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
        }
    }

    /// Liquid displacement at vertex i, given morph progress (0–1) and time
    static func liquidDisplacement(vertexIndex: Int, morphProgress: Double,
                                   time: Double, maxRadius: Double) -> Double {
        let angle = Double(vertexIndex) * 2 * .pi / Double(vertexCount)
        // Envelope peaks at mid-morph, zero at settled endpoints
        let envelope = 0.55 * sin(morphProgress * .pi)
        let noise = sin(angle * 4.8 + time * 2.2) * 0.30
                  + sin(angle * 3.1 + time * 1.7) * 0.24
                  + sin(angle * 6.3 + time * 3.0) * 0.18
                  + sin(angle * 2.4 + time * 1.4) * 0.14
        return envelope * noise * maxRadius
    }

    /// Cubic ease-in-out
    static func ease(_ t: Double) -> Double {
        t < 0.5 ? 4*t*t*t : 1 - pow(-2*t+2, 3)/2
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

```bash
cd /Users/kaviantoniovasudeo/Downloads/Agent-Hackathon-Context
xcodebuild -scheme BetweenClasses -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add BetweenClasses/Views/VoiceQuiz/CrystalMorphEngine.swift
git commit -m "feat(crystal): add CrystalMorphEngine with shape math and liquid displacement"
```

---

## Task 2: MorphingCrystalView

**Files:**
- Create: `BetweenClasses/Views/VoiceQuiz/MorphingCrystalView.swift`

Renders the morphing crystal using `TimelineView(.animation)` + `Canvas`. Handles the morph state machine internally, driven by a `CrystalShape` input.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct MorphingCrystalView: View {
    let shape: CrystalShape

    // Morph state
    @State private var fromVertices: [CGPoint] = []
    @State private var toShape: CrystalShape = .gem
    @State private var morphStart: Date = .now
    @State private var morphDuration: Double = 1.1
    @State private var iridRotation: Double = 0

    private let size = CGSize(width: 180, height: 180)

    var body: some View {
        ZStack {
            // Iridescent ambient glow
            AngularGradient(
                colors: [
                    Color(red: 0.78, green: 0.84, blue: 1.0).opacity(0.18),
                    Color(red: 0.84, green: 0.71, blue: 1.0).opacity(0.12),
                    Color(red: 0.71, green: 1.0, blue: 0.84).opacity(0.15),
                    Color(red: 1.0, green: 0.95, blue: 0.80).opacity(0.10),
                    Color(red: 0.78, green: 0.84, blue: 1.0).opacity(0.18),
                ],
                center: .center,
                startAngle: .degrees(iridRotation),
                endAngle: .degrees(iridRotation + 360)
            )
            .frame(width: 260, height: 260)
            .blur(radius: 32)
            .onAppear {
                withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                    iridRotation = 360
                }
            }

            TimelineView(.animation) { timeline in
                Canvas { ctx, canvasSize in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let elapsed = now - morphStart.timeIntervalSinceReferenceDate
                    let rawT = min(elapsed / morphDuration, 1.0)
                    let t = CrystalMorphEngine.ease(rawT)

                    let toVerts = CrystalMorphEngine.vertices(for: toShape, in: canvasSize)
                    let maxR = min(canvasSize.width, canvasSize.height) * 0.88 * 0.55

                    // Lerp vertices + liquid displacement
                    let verts: [CGPoint] = (0..<CrystalMorphEngine.vertexCount).map { i in
                        let from = i < fromVertices.count
                            ? fromVertices[i]
                            : toVerts[i]
                        let to = toVerts[i]
                        let cx = canvasSize.width / 2, cy = canvasSize.height / 2
                        // Direction from center (unit vector)
                        let dx = to.x - cx, dy = to.y - cy
                        let dist = sqrt(dx*dx + dy*dy)
                        let nx = dist > 0 ? dx/dist : 0
                        let ny = dist > 0 ? dy/dist : 0

                        let disp = CrystalMorphEngine.liquidDisplacement(
                            vertexIndex: i, morphProgress: rawT,
                            time: now, maxRadius: maxR
                        )
                        return CGPoint(
                            x: from.x + (to.x - from.x) * t + nx * disp,
                            y: from.y + (to.y - from.y) * t + ny * disp
                        )
                    }

                    // Orbit rings
                    let cx = canvasSize.width/2, cy = canvasSize.height/2
                    let orbitR1: Double = min(cx, cy) * 1.06
                    let orbitR2: Double = min(cx, cy) * 1.16
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: cx-orbitR1, y: cy-orbitR1,
                                               width: orbitR1*2, height: orbitR1*2)),
                        with: .color(.white.opacity(0.07)), lineWidth: 1
                    )
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: cx-orbitR2, y: cy-orbitR2,
                                               width: orbitR2*2, height: orbitR2*2)),
                        with: .color(.white.opacity(0.04)), lineWidth: 0.75
                    )

                    // Crystal body — filled polygon
                    var path = Path()
                    path.move(to: verts[0])
                    for v in verts.dropFirst() { path.addLine(to: v) }
                    path.closeSubpath()

                    // Fill: dark with subtle shimmer
                    ctx.fill(path, with: .color(Color(red: 0.11, green: 0.13, blue: 0.18).opacity(0.92)))

                    // Internal facet lines (every 8th vertex to center)
                    let center = CGPoint(x: cx, y: cy)
                    for i in stride(from: 0, to: CrystalMorphEngine.vertexCount, by: 8) {
                        var spoke = Path()
                        spoke.move(to: center)
                        spoke.addLine(to: verts[i])
                        ctx.stroke(spoke, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
                    }

                    // Outline
                    ctx.stroke(path, with: .color(.white.opacity(0.22)), lineWidth: 1.0)

                    // Specular — bright dot at topmost vertex
                    let top = verts.min(by: { $0.y < $1.y }) ?? verts[0]
                    ctx.fill(Path(ellipseIn: CGRect(x: top.x-3, y: top.y-3, width: 6, height: 6)),
                             with: .color(.white.opacity(0.92)))
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .frame(width: size.width, height: size.height)
        .onChange(of: shape) { _, newShape in
            // Snapshot current vertices as "from" then start morph to new shape
            let current = CrystalMorphEngine.vertices(for: toShape, in: size)
            fromVertices = current
            toShape = newShape
            morphStart = .now
            morphDuration = 1.0
        }
        .onAppear {
            toShape = shape
            fromVertices = CrystalMorphEngine.vertices(for: shape, in: size)
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme BetweenClasses -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add BetweenClasses/Views/VoiceQuiz/MorphingCrystalView.swift
git commit -m "feat(crystal): add MorphingCrystalView with Canvas polygon morph and iridescent glow"
```

---

## Task 3: Wire Crystal into VoiceQuizView

**Files:**
- Modify: `BetweenClasses/Views/VoiceQuiz/VoiceQuizView.swift`

Replace the `PulseRing` + `GlassCard` wrapper in `quizContent` with `MorphingCrystalView`. Map `manager.state` → `CrystalShape`.

- [ ] **Step 1: Add shape-mapping computed property**

In `VoiceQuizView`, add after the `amplitude` property:

```swift
private var crystalShape: CrystalShape {
    switch manager.state {
    case .listening:   return .gem
    case .speaking:    return .diamond
    case .evaluating:  return .cube
    case .complete:    return .star
    default:           return .sphere
    }
}
```

- [ ] **Step 2: Replace PulseRing with MorphingCrystalView in quizContent**

In `quizContent`, find:
```swift
PulseRing(isListening: isListening, size: 48)
    .padding(.vertical, BCSpacing.xxl)
```

Replace with:
```swift
MorphingCrystalView(shape: crystalShape)
    .padding(.vertical, BCSpacing.lg)
```

- [ ] **Step 3: Remove GlassCard wrapper from quizContent, go full-screen**

The outer `GlassCard` in `quizContent` (the one wrapping question text + dividers + ring) is replaced by a plain `VStack` so the crystal is unboxed. Change:

```swift
VStack(spacing: 0) {
    // ... header, divider, question, divider, PulseRing
}
.glassCard()
.padding(.horizontal, BCSpacing.xxl)
```

To:

```swift
VStack(spacing: 0) {
    HStack {
        Text(appState.quizSubject?.name.uppercased() ?? "QUIZ")
            .bcCaption()
            .foregroundStyle(Color.textSecond)
        Spacer()
        if manager.questions.count > 0 {
            Text("Q \(manager.currentIndex + 1) of \(manager.questions.count)")
                .bcCaption()
                .foregroundStyle(Color.textSecond)
        }
    }
    .padding(.horizontal, BCSpacing.xl)
    .padding(.top, BCSpacing.xl)
    .padding(.bottom, BCSpacing.lg)

    // Iridescent divider
    Rectangle()
        .fill(
            LinearGradient(
                colors: [.clear,
                         Color(red:0.73,green:0.80,blue:1.0).opacity(0.28),
                         Color(red:0.84,green:0.72,blue:1.0).opacity(0.20),
                         Color(red:0.73,green:1.0,blue:0.84).opacity(0.26),
                         .clear],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .frame(height: 1)

    if let q = manager.currentQuestion {
        Text(q.question)
            .bcHeadline()
            .foregroundStyle(Color.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, BCSpacing.xl)
            .padding(.vertical, BCSpacing.xxl)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .id(q.id)
    } else {
        Text("Preparing quiz…")
            .bcHeadline()
            .foregroundStyle(Color.textSecond)
            .padding(BCSpacing.xxl)
    }

    MorphingCrystalView(shape: crystalShape)
        .padding(.vertical, BCSpacing.lg)

    Rectangle()
        .fill(
            LinearGradient(
                colors: [.clear,
                         Color(red:0.73,green:1.0,blue:0.84).opacity(0.20),
                         Color(red:0.73,green:0.80,blue:1.0).opacity(0.24),
                         .clear],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .frame(height: 1)
}
.padding(.horizontal, BCSpacing.xxl)
```

- [ ] **Step 4: Build**

```bash
xcodebuild -scheme BetweenClasses -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add BetweenClasses/Views/VoiceQuiz/VoiceQuizView.swift
git commit -m "feat(quiz): replace PulseRing with MorphingCrystalView, add iridescent dividers"
```

---

## Task 4: Iridescent Border Modifier

**Files:**
- Modify: `BetweenClasses/Extensions/View+Glass.swift`

Add an `.iridBorder(cornerRadius:)` modifier — an animated rotating gradient stroke.

- [ ] **Step 1: Add IridBorderModifier to View+Glass.swift**

After the closing brace of `GlassCardModifier`, add:

```swift
// MARK: - Iridescent Border

struct IridBorderModifier: ViewModifier {
    var cornerRadius: CGFloat
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color.white.opacity(0.32),
                                Color(red: 0.73, green: 0.80, blue: 1.0).opacity(0.26),
                                Color(red: 0.84, green: 0.72, blue: 1.0).opacity(0.20),
                                Color(red: 0.73, green: 1.0, blue: 0.84).opacity(0.24),
                                Color(red: 1.0, green: 0.96, blue: 0.80).opacity(0.18),
                                Color.white.opacity(0.32),
                            ],
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: 1
                    )
            }
            .onAppear {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

extension View {
    func iridBorder(cornerRadius: CGFloat = BCRadius.panel) -> some View {
        modifier(IridBorderModifier(cornerRadius: cornerRadius))
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme BetweenClasses -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add BetweenClasses/Extensions/View+Glass.swift
git commit -m "feat(irid): add iridBorder modifier with animated AngularGradient stroke"
```

---

## Task 5: Next Class Card — Iridescent Border + Ambient Glow

**Files:**
- Modify: `BetweenClasses/Views/Home/HomeView.swift`

Apply `.iridBorder` and a breathing glow to `NextClassCard`.

- [ ] **Step 1: Apply iridBorder to NextClassCard body**

In `NextClassCard.body`, find the outer `GlassCard { ... }` and chain `.iridBorder()` after it:

```swift
var body: some View {
    GlassCard {
        // ... existing content unchanged ...
    }
    .iridBorder(cornerRadius: BCRadius.panel)
    .background {
        RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous)
            .fill(Color.white.opacity(glowOpacity))
            .blur(radius: 24)
    }
    .onAppear {
        withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
            glowOpacity = 0.07
        }
    }
}
```

- [ ] **Step 2: Add glowOpacity state to NextClassCard**

At the top of `NextClassCard`, add:

```swift
@State private var glowOpacity: Double = 0.03
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme BetweenClasses -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add BetweenClasses/Views/Home/HomeView.swift
git commit -m "feat(home): iridescent border + breathing ambient glow on NextClassCard"
```

---

## Task 6: Subject Card — Iridescent Border

**Files:**
- Modify: `BetweenClasses/Views/Home/SubjectCardView.swift`

- [ ] **Step 1: Chain .iridBorder onto the GlassCard in SubjectCardView**

In `SubjectCardView.body`, find:
```swift
GlassCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
    // ...
}
```

Change to:
```swift
GlassCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
    // ... unchanged ...
}
.iridBorder(cornerRadius: BCRadius.panel)
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme BetweenClasses -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add BetweenClasses/Views/Home/SubjectCardView.swift
git commit -m "feat(subjects): iridescent border on subject cards"
```

---

## Task 7: Tab Bar — Liquid Indicator Dot

**Files:**
- Modify: `BetweenClasses/Views/Components/TabBarView.swift`

Replace the white-blob selected state with a sliding dot using `matchedGeometryEffect`.

- [ ] **Step 1: Add namespace and dot to TabBarView**

Replace entire `TabBarView.body`:

```swift
@Namespace private var tabIndicator

var body: some View {
    @Bindable var appState = appState

    HStack(spacing: 0) {
        ForEach(AppTab.allCases, id: \.self) { tab in
            TabBarItem(
                tab: tab,
                isSelected: appState.selectedTab == tab,
                namespace: tabIndicator
            ) {
                appState.selectedTab = tab
            }
        }
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 10)
    .background {
        RoundedRectangle(cornerRadius: BCRadius.dock, style: .continuous)
            .fill(.ultraThinMaterial)
            .background {
                RoundedRectangle(cornerRadius: BCRadius.dock, style: .continuous)
                    .fill(Color.bgElevated.opacity(0.88))
            }
            .overlay {
                RoundedRectangle(cornerRadius: BCRadius.dock, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(0.55), radius: 28, x: 0, y: 14)
    }
    .padding(.horizontal, BCSpacing.lg)
    .padding(.bottom, 10)
}
```

- [ ] **Step 2: Update TabBarItem to accept namespace and use matchedGeometryEffect**

Replace `TabBarItem`:

```swift
private struct TabBarItem: View {
    let tab: AppTab
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .bottom) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                        .frame(height: 28)
                        .scaleEffect(isSelected ? 1.05 : 1.0)

                    if isSelected {
                        // Liquid indicator dot
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4, height: 4)
                            .matchedGeometryEffect(id: "tabDot", in: namespace)
                            .offset(y: 6)

                        // Comet trail — delayed copy at low opacity
                        Circle()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 4, height: 4)
                            .matchedGeometryEffect(id: "tabDotTrail", in: namespace,
                                                   isSource: false)
                            .offset(y: 6)
                            .animation(
                                .spring(response: 0.38, dampingFraction: 0.72).delay(0.06),
                                value: isSelected
                            )
                    }
                }

                Text(tab.label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                    .tracking(0.2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(BCMotion.microSpring, value: isSelected)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme BetweenClasses -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add BetweenClasses/Views/Components/TabBarView.swift
git commit -m "feat(tabbar): liquid indicator dot with matchedGeometryEffect spring animation"
```

---

## Self-Review Notes

- Crystal shape `.star` used for `.complete` state — verify `QuizSessionState` has a `.complete` case (it does: `case complete(Int, Int)`). The `crystalShape` switch handles it. ✓
- `onChange(of:)` in `MorphingCrystalView` uses two-argument form (new in iOS 17) — project targets iOS 17+. ✓
- `matchedGeometryEffect` for the trail dot uses `isSource: false` — this makes it follow the source dot with the delayed animation, not compete with it. ✓
- `glowOpacity` animation in `NextClassCard` uses `.onAppear` — safe since the card stays mounted. ✓
- No placeholders. All code is complete. ✓
