import SwiftUI

struct WaveformView: View {
    var amplitude: Float   // 0–1, drives bar heights
    var barCount: Int = 20
    var color: Color = .white

    @State private var randomPhases: [Double] = []

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { i in
                WaveformBar(
                    amplitude: amplitude,
                    phase: randomPhases[safe: i] ?? Double(i) * 0.3,
                    color: color
                )
            }
        }
        .onAppear {
            if randomPhases.isEmpty {
                randomPhases = (0..<barCount).map { _ in Double.random(in: 0...1) }
            }
        }
    }
}

private struct WaveformBar: View {
    var amplitude: Float
    var phase: Double
    var color: Color

    @State private var animating = false

    private var height: CGFloat {
        let base: CGFloat = 4
        let max: CGFloat = 32
        let noise = CGFloat(sin(phase * .pi))
        let driven = CGFloat(amplitude) * max * (0.6 + 0.4 * noise)
        return max(base, driven)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(0.7 + Double(amplitude) * 0.3))
            .frame(width: 2, height: height)
            .animation(.easeInOut(duration: 0.08), value: amplitude)
    }
}
