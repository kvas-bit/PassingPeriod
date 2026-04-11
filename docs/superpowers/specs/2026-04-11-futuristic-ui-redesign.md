# Between Classes — Futuristic UI Redesign Spec
**Date:** 2026-04-11
**Approach:** A — Focused Elevation
**Status:** Approved for implementation

---

## Aesthetic Identity

**Monochrome refractive** — no accent color. Identity comes entirely from how white light interacts with dark surfaces:
- Crystalline facets with sharp specular highlights
- Iridescent shimmer: surfaces shift between barely-visible spectral hues (blue→purple→green) depending on angle, like oil on glass
- Base palette unchanged: `#08090a` bg, `#0f1011` surface, `#191a1b` elevated

The reference: B+C from the visual brainstorm — crystalline geometry + iridescent oil-slick shimmer.

---

## Voice Quiz Screen (biggest change)

### The Morphing Crystal
A 3D SceneKit node centered on screen. Base geometry: `SCNSphere` with subdivided vertex buffer (~56×56 segments). Each frame, vertices are displaced along their unit-direction vectors using the formula:

```
r = lerp(fromRadius, toRadius, ease(morphT))
  + liquidEnvelope * sinNoise(nx, ny, nz, time)
```

Where `liquidEnvelope = amplitude * sin(morphT * π)` — zero when the shape is settled, peaks at mid-transition. This makes each shape land cleanly geometric while the transition itself goes fully liquid.

**Shape per state:**
| State | Shape cycle |
|-------|-------------|
| Listening | gem → sphere → diamond → cube (auto-cycles ~2.5s) |
| AI Speaking | tall diamond |
| Evaluating | rounded cube |
| Correct | star burst |

**Material:** `SCNMaterial` with physically-based rendering:
- `diffuse.contents = UIColor(hex: "#1a1d28")`
- `roughness.contents = 0.04`, `metalness.contents = 0.55`
- No custom shader needed — iridescence comes from 4 colored `SCNLight` nodes (indigo, violet, teal, warm-white) bouncing off the metallic surface at different angles

**Iridescent ambient glow:** `RadialGradient` SwiftUI view behind the SceneKit canvas. Rotates via `AngularGradient` conic gradient over 12s. Colors: `rgba(200,215,255,0.12)` → `rgba(255,240,255,0.08)` → `rgba(210,255,240,0.10)` → transparent.

**Orbit rings:** Two `Circle` strokes in SwiftUI, counter-rotating at different speeds, `opacity(0.06)` white, `strokeBorder` 1pt. Reinforce the 3D feel.

### Layout
- Full-screen `#08090a` background — no `GlassCard` wrapper
- Iridescent 1pt divider lines top and bottom (animated `LinearGradient`)
- Subject name + Q counter in top chrome (9px, letter-spaced)
- Crystal centered vertically, ~110pt bounding box
- Waveform bars below (iridescent gradient fill, animated scaleY)
- State chip below waveform (`LISTENING` / `AI SPEAKING` / `EVALUATING` / `CORRECT`)
- "End session" ghost button at bottom

### SwiftUI Implementation Path
- `SCNView` wrapped in `UIViewRepresentable`
- `SCNSceneRendererDelegate.renderer(_:updateAtTime:)` updates vertex buffer each frame
- Shape state driven by `QuizSessionManager.state` via `@Published`
- Morph start captured as `fromRadius` snapshot; destination set as `toRadius` array

---

## Home Screen

### Next Class Card
- Existing `GlassCard` + `NextClassCard` structure preserved
- Add iridescent border: replace static `glassStroke` with animated `AngularGradient` stroke
  - Colors: `white.opacity(0.30)` → `rgba(185,205,255,0.25)` → `rgba(215,185,255,0.20)` → `rgba(185,255,215,0.25)` → `white.opacity(0.30)`
  - Rotates 360° over 8s with `.animation(.linear(duration: 8).repeatForever(autoreverses: false))`
  - Implemented as overlay on the `RoundedRectangle` border

- Ambient glow: `RadialGradient` from `white.opacity(0.04)` to transparent, behind the card, animates `opacity` 0.5↔1.0 at 0.8Hz (gentle breathe)

### Subject Cards (horizontal scroll)
- Same iridescent border treatment as Next Class card
- No other changes

### Quick Stats Chips
- No changes

---

## Tab Bar

### Liquid Indicator
Replace the white opacity blob (current selected state) with:
- A bright white dot (`Circle`, 5pt) that slides between tab positions using `.matchedGeometryEffect` with a `spring(response: 0.38, dampingFraction: 0.72)` animation
- Comet trail: a second dot at 20% opacity that follows with a 0.08s delay, giving a brief smear
- Active icon uses `.semibold` weight (unchanged); dot appears below the icon

---

## Design Token Additions

```swift
// In BCDesignSystem.swift or Color+Theme.swift

// Iridescent gradient for card borders
extension LinearGradient {
    static let iridBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.28),
            Color(red: 0.73, green: 0.80, blue: 1.0).opacity(0.22),
            Color(red: 0.84, green: 0.72, blue: 1.0).opacity(0.18),
            Color(red: 0.73, green: 1.0, blue: 0.84).opacity(0.22),
            Color.white.opacity(0.28),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// Ambient glow color for card backs
extension Color {
    static let ambientGlow = Color.white.opacity(0.04)
}
```

---

## What Does NOT Change
- `BCSpacing`, `BCRadius`, `BCMotion` tokens — unchanged
- `GlassCard` base component — unchanged (iridescent border is additive overlay)
- `ScheduleView`, `NoteCaptureView`, `OnboardingView` — out of scope
- Knowledge graph — already impressive, no changes

---

## Implementation Order
1. Voice quiz crystal (SceneKit + vertex morph) — biggest impact, do first
2. Next Class card iridescent border + ambient glow
3. Tab bar liquid indicator dot
4. Subject card iridescent borders
