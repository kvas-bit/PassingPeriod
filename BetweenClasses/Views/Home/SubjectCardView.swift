import SwiftUI

struct SubjectCardView: View {
    let subject: Subject
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.startQuiz(for: subject)
        } label: {
            GlassCard(padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color(hex: subject.colorHex))
                            .frame(width: 8, height: 8)
                        Text(subject.name)
                            .bcBody()
                            .foregroundStyle(Color.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }

                    Text("\(subject.notes.count) note\(subject.notes.count == 1 ? "" : "s")")
                        .bcCaption()
                        .foregroundStyle(Color.textSecond)

                    if subject.isFreeWindow {
                        WhitePill(text: "Free now")
                    }
                }
            }
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel("Start quiz for \(subject.name)")
    }
}
