import SwiftUI

struct ClassRowView: View {
    let subject: Subject
    @State private var showDetail = false

    private var isFreeNow: Bool { subject.isFreeWindow }
    private var isHappeningNow: Bool {
        subject.scheduleTimes.contains { $0.isHappeningNow() }
    }

    var body: some View {
        Button { showDetail = true } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: subject.colorHex))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(subject.name)
                        .bcBody()
                        .foregroundStyle(.textPrimary)

                    if let ct = subject.nextClassTime {
                        Text(ct.displayTime)
                            .bcCaption()
                            .foregroundStyle(.textSecond)
                    }
                }

                Spacer()

                if isHappeningNow {
                    WhitePill(text: "Now")
                } else if isFreeNow {
                    WhitePill(text: "Free now")
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.textTertiary)
            }
            .padding(.vertical, 4)
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
    @Environment(\.dismiss) private var dismiss

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
                                        .foregroundStyle(.textTertiary)
                                    Text("No notes yet")
                                        .bcBody()
                                        .foregroundStyle(.textSecond)
                                    Text("Capture notes after class to start quizzing.")
                                        .bcCaption()
                                        .foregroundStyle(.textTertiary)
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
                                            .foregroundStyle(.textSecond)
                                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .bcCaption()
                                            .foregroundStyle(.textTertiary)
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
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
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
                        .foregroundStyle(.textSecond)
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        }
    }
}
