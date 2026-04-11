import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State private var isRefreshing = false
    @State private var appeared = false
    @State private var showSettings = false
    @State private var confirmDeleteAll = false

    var body: some View {
        let _ = appState.colorCodingEnabled
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
                .font(.system(size: 48, weight: .thin))
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

        do {
            let fetched = try await CanvasService.fetchCourses()
            for s in fetched {
                if let existing = subjects.first(where: {
                    (!s.canvasID.isEmpty && $0.canvasID == s.canvasID) || $0.name == s.name
                }) {
                    if existing.canvasID.isEmpty { existing.canvasID = s.canvasID }
                    if existing.displayColorHex != existing.colorHex {
                        existing.colorHex = existing.displayColorHex
                    }
                } else {
                    modelContext.insert(s)
                }
            }
            try? modelContext.save()
        } catch CanvasError.notConfigured {
        } catch {}

        if let stored = try? KeychainService.retrieve(KeychainKey.icalURL),
           !stored.isEmpty,
           let url = URL(string: stored) {
            if let grouped = try? await iCalService.parseGrouped(from: url) {
                let canvasConfigured = KeychainService.exists(KeychainKey.canvasToken)
                let canvasNames: [String] = canvasConfigured
                    ? subjects.compactMap { $0.canvasID.isEmpty ? nil : $0.name }
                    : []

                for (name, times) in grouped {
                    if canvasConfigured && !canvasNames.isEmpty {
                        guard canvasNamesContain(name, canvasNames: canvasNames) else { continue }
                    }

                    if let existing = subjects.first(where: { $0.name == name }) {
                        existing.scheduleTimes = times
                        if existing.displayColorHex != existing.colorHex {
                            existing.colorHex = existing.displayColorHex
                        }
                    } else {
                        let s = Subject(name: name, colorHex: Color.generatedSubjectHex(for: name))
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
