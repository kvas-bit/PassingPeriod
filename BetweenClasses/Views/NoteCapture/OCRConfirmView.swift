import SwiftUI
import SwiftData

struct OCRConfirmView: View {
    let imageData: Data
    let extractedText: String
    let ocrSourceSummary: String?
    let ocrConfidenceSummary: String?
    let suggestedTopicName: String?
    let unreadableRegions: [String]
    let onSave: (Note) -> Void
    /// When non-nil, a "Save & Capture Another" button is shown. Caller should
    /// dismiss the sheet and return to the camera when this fires.
    var onCaptureAnother: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var subjects: [Subject]

    @State private var editedText: String
    @State private var selectedSubject: Subject?
    @State private var selectedExistingTopic: String = ""
    @State private var customTopicName: String = ""
    @State private var isSaving = false

    init(imageData: Data,
         extractedText: String,
         ocrSourceSummary: String? = nil,
         ocrConfidenceSummary: String? = nil,
         suggestedTopicName: String? = nil,
         unreadableRegions: [String] = [],
         onSave: @escaping (Note) -> Void,
         onCaptureAnother: (() -> Void)? = nil) {
        self.imageData = imageData
        self.extractedText = extractedText
        self.ocrSourceSummary = ocrSourceSummary
        self.ocrConfidenceSummary = ocrConfidenceSummary
        self.suggestedTopicName = suggestedTopicName
        self.unreadableRegions = unreadableRegions
        self.onSave = onSave
        self.onCaptureAnother = onCaptureAnother
        self._editedText = State(initialValue: extractedText)
    }

    private var existingTopics: [String] {
        selectedSubject?.topicNames ?? []
    }

    private var resolvedTopicName: String {
        let custom = customTopicName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        let existing = selectedExistingTopic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.isEmpty { return existing }
        return "Unsorted"
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

                        if ocrSourceSummary != nil || ocrConfidenceSummary != nil || !unreadableRegions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("OCR")
                                    .bcCaption()
                                    .foregroundStyle(Color.textSecond)
                                    .textCase(.uppercase)

                                VStack(alignment: .leading, spacing: 6) {
                                    if let ocrSourceSummary {
                                        Text("Source: \(ocrSourceSummary)")
                                            .bcBody()
                                            .foregroundStyle(Color.textPrimary)
                                    }
                                    if let ocrConfidenceSummary {
                                        Text(ocrConfidenceSummary)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.textTertiary)
                                    }
                                    if !unreadableRegions.isEmpty {
                                        Text("Unreadable bits: \(unreadableRegions.prefix(2).joined(separator: " • "))")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Color.textTertiary)
                                    }
                                }
                                .padding(16)
                                .glassCard(cornerRadius: 12)
                            }
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

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Topic / Lecture")
                                    .bcCaption()
                                    .foregroundStyle(Color.textSecond)
                                    .textCase(.uppercase)
                                Spacer()
                                if let suggestedTopicName,
                                   !suggestedTopicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Button("Use suggestion") {
                                        customTopicName = suggestedTopicName
                                        selectedExistingTopic = ""
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.textSecond)
                                }
                            }

                            if !existingTopics.isEmpty {
                                Menu {
                                    Button("Use Unsorted") {
                                        selectedExistingTopic = "Unsorted"
                                        customTopicName = ""
                                    }
                                    ForEach(existingTopics, id: \.self) { topic in
                                        Button(topic) {
                                            selectedExistingTopic = topic
                                            customTopicName = ""
                                        }
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(selectedExistingTopic.isEmpty ? "Pick existing topic" : selectedExistingTopic)
                                                .bcBody()
                                                .foregroundStyle(selectedExistingTopic.isEmpty ? Color.textSecond : Color.textPrimary)
                                            Text("Reuse an existing lecture/topic")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(Color.textTertiary)
                                        }
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

                            TextField("New topic or lecture name", text: $customTopicName, prompt: Text("e.g. Chapter 4, Derivatives, Crusades Day 1"))
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .glassCard(cornerRadius: 12)

                            Text("Saved as: \(resolvedTopicName)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.textTertiary)
                        }

                        // Primary save button
                        Button {
                            saveNote(captureAnother: false)
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

                        // "Save & Capture Another" — only shown when the caller supports it
                        if onCaptureAnother != nil {
                            Button {
                                saveNote(captureAnother: true)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                    Text("Save & Capture Another")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundStyle(Color.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.bgElevated, in: RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.glassStroke, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedSubject == nil || isSaving)
                            .opacity(selectedSubject == nil ? 0.4 : 1)
                        }

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
            selectedExistingTopic = subjects.first?.topicNames.first ?? ""
            if let suggestedTopicName,
               !suggestedTopicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               selectedExistingTopic.isEmpty {
                customTopicName = suggestedTopicName
            }
        }
        .onChange(of: selectedSubject?.id) { _, _ in
            selectedExistingTopic = selectedSubject?.topicNames.first ?? ""
            customTopicName = ""
        }
    }

    // MARK: - Save

    private func saveNote(captureAnother: Bool) {
        guard let subject = selectedSubject else { return }
        isSaving = true

        let note = Note(
            imageData: imageData,
            extractedText: editedText,
            subjectID: subject.id,
            topicName: resolvedTopicName
        )
        modelContext.insert(note)
        subject.notes.append(note)

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Pre-generate questions asynchronously (with fallback)
        Task { @MainActor in
            let questions = await GeminiService.generateQuestionsWithFallback(
                from: editedText,
                noteID: note.id
            )
            for q in questions {
                modelContext.insert(q)
                note.questions.append(q)
            }
            try? modelContext.save()
        }

        try? modelContext.save()
        onSave(note)

        isSaving = false

        if captureAnother, let handler = onCaptureAnother {
            dismiss()
            handler()
        } else {
            dismiss()
        }
    }
}
