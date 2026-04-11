import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var showConnect = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / wordmark
                VStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(.white)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: appeared)

                    Text("Between Classes")
                        .bcDisplay()
                        .foregroundStyle(.textPrimary)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: appeared)

                    Text("Active recall. Hands-free.")
                        .bcBody()
                        .foregroundStyle(.textSecond)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.25), value: appeared)
                }

                Spacer()

                // Feature bullets
                VStack(spacing: 16) {
                    FeatureRow(icon: "camera.fill",      text: "Snap your notes after class")
                    FeatureRow(icon: "waveform",         text: "Get quizzed by voice between classes")
                    FeatureRow(icon: "airpodspro",       text: "AirPods in, phone in pocket")
                    FeatureRow(icon: "circle.hexagongrid.fill", text: "Visualize your knowledge graph")
                }
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.35), value: appeared)

                Spacer()

                // CTA
                VStack(spacing: 12) {
                    Button {
                        showConnect = true
                    } label: {
                        Text("Connect Canvas")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    Button {
                        appState.completeOnboarding()
                    } label: {
                        Text("Skip for now")
                            .bcBody()
                            .foregroundStyle(.textSecond)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.45), value: appeared)
            }
        }
        .sheet(isPresented: $showConnect) {
            CanvasConnectView()
        }
        .onAppear { appeared = true }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 32)
            Text(text)
                .bcBody()
                .foregroundStyle(.textPrimary)
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
