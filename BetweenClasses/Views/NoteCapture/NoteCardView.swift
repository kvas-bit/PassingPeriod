import SwiftUI

struct NoteCardView: View {
    let note: Note
    let subjects: [Subject]

    private var subjectName: String {
        subjects.first { $0.id == note.subjectID }?.name ?? "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail or placeholder
            ZStack {
                if let data = note.imageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 70)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [Color.bgElevated, Color.bgSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 80, height: 70)
                    Image(systemName: "doc.text")
                        .foregroundStyle(Color.textTertiary)
                        .font(.system(size: 18))
                }
            }

            // Subject label
            Text(subjectName)
                .bcCaption()
                .foregroundStyle(Color.textSecond)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(width: 80, alignment: .leading)
        }
        .frame(width: 80, height: 100)
        .glassCard(cornerRadius: 12)
        .clipped()
    }
}
