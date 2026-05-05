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

    private var canvasLinked: Bool {
        KeychainService.exists(KeychainKey.canvasToken)
    }

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

    private var colorCodingRefreshToken: Bool {
        appState.colorCodingEnabled
    }

    var body: some View {
        let _ = colorCodingRefreshToken
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {

                // MARK: Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Between Classes")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.bcAccent)
                            .tracking(1.4)

                        Text("\(greeting)")
                            .bcDisplayLarge()
                            .foregroundStyle(Color.textPrimary)

                        Text(dateString)
                            .bcBody()
                            .foregroundStyle(Color.textSecond)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        GlassChip(text: formattedDate(), textColor: Color.textPrimary)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showIntegrations = true
                        } label: {
                            Image(systemName: canvasLinked ? "link.circle.fill" : "link.badge.plus")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(canvasLinked ? Color.bcAccent : Color.textSecond)
                                .frame(width: 42, height: 42)
                                .background(
                                    Circle().fill(Color.bcAccentSubtle.opacity(canvasLinked ? 0.65 : 0.35))
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.glassStroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(canvasLinked ? "Connections — Canvas linked" : "Connections — set up Canvas and calendar")
                        .accessibilityHint("Opens connections to sync your schedule and API keys")
                    }
                }
                .padding(.top, 20)

                if !canvasLinked {
                    connectBanner
                }

                // MARK: Next Class Card
                if let subject = nextSubject {
                    NextClassCard(subject: subject)
                        .offset(y: appeared ? 0 : 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(BCMotion.panelSpring.delay(0.05), value: appeared)
                } else {
                    EmptyNextClassCard(onConnect: { showIntegrations = true })
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
                    GlassChip(text: "\(appState.quizStreak) day streak", leadingSymbol: "flame.fill", symbolColor: Color.bcAccent.opacity(0.9))
                    GlassChip(text: "\(appState.sessionsToday) sessions today", leadingSymbol: "waveform.path", symbolColor: Color.bcAccent.opacity(0.85))
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
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        appState.selectedTab = .capture
                    } label: {
                        Text("Open capture")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BCPrimaryButtonStyle())

                    if !canvasLinked {
                        Button {
                            showIntegrations = true
                        } label: {
                            Text("Connect Canvas first")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(BCGhostButtonStyle())
                    }
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

    private var connectBanner: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showIntegrations = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.bcAccent)
                    .frame(width: 36, height: 36)
                    .background(Color.bcAccentSubtle, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect Canvas")
                        .bcBodyStrong()
                        .foregroundStyle(Color.textPrimary)
                    Text("Pulls in subjects and unlocks schedule-aware study. You can still capture notes without it.")
                        .bcCaption()
                        .foregroundStyle(Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.top, 4)
            }
            .padding(BCSpacing.lg)
            .background(Color.bgSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: BCRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BCRadius.card, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [Color.bcAccent.opacity(0.35), Color.glassStroke], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Open the connection and API key screen")
    }
}

// MARK: - Next Class Card

private struct NextClassCard: View {
    let subject: Subject
    @Environment(AppState.self) private var appState

    private var subjectAccent: Color {
        _ = appState.colorCodingEnabled
        return subject.displayColor
    }

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
                                .fill(subjectAccent)
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
                .stroke(subjectAccent.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct EmptyNextClassCard: View {
    @Environment(AppState.self) private var appState
    var onConnect: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BCSpacing.md) {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 26, weight: .thin))
                        .foregroundStyle(Color.bcAccent.opacity(0.85))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No class scheduled")
                            .bcTitle()
                            .foregroundStyle(Color.textPrimary)
                        Text("Sync Canvas and optional iCal so we can nudge you between periods.")
                            .bcBody()
                            .foregroundStyle(Color.textSecond)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onConnect()
                } label: {
                    Text("Open connections")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BCPrimaryButtonStyle())

                Button {
                    appState.selectedTab = .schedule
                } label: {
                    Text("View schedule tab")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BCGhostButtonStyle())
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: BCRadius.card, style: .continuous)
                .stroke(Color.bcAccent.opacity(0.12), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}
