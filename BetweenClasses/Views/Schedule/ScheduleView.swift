import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @AppStorage("scheduleLastSyncEpoch") private var lastSyncEpoch: Double = 0
    @State private var isRefreshing = false
    @State private var appeared = false
    @State private var showSettings = false
    @State private var confirmDeleteAll = false
    @State private var syncNotice: String?

    var body: some View {
        let _ = appState.colorCodingEnabled
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                Group {
                    if subjects.isEmpty && isRefreshing {
                        syncingPlaceholder
                    } else if subjects.isEmpty {
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
                        HStack(spacing: 16) {
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .foregroundStyle(Color.textSecond)
                            }
                            .accessibilityLabel("Canvas and iCal connection settings")

                            Button {
                                confirmDeleteAll = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(Color.textSecond)
                            }
                            .accessibilityLabel("Delete all classes")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Group {
                            if isRefreshing {
                                ProgressView()
                                    .tint(Color.textSecond)
                                    .scaleEffect(0.95)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(Color.textSecond)
                            }
                        }
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel(isRefreshing ? "Refreshing schedule" : "Refresh schedule")
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
            VStack(alignment: .leading, spacing: BCSpacing.md) {
                connectionSourcesCard

                syncMetaSection

                if isRefreshing {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(Color.textSecond)
                            .scaleEffect(0.9)
                        Text("Syncing Canvas and calendar…")
                            .bcCaption()
                            .foregroundStyle(Color.textSecond)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, BCSpacing.md)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.bgSurface.opacity(0.65), in: RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous)
                            .strokeBorder(Color.glassStroke, lineWidth: 1)
                    )
                }

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
            }
            .padding(.horizontal, BCSpacing.gutter)
            .padding(.vertical, BCSpacing.md)
        }
        .background(Color.bgPrimary)
        .refreshable { await refresh() }
    }

    private var connectionSourcesCard: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.textSecond)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connections")
                        .bcCaption()
                        .foregroundStyle(Color.textPrimary.opacity(0.92))
                    Text("Canvas token · iCal URL")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.35)
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, BCSpacing.md)
            .padding(.vertical, 12)
            .background(Color.bgSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BCRadius.panel, style: .continuous)
                    .strokeBorder(Color.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Canvas and iCal connection settings")
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 18) {
                syncMetaSection

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

                Button {
                    showSettings = true
                } label: {
                    Text("Canvas token or iCal URL")
                }
                .buttonStyle(.plain)
                .bcCaption()
                .foregroundStyle(Color.textSecond)
                .padding(.top, 10)
            }
            .padding(.vertical, 28)
        }
    }

    @ViewBuilder
    private var syncMetaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let notice = syncNotice, !notice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.orange.opacity(0.9))
                    Text(notice)
                        .bcCaption()
                        .foregroundStyle(Color.textPrimary.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.22), lineWidth: 1)
                )
            }

            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
                if lastSyncEpoch > 0 {
                    Text("Last sync \(Date(timeIntervalSince1970: lastSyncEpoch).formatted(.relative(presentation: .named)))")
                        .bcCaption()
                        .foregroundStyle(Color.textSecond)
                } else {
                    Text("Not synced yet — tap refresh after connecting.")
                        .bcCaption()
                        .foregroundStyle(Color.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, BCSpacing.md)
            .padding(.vertical, 10)
            .background(Color.bgSurface.opacity(0.45), in: RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BCRadius.control, style: .continuous)
                    .strokeBorder(Color.glassStroke.opacity(0.85), lineWidth: 1)
            )
        }
        .padding(.horizontal, BCSpacing.gutter)
    }

    private var syncingPlaceholder: some View {
        VStack(spacing: 22) {
            ProgressView()
                .scaleEffect(1.15)
                .tint(Color.textSecond)
            Text("Pulling your schedule…")
                .bcHeadline()
                .foregroundStyle(Color.textPrimary)
            Text("Contacting Canvas and your calendar link. You can leave this screen — sync finishes in the background.")
                .bcBody()
                .foregroundStyle(Color.textSecond)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            syncMetaSection
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.bottom, 48)
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
