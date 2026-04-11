import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State private var isRefreshing = false
    @State private var appeared = false
    @State private var showSettings = false
    @State private var confirmDeleteAll = false

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !subjects.isEmpty {
                        Button {
                            confirmDeleteAll = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.textSecond)
                        }
                        .accessibilityLabel("Delete all classes")
                    }
                }
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
                    .accessibilityLabel("Refresh schedule")
                }
            }
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .confirmationDialog(
                "Remove all synced classes from this device?",
                isPresented: $confirmDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Delete all", role: .destructive) {
                    clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This does not delete your Canvas account. You can sync again later.")
            }
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
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: BCSpacing.sm) {
                ForEach(Array(subjects.enumerated()), id: \.element.id) { index, subject in
                    ClassRowView(subject: subject)
                        .offset(y: appeared ? 0 : 16)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            BCMotion.panelSpring.delay(Double(index) * 0.04),
                            value: appeared
                        )
                }
            }
            .padding(.horizontal, BCSpacing.gutter)
            .padding(.vertical, BCSpacing.md)
        }
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
            }
            .buttonStyle(BCPrimaryButtonStyle())
            .padding(.horizontal, BCSpacing.xxl)
            .padding(.top, 4)
        }
    }

    // MARK: - Clear

    private func clearAll() {
        for subject in subjects { modelContext.delete(subject) }
        try? modelContext.save()
        Task { await refresh() }
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
                // Filter C: If Canvas is configured and returned courses, use those names
                // as a whitelist — only import iCal events that fuzzy-match a Canvas course.
                let canvasConfigured = KeychainService.exists(KeychainKey.canvasToken)
                let canvasNames: [String] = canvasConfigured
                    ? subjects.compactMap { $0.canvasID.isEmpty ? nil : $0.name }
                    : []

                for (name, times) in grouped {
                    // Skip events that don't match any Canvas course (when Canvas is active)
                    if canvasConfigured && !canvasNames.isEmpty {
                        guard canvasNamesContain(name, canvasNames: canvasNames) else { continue }
                    }

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

    // MARK: - Canvas whitelist helper

    private func canvasNamesContain(_ icalName: String, canvasNames: [String]) -> Bool {
        // True if iCal event name contains any Canvas course code (e.g., "CSC413" in "CSC413 Digital Media")
        // or Canvas name is a substring of iCal name, or vice versa
        let normalizedICal = icalName.uppercased()
        return canvasNames.contains { canvas in
            let normalizedCanvas = canvas.uppercased()
            return normalizedICal.contains(normalizedCanvas) || normalizedCanvas.contains(normalizedICal)
                || normalizedICal.components(separatedBy: " ").first == normalizedCanvas.components(separatedBy: " ").first
        }
    }
}

#Preview {
    ScheduleView()
        .preferredColorScheme(.dark)
}
