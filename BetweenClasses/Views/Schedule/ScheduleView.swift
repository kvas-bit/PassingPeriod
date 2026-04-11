import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.name) private var subjects: [Subject]

    @State private var isRefreshing = false
    @State private var appeared = false

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
        .onAppear { appeared = true }
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

            Text("Connect Canvas or add an iCal URL in settings to sync your class schedule.")
                .bcBody()
                .foregroundStyle(Color.textSecond)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let newSubjects = try await CanvasService.fetchCourses()
            for s in newSubjects {
                if !subjects.contains(where: { $0.name == s.name }) {
                    modelContext.insert(s)
                }
            }
            try? modelContext.save()
        } catch {}
    }
}

#Preview {
    ScheduleView()
        .preferredColorScheme(.dark)
}
