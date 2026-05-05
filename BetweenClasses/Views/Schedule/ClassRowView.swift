import SwiftUI

struct ClassRowView: View {
    let subject: Subject
    @Environment(AppState.self) private var appState
    @State private var showDetail = false

    private var subjectAccent: Color {
        _ = appState.colorCodingEnabled
        return subject.displayColor
    }

    private var isFreeNow: Bool { subject.isFreeWindow }
    private var isHappeningNow: Bool {
        subject.scheduleTimes.contains { $0.isHappeningNow() }
    }

    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(subjectAccent)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(subject.name)
                        .bcBody()
                        .foregroundStyle(Color.textPrimary)

                    if let ct = subject.nextClassTime {
                        Text(ct.displayTime)
                            .bcCaption()
                            .foregroundStyle(Color.textSecond)
                    }
                }

                Spacer()

                if isHappeningNow {
                    WhitePill(text: "Now", prominent: true)
                } else if isFreeNow {
                    WhitePill(text: "Free now")
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.textSecond.opacity(0.55))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, BCSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: BCRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: BCRadius.card, style: .continuous)
                    .stroke(subjectAccent.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            SubjectDetailSheet(subject: subject)
        }
    }
}

// MARK: - Subject detail sheet

private struct SubjectDetailSheet: View {
    let subject: Subject
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showAddNote = false
    @State private var draftText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Notes list
                        if subject.notes.isEmpty {
                            GlassCard {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Color.textTertiary)
                                    Text("No notes yet")
                                        .bcBody()
                                        .foregroundStyle(Color.textSecond)
                                    Text("Snap a photo after class or tap + to type notes manually.")
                                        .bcCaption()
                                        .foregroundStyle(Color.textTertiary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                        } else {
                            ForEach(subject.notes) { note in
                                GlassCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(note.extractedText.prefix(120) + (note.extractedText.count > 120 ? "…" : ""))
                                            .bcCaption()
                                            .foregroundStyle(Color.textSecond)
                                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .bcCaption()
                                            .foregroundStyle(Color.textTertiary)
                                    }
                                }
                            }
                        }

                        // Start Quiz CTA
                        Button {
                            appState.startQuiz(for: subject)
                            dismiss()
                        } label: {
                            Text("Start Quiz")
                        }
                        .buttonStyle(BCPrimaryButtonStyle())
                        .disabled(subject.notes.isEmpty)
                        .opacity(subject.notes.isEmpty ? 0.4 : 1)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(subject.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.textSecond)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddNote = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.textSecond)
                    }
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .sheet(isPresented: $showAddNote) {
                AddNoteSheet(subject: subject, onSave: { text in
                    let note = Note(extractedText: text, subjectID: subject.id)
                    modelContext.insert(note)
                    try? modelContext.save()
                })
            }
        }
    }
}

// MARK: - Manual note entry sheet

private struct AddNoteSheet: View {
    let subject: Subject
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                VStack(spacing: 12) {
                    TextEditor(text: $text)
                        .bcBody()
                        .foregroundStyle(Color.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(14)
                        .glassCard(cornerRadius: 16)
                        .frame(maxHeight: .infinity)

                    Text("Type or paste your class notes. Quiz questions get generated only when you actually start a quiz.")
                        .bcCaption()
                        .foregroundStyle(Color.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .navigationTitle("Add Notes — \(subject.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecond)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        }
    }
}
