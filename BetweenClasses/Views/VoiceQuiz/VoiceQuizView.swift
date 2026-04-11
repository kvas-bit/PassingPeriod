import SwiftUI
import SwiftData

struct VoiceQuizView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var manager = QuizSessionManager()
    @State private var appeared = false
    @State private var showScore = false

    private var isListening: Bool {
        if case .listening = manager.state { return true }
        return false
    }

    private var amplitude: Float {
        switch manager.state {
        case .speaking:   return manager.ttsAmplitude
        case .listening:  return manager.micAmplitude
        default:          return 0
        }
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            if case .complete(let score, let total) = manager.state {
                ScoreCard(score: score, total: total) {
                    appState.showQuiz = false
                    appState.selectedTab = .home
                    manager.state = .idle
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if case .noContent = manager.state {
                noContentView
                    .transition(.opacity)
            } else if case .idle = manager.state {
                readyView
                    .transition(.opacity)
            } else {
                quizContent
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            manager.configure(modelContext: modelContext)
            appeared = true
            // Do NOT auto-start — user must tap Start to avoid wasting API calls
        }
        .onDisappear {
            manager.stop()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: appeared)
    }

    private var readyView: some View {
        VStack(spacing: 32) {
            Spacer()
            GlassCard {
                VStack(spacing: 20) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 52, weight: .thin))
                        .foregroundStyle(Color.textPrimary)

                    VStack(spacing: 6) {
                        Text(appState.quizSubject?.name ?? "Quiz")
                            .bcHeadline()
                            .foregroundStyle(Color.textPrimary)
                        let qCount = appState.quizSubject?.notes.flatMap { $0.questions }.count ?? 0
                        Text(qCount > 0 ? "\(min(qCount, 5)) questions" : "No questions yet")
                            .bcBody()
                            .foregroundStyle(Color.textSecond)
                    }

                    Button {
                        if let subject = appState.quizSubject {
                            Task { await manager.start(subject: subject) }
                        }
                    } label: {
                        Text("Start Quiz")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.quizSubject == nil)
                }
            }
            .padding(.horizontal, 24)
            .offset(y: appeared ? 0 : 30)
            .opacity(appeared ? 1 : 0)

            Button("Back") {
                appState.selectedTab = .home
            }
            .bcCaption()
            .foregroundStyle(Color.textSecond)
            .padding(.bottom, 40)

            Spacer()
        }
    }

    private var noContentView: some View {
        VStack(spacing: 32) {
            Spacer()
            GlassCard {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.textTertiary)
                    Text("No Notes Yet")
                        .bcHeadline()
                        .foregroundStyle(Color.textPrimary)
                    Text("Capture notes from class first, then come back to quiz yourself.")
                        .bcBody()
                        .foregroundStyle(Color.textSecond)
                        .multilineTextAlignment(.center)
                    Button("Capture Notes") {
                        appState.selectedTab = .capture
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private var quizContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // Main glass card
            VStack(spacing: 0) {
                // Header
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
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider()
                    .background(Color.glassStroke)

                // Question text
                VStack {
                    if let q = manager.currentQuestion {
                        Text(q.question)
                            .bcHeadline()
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 28)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                            .id(q.id)
                    } else {
                        Text(manager.state == .idle ? "Preparing quiz…" : "…")
                            .bcHeadline()
                            .foregroundStyle(Color.textSecond)
                            .padding(28)
                    }
                }

                Divider()
                    .background(Color.glassStroke)

                // Pulse ring
                PulseRing(isListening: isListening, size: 48)
                    .padding(.vertical, 24)
            }
            .glassCard()
            .padding(.horizontal, 24)
            .offset(y: appeared ? 0 : 30)
            .opacity(appeared ? 1 : 0)

            // Waveform
            WaveformView(amplitude: amplitude)
                .frame(height: 40)
                .padding(.horizontal, 40)
                .opacity(amplitude > 0 ? 1 : 0.3)
                .animation(.easeInOut(duration: 0.2), value: amplitude)

            // Status label
            Text(manager.statusLabel)
                .bcCaption()
                .foregroundStyle(Color.textSecond)
                .opacity(manager.statusLabel.isEmpty ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: manager.statusLabel)

            Spacer()

            // End session button
            Button("End Session") {
                manager.stop()
                appState.selectedTab = .home
            }
            .bcCaption()
            .foregroundStyle(Color.textSecond)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Score Card

private struct ScoreCard: View {
    let score: Int
    let total: Int
    let onDone: () -> Void

    @State private var appeared = false

    var percentage: Double {
        total > 0 ? Double(score) / Double(total) : 0
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            GlassCard {
                VStack(spacing: 20) {
                    Text(percentage >= 0.6 ? "🎉" : "📖")
                        .font(.system(size: 48))

                    Text("\(score) / \(total)")
                        .bcDisplay()
                        .foregroundStyle(Color.textPrimary)

                    Text(percentage >= 0.8 ? "Excellent work!" :
                         percentage >= 0.6 ? "Good session!" : "Keep reviewing!")
                        .bcBody()
                        .foregroundStyle(Color.textSecond)

                    Button("Done") { onDone() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .offset(y: appeared ? 0 : 60)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: appeared)

            Spacer()
        }
        .onAppear { appeared = true }
    }
}

#Preview {
    VoiceQuizView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
