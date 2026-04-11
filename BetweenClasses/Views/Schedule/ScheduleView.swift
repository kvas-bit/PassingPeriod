import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State private var isRefreshing = false
    @State private var appeared = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                Group {
                    if subjects.isEmpty {
                        emptyState
                    } else {
                        subjectList
                    }
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: isRefreshing ? "arrow.clockwise.circle" : "arrow.clockwise")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(
                                isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                                value: isRefreshing
                            )
                            .foregroundStyle(Color.textSecond)
                    }
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings) {
            CanvasConnectView()
        }
        .onAppear {
            appeared = true
            // Auto-refresh when subjects are missing or have no schedule times
            let needsRefresh = subjects.isEmpty || subjects.allSatisfy { $0.scheduleTimes.isEmpty }
            if needsRefresh && !isRefreshing {
                Task { await refresh() }
            }
        }
    }

    private var subjectList: some View {
        List {
            ForEach(subjects) { subject in
                ClassRowView(subject: subject)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: appeared)
            }
        }
        .listStyle(.plain)
        .background(Color.bgPrimary)
        .refreshable { await refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)

            Text("No schedule yet")
                .bcHeadline()
                .foregroundStyle(Color.textPrimary)

            Text("Connect Canvas or add an iCal URL to sync your class schedule.")
                .bcBody()
                .foregroundStyle(Color.textSecond)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showSettings = true
            } label: {
                Text("Connect")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Refresh

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // 1. Canvas: fetch enrolled courses and upsert subjects (names only — Canvas API
        //    does not expose recurring class schedule; schedule comes from iCal below).
        do {
            let fetched = try await CanvasService.fetchCourses()
            for s in fetched {
                if let existing = subjects.first(where: { $0.name == s.name }) {
                    if existing.canvasID.isEmpty { existing.canvasID = s.canvasID }
                } else {
                    modelContext.insert(s)
                }
            }
            try? modelContext.save()
        } catch CanvasError.notConfigured {
            // No Canvas credentials set — skip silently
        } catch {}

        // 2. iCal: parse and group by course name
        if let stored = try? KeychainService.retrieve(KeychainKey.icalURL),
           !stored.isEmpty,
           let url = URL(string: stored) {
            if let grouped = try? await iCalService.parseGrouped(from: url) {
                for (name, times) in grouped {
                    if let existing = subjects.first(where: { $0.name == name }) {
                        existing.scheduleTimes = times
                    } else {
                        let s = Subject(name: name)
                        s.scheduleTimes = times
                        modelContext.insert(s)
                    }
                }
                try? modelContext.save()
            }
        }
    }
}

#Preview {
    ScheduleView()
        .preferredColorScheme(.dark)
}
