import SwiftUI
import SwiftData

struct VoiceQuizView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]

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

    private var quizScopeSummary: String {
        if !appState.quizNoteIDs.isEmpty {
            return "\(appState.quizNoteIDs.count) selected note\(appState.quizNoteIDs.count == 1 ? "" : "s")"
        }
        if let topic = appState.quizTopicName, !topic.isEmpty {
            return topic
        }
        return appState.quizSubject?.name ?? "Quiz"
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            Group {
                if case .complete(let score, let total) = manager.state {
                    ScoreCard(score: score, total: total) {
                        appState.selectedTab = .home
                        appState.clearQuizSelection()
                        manager.state = .idle
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if case .noContent = manager.state {
                    noContentView
                        .transition(.opacity)
                } else if appState.quizSubject == nil {
                    quizLibraryView
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
                        Text(quizScopeSummary)
                            .bcCaption()
                            .foregroundStyle(Color.textTertiary)
                        let scopedNotes: [Note] = {
                            guard let subject = appState.quizSubject else { return [] }
                            if !appState.quizNoteIDs.isEmpty {
                                let noteIDSet = Set(appState.quizNoteIDs)
                                return subject.notes.filter { noteIDSet.contains($0.id) }
                            }
                            if let topic = appState.quizTopicName, !topic.isEmpty {
                                return subject.notes.filter {
                                    $0.topicName.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(topic) == .orderedSame
                                }
                            }
                            return subject.notes
                        }()
                        let qCount = scopedNotes.flatMap { $0.questions }.count
                        let hasNoteText = scopedNotes.contains { !$0.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                        if qCount > 0 {
                            Text("\(min(qCount, 5)) questions ready")
                                .bcBody()
                                .foregroundStyle(Color.textSecond)
                        } else if hasNoteText {
                            Text("Will generate questions from this study set")
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
                            Task {
                                await manager.start(
                                    subject: subject,
                                    topicName: appState.quizTopicName,
                                    noteIDs: appState.quizNoteIDs
                                )
                            }
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

            Button("Choose Different Quiz") {
                manager.stop()
                appState.clearQuizSelection()
            }
            .buttonStyle(BCGhostButtonStyle())
            .padding(.bottom, BCSpacing.xl)

            Spacer()
        }
    }

    private var quizLibraryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quiz Library")
                        .bcHeadline()
                        .foregroundStyle(Color.textPrimary)
                    Text("Pick a subject, topic, or single note. Stop burying quiz start behind another screen.")
                        .bcBody()
                        .foregroundStyle(Color.textSecond)
                }

                if subjects.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No subjects yet")
                                .bcHeadline()
                                .foregroundStyle(Color.textPrimary)
                            Text("Connect Canvas or capture notes first.")
                                .bcBody()
                                .foregroundStyle(Color.textSecond)
                        }
                    }
                } else {
                    ForEach(subjects) { subject in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(subject.name)
                                            .bcHeadline()
                                            .foregroundStyle(Color.textPrimary)
                                        Text("\(subject.notes.count) notes • \(subject.notes.flatMap { $0.questions }.count) saved questions")
                                            .bcCaption()
                                            .foregroundStyle(Color.textTertiary)
                                    }
                                    Spacer()
                                    Button("Quiz All") {
                                        appState.startQuiz(for: subject)
                                    }
                                    .buttonStyle(BCGhostButtonStyle())
                                }

                                ForEach(subject.notesByTopic, id: \.topic) { entry in
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(entry.topic)
                                                    .bcBody()
                                                    .foregroundStyle(Color.textPrimary)
                                                Text("\(entry.notes.count) note\(entry.notes.count == 1 ? "" : "s")")
                                                    .bcCaption()
                                                    .foregroundStyle(Color.textTertiary)
                                            }
                                            Spacer()
                                            Button("Quiz Topic") {
                                                appState.startQuiz(for: subject, topicName: entry.topic)
                                            }
                                            .buttonStyle(BCGhostButtonStyle())
                                        }

                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(entry.notes.prefix(3)) { note in
                                                Button {
                                                    appState.startQuiz(for: subject, topicName: entry.topic, noteIDs: [note.id])
                                                } label: {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(note.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled note" : String(note.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(72)))
                                                            .font(.system(size: 13, weight: .medium))
                                                            .foregroundStyle(Color.textPrimary)
                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                            .lineLimit(2)
                                                        Text(note.questions.isEmpty ? "Will generate live from this note" : "\(note.questions.count) saved question\(note.questions.count == 1 ? "" : "s")")
                                                            .bcCaption()
                                                            .foregroundStyle(Color.textTertiary)
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 10)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            if entry.notes.count > 3 {
                                                Text("+ \(entry.notes.count - 3) more note\(entry.notes.count - 3 == 1 ? "" : "s") in \(entry.topic)")
                                                    .bcCaption()
                                                    .foregroundStyle(Color.textTertiary)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
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

                    Button("Choose Different Quiz") {
                        manager.state = .idle
                        appState.clearQuizSelection()
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
