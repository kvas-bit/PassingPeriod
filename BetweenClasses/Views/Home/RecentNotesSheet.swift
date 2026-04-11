import SwiftUI
import SwiftData

struct RecentNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var subjects: [Subject]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: BCSpacing.md) {
                        ForEach(notes) { note in
                            NoteCardView(note: note, subjects: subjects)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, BCSpacing.gutter)
                    .padding(.vertical, BCSpacing.lg)
                }
            }
            .navigationTitle("All notes")
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
