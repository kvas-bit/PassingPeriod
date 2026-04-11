import SwiftUI

// MARK: - Press button style

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(BCMotion.microSpring, value: configuration.isPressed)
    }
}

// MARK: - NoteCardView

struct NoteCardView: View {
    let note: Note
    let subjects: [Subject]

    @State private var showDetail = false

    private var subjectName: String {
        subjects.first { $0.id == note.subjectID }?.name ?? "Unknown"
    }

    private var relativeTime: String {
        let seconds = Date().timeIntervalSince(note.createdAt)
        let minutes = Int(seconds / 60)
        let hours   = Int(seconds / 3600)
        let days    = Int(seconds / 86400)
        if minutes < 60 { return "\(max(1, minutes))m ago" }
        if hours   < 24 { return "\(hours)h ago" }
        if days    == 1 { return "Yesterday" }
        return "\(days)d ago"
    }

    private var topicName: String {
        let trimmed = note.topicName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unsorted" : trimmed
    }

    private var questionBadge: String {
        note.questions.isEmpty ? "No quiz" : "\(note.questions.count) Q"
    }

    private var previewText: String {
        let trimmed = note.extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 { return trimmed }
        return String(trimmed.prefix(80)) + "…"
    }

    var body: some View {
        Button { showDetail = true } label: {
            VStack(alignment: .leading, spacing: 8) {

                // Subject + time row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(subjectName)
                            .bcCaption()
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Text(topicName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(relativeTime)
                        .bcCaption()
                        .foregroundStyle(Color.textTertiary)
                }

                // Preview text
                if !previewText.isEmpty {
                    Text(previewText)
                        .font(.bcCaption)
                        .fontWeight(.regular)
                        .foregroundStyle(Color.textSecond)
                        .lineLimit(3)
                        .tracking(0.2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                // Question count badge
                Text(questionBadge)
                    .font(.bcCaption)
                    .fontWeight(.semibold)
                    .tracking(0.3)
                    .foregroundStyle(note.questions.isEmpty ? Color.textTertiary : Color.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(note.questions.isEmpty
                                  ? Color.white.opacity(0.05)
                                  : Color.white.opacity(0.12))
                    )
            }
            .padding(12)
            .frame(minWidth: 160, minHeight: 100, alignment: .topLeading)
            .glassCard(cornerRadius: BCRadius.card)
        }
        .buttonStyle(PressButtonStyle())
        .sheet(isPresented: $showDetail) {
            NoteDetailSheet(note: note, subjectName: subjectName)
        }
    }
}

// MARK: - Note detail sheet

struct NoteDetailSheet: View {
    let note: Note
    let subjectName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Photo if available
                        if let data = note.imageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.glassStroke, lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Topic")
                                .bcCaption()
                                .foregroundStyle(Color.textSecond)
                                .textCase(.uppercase)

                            Text(note.topicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unsorted" : note.topicName)
                                .bcBody()
                                .foregroundStyle(Color.textPrimary)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard()
                        }

                        // Full note text
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .bcCaption()
                                .foregroundStyle(Color.textSecond)
                                .textCase(.uppercase)

                            Text(note.extractedText)
                                .bcBody()
                                .foregroundStyle(Color.textPrimary)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassCard()
                        }

                        // Questions list
                        if !note.questions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Quiz Questions (\(note.questions.count))")
                                    .bcCaption()
                                    .foregroundStyle(Color.textSecond)
                                    .textCase(.uppercase)

                                ForEach(note.questions) { question in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(question.question)
                                            .bcBody()
                                            .foregroundStyle(Color.textPrimary)
                                        Text(question.expectedAnswer)
                                            .bcCaption()
                                            .foregroundStyle(Color.textSecond)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .glassCard(cornerRadius: 12)
                                }
                            }
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Color.textTertiary)
                                Text("No questions yet")
                                    .bcCaption()
                                    .foregroundStyle(Color.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }

                        // Metadata
                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .bcCaption()
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(subjectName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.textSecond)
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        }
    }
}
