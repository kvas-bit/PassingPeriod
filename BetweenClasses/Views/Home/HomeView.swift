import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var subjects: [Subject]

    @State private var appeared = false
    @State private var showIntegrations = false
    @State private var showAllNotes = false

    private var nextSubject: Subject? {
        subjects
            .compactMap { s -> (Subject, Int)? in
                guard let m = s.minutesUntilNext else { return nil }
                return (s, m)
            }
            .sorted { $0.1 < $1.1 }
            .first?.0
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {

                // MARK: Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(greeting)")
                            .bcDisplay()
                            .foregroundStyle(Color.textPrimary)
                        Text(dateString)
                            .bcBody()
                            .foregroundStyle(Color.textSecond)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        GlassChip(text: formattedDate())
                        Button { showIntegrations = true } label: {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.textSecond)
                                .frame(width: 38, height: 38)
                                .glassCard(cornerRadius: BCRadius.control)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Canvas and calendar")
                        .accessibilityHint("Opens connections to sync your schedule")
                    }
                }
                .padding(.top, 20)

                // MARK: Next Class Card
                if let subject = nextSubject {
                    NextClassCard(subject: subject)
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(BCMotion.panelSpring.delay(0.05), value: appeared)
                } else {
                    EmptyNextClassCard()
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(BCMotion.panelSpring.delay(0.05), value: appeared)
                }

                // MARK: Recent Notes
                if !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("RECENT NOTES · \(notes.count)")
                                .bcCaption()
                                .foregroundStyle(Color.textSecond)

                            Spacer()

                            Button {
                                showAllNotes = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("See all")
                                        .bcCaption()
                                        .foregroundStyle(Color.textSecond)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.textSecond)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("See all notes")
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(notes.prefix(10).enumerated()), id: \.element.id) { index, note in
                                    NoteCardView(note: note, subjects: subjects)
                                        .offset(y: appeared ? 0 : 20)
                                        .opacity(appeared ? 1 : 0)
                                        .animation(
                                            BCMotion.panelSpring.delay(Double(index) * 0.06),
                                            value: appeared
                                        )
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                } else {
                    emptyNotesSection
                }

                // MARK: Quick Stats
                HStack(spacing: 12) {
                    GlassChip(text: "\(appState.quizStreak) day streak", leadingSymbol: "flame.fill")
                    GlassChip(text: "\(appState.sessionsToday) sessions today", leadingSymbol: "waveform.path")
                    Spacer()
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(BCMotion.panelSpring.delay(0.15), value: appeared)

                Spacer(minLength: 32)
            }
            .padding(.horizontal, BCSpacing.gutter)
        }
        .background(Color.bgPrimary)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .sheet(isPresented: $showIntegrations) {
            CanvasConnectView()
        }
        .sheet(isPresented: $showAllNotes) {
            RecentNotesSheet()
        }
    }

    private var emptyNotesSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.md) {
            Text("RECENT NOTES")
                .bcCaption()
                .foregroundStyle(Color.textSecond)

            GlassCard {
                VStack(alignment: .leading, spacing: BCSpacing.lg) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(Color.textTertiary)
                    Text("No notes yet")
                        .bcHeadline()
                        .foregroundStyle(Color.textPrimary)
                    Text("Capture a page after class — we will turn it into voice quizzes between periods.")
                        .bcBody()
                        .foregroundStyle(Color.textSecond)
                    Button {
                        appState.selectedTab = .capture
                    } label: {
                        Text("Open capture")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .offset(y: appeared ? 0 : 20)
        .opacity(appeared ? 1 : 0)
        .animation(BCMotion.panelSpring.delay(0.08), value: appeared)
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: Date())
    }
}

// MARK: - Next Class Card

private struct NextClassCard: View {
    let subject: Subject
    @Environment(AppState.self) private var appState

    var timeLabel: String {
        guard let mins = subject.minutesUntilNext else { return "Soon" }
        if mins < 1   { return "Now" }
        if mins < 60  { return "In \(mins) min" }
        let hours = mins / 60
        if hours < 24 {
            let rem = mins % 60
            return rem > 0 ? "In \(hours)h \(rem)m" : "In \(hours)h"
        }
        let days = hours / 24
        if days == 1 { return "Tomorrow" }
        return subject.nextClassTime?.weekdayName ?? "Upcoming"
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(subject.displayColor)
                                .frame(width: 9, height: 9)
                            Text(subject.name)
                                .bcHeadline()
                                .foregroundStyle(Color.textPrimary)
                        }
                        Text(timeLabel)
                            .bcBody()
                            .foregroundStyle(Color.textSecond)
                        if let ct = subject.nextClassTime, !ct.room.isEmpty {
                            Text(ct.room)
                                .bcCaption()
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.textTertiary)
                }

                Button {
                    appState.startQuiz(for: subject)
                } label: {
                    Text("Start Quiz")
                }
                .buttonStyle(BCPrimaryButtonStyle())
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: BCRadius.card, style: .continuous)
                .stroke(subject.displayColor.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct EmptyNextClassCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("No class scheduled")
                    .bcHeadline()
                    .foregroundStyle(Color.textPrimary)
                Text("Connect Canvas or add your schedule to get started.")
                    .bcBody()
                    .foregroundStyle(Color.textSecond)
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
