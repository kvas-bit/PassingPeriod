import SwiftUI

struct NoteCardView: View {
    let note: Note
    let subjects: [Subject]

    @State private var showDetail = false
    @State private var appeared = false

    private var subjectName: String {
        subjects.first { $0.id == note.subjectID }?.name ?? "Unknown"
    }

    private var questionCount: Int { note.questions.count }

    var body: some View {
        Button { showDetail = true } label: {
            VStack(alignment: .leading, spacing: 0) {

                // Thumbnail or placeholder
                ZStack(alignment: .topTrailing) {
                    if let data = note.imageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 70)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [Color.bgElevated, Color.bgSurface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(width: 80, height: 70)
                        Image(systemName: "doc.text")
                            .foregroundStyle(Color.textTertiary)
                            .font(.system(size: 18))
                    }

                    // Question count badge
                    if questionCount > 0 {
                        Text("\(questionCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white, in: Capsule())
                            .padding(5)
                    }
                }

                // Subject label
                Text(subjectName)
                    .bcCaption()
                    .foregroundStyle(Color.textSecond)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(width: 80, alignment: .leading)
            }
            .frame(width: 80, height: 100)
            .glassCard(cornerRadius: 12)
            .clipped()
        }
        .buttonStyle(.plain)
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showDetail) {
            NoteDetailSheet(note: note, subjectName: subjectName)
        }
    }
}

// MARK: - Note detail sheet

private struct NoteDetailSheet: View {
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
