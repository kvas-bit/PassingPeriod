import ActivityKit
import WidgetKit
import SwiftUI

struct BetweenClassesLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassLiveActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.status.label, systemImage: context.state.status.systemImage)
                        .font(.caption.weight(.semibold))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startDate, style: .time)
                        .font(.caption.monospacedDigit())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.subjectName)
                            .font(.headline)
                            .lineLimit(1)

                        if context.state.status == .inSession {
                            Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                                .font(.subheadline.monospacedDigit())
                        } else {
                            Text(timerInterval: Date()...context.state.startDate, countsDown: true)
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.state.status.systemImage)
            } compactTrailing: {
                if context.state.status == .inSession {
                    Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                        .monospacedDigit()
                } else {
                    Text(timerInterval: Date()...context.state.startDate, countsDown: true)
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: context.state.status.systemImage)
            }
        }
    }
}

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<ClassLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(context.state.status.label, systemImage: context.state.status.systemImage)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(context.state.startDate, style: .time)
                    .font(.caption.monospacedDigit())
            }

            Text(context.state.subjectName)
                .font(.headline)
                .lineLimit(1)

            if !context.state.room.isEmpty {
                Text(context.state.room)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if context.state.status == .inSession {
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .font(.title3.monospacedDigit().bold())
            } else {
                Text(timerInterval: Date()...context.state.startDate, countsDown: true)
                    .font(.title3.monospacedDigit().bold())
            }
        }
        .padding(.vertical, 6)
    }
}
