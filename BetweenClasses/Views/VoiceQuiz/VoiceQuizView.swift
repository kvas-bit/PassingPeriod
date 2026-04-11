import SwiftUI
import SwiftData

struct VoiceQuizView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var manager = QuizSessionManager()
    @State private var appeared = false

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

            Group {
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
                        .transition(.opacity)
                }
            }
            .animation(BCMotion.panelSpring, value: manager.state)
        }
        .onAppear {
            manager.configure(modelContext: modelContext)
            appeared = true
        }
        .onDisappear {
            manager.stop()
        }
    }

    private var readyView: some View {
        VStack(spacing: 32) {
            Spacer()
            GlassCard {
                VStack(spacing: 20) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 52, weight: .thin))
                        .foregroundStyle(Color.textPrimary)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 6) {
                        Text(appState.quizSubject?.name ?? "Quiz")
                            .bcHeadline()
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                        let qCount = appState.quizSubject?.notes.flatMap { $0.questions }.count ?? 0
                        let hasNoteText = appState.quizSubject?.notes.contains { !$0.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
                        if qCount > 0 {
                            Text("\(min(qCount, 5)) questions ready")
                                .bcBody()
                                .foregroundStyle(Color.textSecond)
                        } else if hasNoteText {
                            Text("Will generate questions from your notes")
                                .bcBody()
                                .foregroundStyle(Color.textSecond)
                        } else {
                            Text("No questions yet — capture notes first")
                                .bcBody()
                                .foregroundStyle(Color.textSecond)
                        }
                    }

                    if let err = manager.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13))
                            Text(err)
                                .bcCaption()
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(Color.textPrimary.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }

                    Button {
                        if let subject = appState.quizSubject {
                            Task { await manager.start(subject: subject) }
                        }
                    } label: {
                        Text("Start Quiz")
                    }
                    .buttonStyle(BCPrimaryButtonStyle(isEnabled: appState.quizSubject != nil))
                    .disabled(appState.quizSubject == nil)
                }
            }
            .padding(.horizontal, BCSpacing.xxl)
            .offset(y: appeared ? 0 : 30)
            .opacity(appeared ? 1 : 0)
            .animation(BCMotion.panelSpring, value: appeared)

            Button("Back") {
                appState.selectedTab = .home
            }
            .buttonStyle(BCGhostButtonStyle())
            .padding(.bottom, BCSpacing.xl)

            Spacer()
        }
    }

    private var noContentView: some View {
        let subjectName = appState.quizSubject?.name ?? "this subject"
        return VStack(spacing: 32) {
            Spacer()
            GlassCard {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(Color.textTertiary)
                    Text("No notes for \(subjectName)")
                        .bcHeadline()
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Capture notes from \(subjectName) first, then come back to quiz yourself.")
                        .bcBody()
                        .foregroundStyle(Color.textSecond)
                        .multilineTextAlignment(.center)
                    Button("Capture notes") {
                        appState.selectedTab = .capture
                    }
                    .buttonStyle(BCPrimaryButtonStyle())

                    Button("Back") {
                        manager.state = .idle
                    }
                    .buttonStyle(BCGhostButtonStyle())
                }
            }
            .padding(.horizontal, BCSpacing.xxl)
            Spacer()
        }
    }

    private var quizContent: some View {
        VStack(spacing: 32) {
            Spacer()

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

                Divider()
                    .background(Color.glassStroke)

                VStack(spacing: 8) {
                    if let q = manager.currentQuestion {
                        Text(q.question)
                            .bcHeadline()
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, BCSpacing.xl)
                            .padding(.vertical, 28)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                            .id(q.id)
                    } else {
                        Text("Preparing quiz…")
                            .bcHeadline()
                            .foregroundStyle(Color.textSecond)
                            .padding(28)
                    }

                    if case .evaluating = manager.state {
                        Text("Evaluating your answer…")
                            .bcCaption()
                            .foregroundStyle(Color.textTertiary)
                            .padding(.bottom, 8)
                    }
                }
                .animation(BCMotion.gentleEase, value: manager.currentQuestion?.id)

                Divider()
                    .background(Color.glassStroke)

                PulseRing(isListening: isListening, size: 48)
                    .padding(.vertical, BCSpacing.xxl)
            }
            .glassCard()
            .padding(.horizontal, BCSpacing.xxl)
            .offset(y: appeared ? 0 : 30)
            .opacity(appeared ? 1 : 0)
            .animation(BCMotion.panelSpring, value: appeared)

            WaveformView(amplitude: amplitude)
                .frame(height: 40)
                .padding(.horizontal, 40)
                .opacity(amplitude > 0 ? 1 : 0.3)
                .animation(BCMotion.gentleEase, value: amplitude)

            Text(manager.statusLabel)
                .bcCaption()
                .foregroundStyle(Color.textSecond)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(manager.statusLabel.isEmpty ? 0 : 1)
                .animation(BCMotion.gentleEase, value: manager.statusLabel)

            Spacer()

            Button("End session") {
                manager.stop()
                appState.selectedTab = .home
            }
            .buttonStyle(BCGhostButtonStyle())
            .padding(.bottom, BCSpacing.xl)
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
                    Image(systemName: percentage >= 0.6 ? "checkmark.seal.fill" : "book.pages.fill")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundStyle(Color.textPrimary)
                        .symbolRenderingMode(.hierarchical)

                    Text("\(score) / \(total)")
                        .bcDisplay()
                        .foregroundStyle(Color.textPrimary)

                    Text(percentage >= 0.8 ? "Excellent work" :
                         percentage >= 0.6 ? "Solid session" : "Keep reviewing")
                        .bcBody()
                        .foregroundStyle(Color.textSecond)

                    Button("Done") { onDone() }
                        .buttonStyle(BCPrimaryButtonStyle())
                }
            }
            .padding(.horizontal, BCSpacing.xxl)
            .offset(y: appeared ? 0 : 60)
            .opacity(appeared ? 1 : 0)
            .animation(BCMotion.panelSpring, value: appeared)

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
