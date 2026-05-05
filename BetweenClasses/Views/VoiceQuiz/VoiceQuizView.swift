import SwiftUI
import SwiftData

struct VoiceQuizView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State private var manager = QuizSessionManager()
    @State private var appeared = false
    @State private var organizerSubject: Subject?
    @State private var selectedLibraryNote: Note?

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

    /// Phase strip for the active session (pairs with `QuizSessionManager` status copy).
    private var livePhaseTitle: String {
        switch manager.state {
        case .speaking: return "Speaking"
        case .listening: return "Your turn"
        case .evaluating: return "Checking answer"
        default: return "Live"
        }
    }

    private var livePhaseChipBackground: Color {
        switch manager.state {
        case .listening: return Color.bcAccentMuted
        case .speaking: return Color.bcAccentSubtle
        case .evaluating: return Color.white.opacity(0.08)
        default: return Color.white.opacity(0.06)
        }
    }

    /// Avoids repeating the question in the footer while TTS reads it; still shows timeout / retry hints from the manager.
    private var sessionStatusFootnote: String? {
        guard !manager.statusLabel.isEmpty else { return nil }
        if case .evaluating = manager.state { return nil }
        if case .speaking = manager.state, let q = manager.currentQuestion {
            let a = manager.statusLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = q.question.trimmingCharacters(in: .whitespacesAndNewlines)
            if a == b {
                return "Playing the question — the mic opens when it’s your turn to answer."
            }
        }
        return manager.statusLabel
    }

    private var pulseSectionLabel: String {
        switch manager.state {
        case .listening: return "Listening"
        case .speaking: return "Audio"
        case .evaluating: return "Pause"
        default: return "Session"
        }
    }

    private var colorCodingRefreshToken: Bool {
        appState.colorCodingEnabled
    }

    var body: some View {
        let _ = colorCodingRefreshToken
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
        .safeAreaInset(edge: .top, spacing: BCSpacing.md) {
            BCChromeBar(title: appState.quizSubject == nil ? "Voice quiz library" : "Voice quiz session") {
                HStack(spacing: 14) {
                    if appState.quizSubject != nil {
                        Text(quizScopeSummary)
                            .bcCaption()
                            .foregroundStyle(Color.textSecond)
                            .lineLimit(1)
                    }
                    if appState.quizSubject != nil {
                        Button("Library") {
                            manager.stop()
                            manager.state = .idle
                            appState.clearQuizSelection()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.textSecond)
                    }
                }
            }
            .padding(.horizontal, BCSpacing.gutter)
        }
        .sheet(item: $organizerSubject) { subject in
            TopicOrganizerSheet(subject: subject)
        }
        .sheet(item: $selectedLibraryNote) { note in
            NoteDetailSheet(note: note, subjectName: subjects.first { $0.id == note.subjectID }?.name ?? "Note")
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
                    Text("Ready")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textSecond)
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .frame(maxWidth: .infinity)

                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 52, weight: .thin))
                        .foregroundStyle(Color.textPrimary)
                        .symbolRenderingMode(.hierarchical)

                    VStack(spacing: 6) {
                        Text(appState.quizSubject?.name ?? "Quiz")
                            .bcHeadline()
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(quizScopeSummary)
                            .bcCaption()
                            .foregroundStyle(Color.textTertiary)
                            .multilineTextAlignment(.center)
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
                        Text(manager.isPreparingQuiz ? "Preparing…" : "Start Quiz")
                    }
                    .buttonStyle(BCPrimaryButtonStyle(isEnabled: appState.quizSubject != nil && !manager.isPreparingQuiz))
                    .disabled(appState.quizSubject == nil || manager.isPreparingQuiz)
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
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Study library")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.textSecond)
                            .textCase(.uppercase)
                            .tracking(1.1)

                        Text("Voice Quiz")
                            .bcHeadline()
                            .foregroundStyle(Color.textPrimary)
                        Text("Pick a subject or topic, then run a live voice session. Use Schedule for class times and sync.")
                            .bcBody()
                            .foregroundStyle(Color.textSecond)
                    }
                }

                if subjects.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nothing to quiz yet")
                                .bcHeadline()
                                .foregroundStyle(Color.textPrimary)
                            Text("Connect Canvas on Schedule or capture notes — subjects appear here automatically.")
                                .bcBody()
                                .foregroundStyle(Color.textSecond)
                        }
                    }
                } else {
                    ForEach(subjects) { subject in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Button {
                                    appState.startQuiz(for: subject)
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Circle()
                                            .fill(subject.displayColor)
                                            .frame(width: 10, height: 10)
                                            .padding(.top, 4)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(subject.name)
                                                .bcHeadline()
                                                .foregroundStyle(Color.textPrimary)
                                            Text("\(subject.notes.count) notes • \(subject.notes.flatMap { $0.questions }.count) saved questions")
                                                .bcCaption()
                                                .foregroundStyle(Color.textTertiary)
                                            Text("Tap subject to quiz everything")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Color.textSecond)
                                        }
                                        Spacer()
                                        Image(systemName: "brain.head.profile")
                                            .foregroundStyle(Color.textSecond)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .padding(.bottom, 2)

                                HStack(spacing: 10) {
                                    Button("Quiz All") {
                                        appState.startQuiz(for: subject)
                                    }
                                    .buttonStyle(BCGhostButtonStyle())

                                    Button("Organize Topics") {
                                        organizerSubject = subject
                                    }
                                    .buttonStyle(BCGhostButtonStyle())
                                }

                                ForEach(subject.notesByTopic, id: \.topic) { entry in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Button {
                                            appState.startQuiz(for: subject, topicName: entry.topic)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Capsule()
                                                    .fill(subject.topicColor(for: entry.topic))
                                                    .frame(width: 12, height: 28)
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(entry.topic)
                                                        .bcBody()
                                                        .foregroundStyle(Color.textPrimary)
                                                    Text("\(entry.notes.count) note\(entry.notes.count == 1 ? "" : "s") • tap topic to quiz it")
                                                        .bcCaption()
                                                        .foregroundStyle(Color.textTertiary)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(Color.textTertiary)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.plain)

                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(entry.notes.prefix(4)) { note in
                                                HStack(spacing: 10) {
                                                    Button {
                                                        selectedLibraryNote = note
                                                    } label: {
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            Text(note.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled note" : String(note.extractedText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(72)))
                                                                .font(.system(size: 13, weight: .medium))
                                                                .foregroundStyle(Color.textPrimary)
                                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                                .lineLimit(2)
                                                            Text(note.questions.isEmpty ? "Tap note to open • quiz builds live" : "Tap note to open • \(note.questions.count) saved question\(note.questions.count == 1 ? "" : "s")")
                                                                .bcCaption()
                                                                .foregroundStyle(Color.textTertiary)
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 10)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .background(subject.noteColor(for: entry.topic).opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                                .stroke(subject.noteColor(for: entry.topic).opacity(0.24), lineWidth: 1)
                                                        )
                                                    }
                                                    .buttonStyle(.plain)

                                                    Button {
                                                        appState.startQuiz(for: subject, topicName: entry.topic, noteIDs: [note.id])
                                                    } label: {
                                                        Image(systemName: "play.fill")
                                                            .font(.system(size: 12, weight: .bold))
                                                            .foregroundStyle(Color.textPrimary)
                                                            .frame(width: 34, height: 34)
                                                            .background(subject.topicColor(for: entry.topic).opacity(0.24), in: RoundedRectangle(cornerRadius: 10))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .accessibilityLabel("Quiz this note")
                                                }
                                            }
                                            if entry.notes.count > 4 {
                                                Text("+ \(entry.notes.count - 4) more note\(entry.notes.count - 4 == 1 ? "" : "s") in \(entry.topic)")
                                                    .bcCaption()
                                                    .foregroundStyle(Color.textTertiary)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(subject.topicColor(for: entry.topic).opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(subject.topicColor(for: entry.topic).opacity(0.18), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    private var noContentView: some View {
        let subjectName = appState.quizSubject?.name ?? "this subject"
        return VStack(spacing: 32) {
            Spacer()
            GlassCard {
                VStack(spacing: 20) {
                    Text("Needs material")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.textSecond)
                        .textCase(.uppercase)
                        .tracking(1.1)

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(Color.textTertiary)
                    Text("No notes for \(subjectName)")
                        .bcHeadline()
                        .foregroundStyle(Color.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Capture a few notes for this class first. The quiz builds from what you saved.")
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
                VStack(alignment: .leading, spacing: BCSpacing.sm) {
                    HStack(alignment: .center, spacing: 10) {
                        Text(livePhaseTitle.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.bcAccent)
                            .tracking(0.9)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(livePhaseChipBackground, in: Capsule(style: .continuous))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.bcAccent.opacity(0.22), lineWidth: 1)
                            )

                        Spacer(minLength: 8)

                        if manager.questions.count > 0 {
                            Text("Q \(manager.currentIndex + 1) / \(manager.questions.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.textSecond)
                                .tracking(0.6)
                        }
                    }

                    HStack {
                        Text(appState.quizSubject?.name ?? "Quiz")
                            .bcCaption()
                            .foregroundStyle(Color.textSecond)
                            .lineLimit(1)
                        Spacer()
                    }
                }
                .padding(.horizontal, BCSpacing.xl)
                .padding(.top, BCSpacing.xl)
                .padding(.bottom, BCSpacing.lg)

                Divider()
                    .background(Color.glassStroke)

                VStack(spacing: 8) {
                    Text("Current question")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .padding(.top, BCSpacing.md)

                    if let q = manager.currentQuestion {
                        Text(q.question)
                            .bcHeadline()
                            .foregroundStyle(Color.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, BCSpacing.xl)
                            .padding(.bottom, 28)
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                            .id(q.id)
                    } else {
                        Text("Preparing quiz…")
                            .bcHeadline()
                            .foregroundStyle(Color.textSecond)
                            .padding(28)
                    }

                    if case .evaluating = manager.state {
                        Text("Scoring what you said…")
                            .bcCaption()
                            .foregroundStyle(Color.textTertiary)
                            .padding(.bottom, 8)
                    }
                }
                .animation(BCMotion.gentleEase, value: manager.currentQuestion?.id)

                Divider()
                    .background(Color.glassStroke)

                VStack(spacing: BCSpacing.sm) {
                    Text(pulseSectionLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    PulseRing(isListening: isListening, size: 52)
                }
                .padding(.vertical, BCSpacing.xl)
            }
            .glassCard()
            .padding(.horizontal, BCSpacing.xxl)
            .offset(y: appeared ? 0 : 30)
            .opacity(appeared ? 1 : 0)
            .animation(BCMotion.panelSpring, value: appeared)

            WaveformView(amplitude: amplitude)
                .frame(height: 40)
                .padding(.horizontal, 40)
                .opacity(amplitude > 0 ? 1 : 0.28)
                .animation(BCMotion.gentleEase, value: amplitude)

            if let foot = sessionStatusFootnote {
                Text(foot)
                    .bcCaption()
                    .foregroundStyle(Color.textSecond)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
            }

            if let err = manager.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                    Text(err)
                        .bcCaption()
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(Color.textPrimary.opacity(0.92))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous)
                        .strokeBorder(Color.bcAccent.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal, BCSpacing.xxl)
            }

            if let transport = manager.sessionTransportNote {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                    Text(transport)
                        .bcCaption()
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.top, 4)
            }

            Spacer()

            Button("End session") {
                manager.stop()
                appState.clearQuizSelection()
                appState.selectedTab = .home
            }
            .buttonStyle(BCGhostButtonStyle())
            .padding(.bottom, BCSpacing.xl)
        }
    }
}

private struct TopicOrganizerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let subject: Subject

    @State private var pendingRenameTopic: String?
    @State private var renameDraft: String = ""
    @State private var editMode: EditMode = .active
    @State private var refreshTick = 0

    var body: some View {
        NavigationStack {
            List {
                let topicEntries = {
                    _ = refreshTick
                    return subject.notesByTopic
                }()
                Section {
                    ForEach(topicEntries, id: \.topic) { entry in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.topic)
                                    .bcBody()
                                    .foregroundStyle(Color.textPrimary)
                                Text("\(entry.notes.count) note\(entry.notes.count == 1 ? "" : "s")")
                                    .bcCaption()
                                    .foregroundStyle(Color.textTertiary)
                            }
                            Spacer()
                            Button("Rename") {
                                pendingRenameTopic = entry.topic
                                renameDraft = entry.topic == "Unsorted" ? "" : entry.topic
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.textSecond)
                        }
                        .listRowBackground(Color.bgPrimary)
                    }
                    .onMove { fromOffsets, toOffset in
                        subject.moveTopics(fromOffsets: fromOffsets, toOffset: toOffset)
                        refreshTick += 1
                    }
                } header: {
                    Text("Drag to reorder. Rename \"Unsorted\" when you finally know what the notes actually are.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .environment(\.editMode, $editMode)
            .navigationTitle(subject.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.textSecond)
                }
            }
            .alert("Rename Topic", isPresented: Binding(
                get: { pendingRenameTopic != nil },
                set: { if !$0 { pendingRenameTopic = nil } }
            )) {
                TextField("Topic name", text: $renameDraft)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {
                    pendingRenameTopic = nil
                    renameDraft = ""
                }
                Button("Save") {
                    if let original = pendingRenameTopic {
                        subject.renameTopic(from: original, to: renameDraft)
                        refreshTick += 1
                    }
                    pendingRenameTopic = nil
                    renameDraft = ""
                }
            } message: {
                Text("This renames the topic across every note in \(subject.name).")
            }
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
