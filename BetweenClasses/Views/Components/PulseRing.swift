import SwiftUI

/// Animated ring that pulses when mic is active, flat when idle/speaking.
struct PulseRing: View {
    var isListening: Bool
    var size: CGFloat = 48

    @State private var pulse = false

    var body: some View {
        ZStack {
            // Outer pulse ring (only when listening)
            if isListening {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: size * 1.5, height: size * 1.5)
                    .scaleEffect(pulse ? 1.2 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(
                        .easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                        value: pulse
                    )

                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: size * 1.9, height: size * 1.9)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .opacity(pulse ? 0 : 0.3)
                    .animation(
                        .easeInOut(duration: 1.0).delay(0.2).repeatForever(autoreverses: false),
                        value: pulse
                    )
            }

            // Core ring
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: size, height: size)

            // Center mic icon
            Image(systemName: isListening ? "mic.fill" : "speaker.wave.2.fill")
                .font(.system(size: size * 0.35, weight: .medium))
                .foregroundStyle(.white)
        }
        .onAppear {
            if isListening { pulse = true }
        }
        .onChange(of: isListening) { _, listening in
            pulse = listening
        }
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        VStack(spacing: 40) {
            PulseRing(isListening: true)
            PulseRing(isListening: false)
        }
    }
}
