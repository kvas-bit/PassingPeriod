import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var subjects: [Subject]

    @State private var appeared = false
    @State private var showSettings = false

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
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.textSecond)
                                .frame(width: 34, height: 34)
                                .glassCard(cornerRadius: 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 20)

                // MARK: Next Class Card
                if let subject = nextSubject {
                    NextClassCard(subject: subject)
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05), value: appeared)
                } else {
                    EmptyNextClassCard()
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.05), value: appeared)
                }

                // MARK: Recent Notes
                if !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        // Header row: label + count badge + See All button
                        HStack(spacing: 8) {
                            Text("RECENT NOTES · \(notes.count)")
                                .bcCaption()
                                .foregroundStyle(Color.textSecond)

                            Spacer()

                            Button {
                                appState.selectedTab = .schedule
                            } label: {
                                HStack(spacing: 4) {
                                    Text("See All")
                                        .bcCaption()
                                        .foregroundStyle(Color.textSecond)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.textSecond)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(notes.prefix(10).enumerated()), id: \.element.id) { index, note in
                                    NoteCardView(note: note, subjects: subjects)
                                        .offset(y: appeared ? 0 : 20)
                                        .opacity(appeared ? 1 : 0)
                                        .animation(
                                            .spring(response: 0.4, dampingFraction: 0.75)
                                                .delay(Double(index) * 0.06),
                                            value: appeared
                                        )
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                }

                // MARK: Quick Stats
                HStack(spacing: 12) {
                    GlassChip(text: "🔥 \(appState.quizStreak) day streak")
                    GlassChip(text: "\(appState.sessionsToday) sessions today")
                    Spacer()
                }
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.75).delay(0.15), value: appeared)

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.bgPrimary)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .sheet(isPresented: $showSettings) {
            CanvasConnectView()
        }
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
                        Text(subject.name)
                            .bcHeadline()
                            .foregroundStyle(Color.textPrimary)
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
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
