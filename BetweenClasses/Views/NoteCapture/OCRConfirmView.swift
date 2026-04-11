import SwiftUI
import SwiftData

struct OCRConfirmView: View {
    let imageData: Data
    let extractedText: String
    let onSave: (Note) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var subjects: [Subject]

    @State private var editedText: String
    @State private var selectedSubject: Subject?
    @State private var isSaving = false

    init(imageData: Data, extractedText: String, onSave: @escaping (Note) -> Void) {
        self.imageData = imageData
        self.extractedText = extractedText
        self.onSave = onSave
        self._editedText = State(initialValue: extractedText)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Photo thumbnail
                        HStack {
                            if let img = UIImage(data: imageData) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.glassStroke, lineWidth: 1)
                                    )
                            }
                            Spacer()
                        }

                        // Extracted text editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Extracted Text")
                                .bcCaption()
                                .foregroundStyle(Color.textSecond)
                                .textCase(.uppercase)

                            TextEditor(text: $editedText)
                                .bcBody()
                                .foregroundStyle(Color.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 180)
                                .padding(16)
                                .glassCard()
                        }

                        // Subject picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Save to")
                                .bcCaption()
                                .foregroundStyle(Color.textSecond)
                                .textCase(.uppercase)

                            Menu {
                                ForEach(subjects) { subject in
                                    Button(subject.name) {
                                        selectedSubject = subject
                                    }
                                }
                                if subjects.isEmpty {
                                    Button("No subjects — connect Canvas first") {}
                                        .disabled(true)
                                }
                            } label: {
                                HStack {
                                    Text(selectedSubject?.name ?? "Select subject")
                                        .bcBody()
                                        .foregroundStyle(selectedSubject == nil ? Color.textSecond : Color.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundStyle(Color.textSecond)
                                        .font(.system(size: 12))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .glassCard(cornerRadius: 12)
                            }
                        }

                        // Save button
                        Button {
                            saveNote()
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text("Save Note")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedSubject == nil ? Color.white.opacity(0.4) : Color.white,
                                        in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedSubject == nil || isSaving)

                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Review Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.textSecond)
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        }
        .onAppear {
            selectedSubject = subjects.first
        }
    }

    private func saveNote() {
        guard let subject = selectedSubject else { return }
        isSaving = true

        let note = Note(imageData: imageData, extractedText: editedText, subjectID: subject.id)
        modelContext.insert(note)
        subject.notes.append(note)

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Pre-generate questions asynchronously
        Task {
            if let questions = try? await GeminiService.generateQuestions(from: editedText, noteID: note.id) {
                for q in questions {
                    modelContext.insert(q)
                    note.questions.append(q)
                }
                try? modelContext.save()
            }
        }

        try? modelContext.save()
        onSave(note)

        isSaving = false
        dismiss()
    }
}
