// PomodoroLiveActivity.swift
//
// Drop this into your Live Activity widget extension target (created via
// File ▸ New ▸ Target… ▸ Widget Extension, "Include Live Activity" checked).
//
// Steps after creating the extension:
//   1. Replace the generated "<Name>LiveActivity.swift" contents with this file
//      (and delete the generated sample `ActivityAttributes` struct + the sample
//      static-widget files so there's only ONE @main in the extension).
//   2. In the File inspector, add the app's
//      PomoLedger/PomoTimer/Models/PomodoroActivityAttributes.swift to this
//      extension's Target Membership (so both targets share the type).
//
// The countdown uses Text(timerInterval:) so the system ticks it down on its
// own — no push updates or background runtime required.

import ActivityKit
import WidgetKit
import SwiftUI

@main
struct PomodoroWidgetBundle: WidgetBundle {
    var body: some Widget {
        PomodoroLiveActivity()
    }
}

struct PomodoroLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            // Lock Screen / banner presentation
            PomodoroLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(
                        context.state.isBreak ? "Break" : "Focus",
                        systemImage: context.state.isBreak
                            ? "cup.and.saucer.fill" : "brain.head.profile"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(context.state.isBreak ? .mint : .indigo)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Session \(context.state.sessionNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(
                        timerInterval: context.state.startDate...context.state.endDate,
                        countsDown: true
                    )
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: context.state.isBreak
                    ? "cup.and.saucer.fill" : "brain.head.profile")
                    .foregroundStyle(context.state.isBreak ? .mint : .indigo)
            } compactTrailing: {
                Text(
                    timerInterval: context.state.startDate...context.state.endDate,
                    countsDown: true
                )
                .monospacedDigit()
                .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: context.state.isBreak
                    ? "cup.and.saucer.fill" : "brain.head.profile")
                    .foregroundStyle(context.state.isBreak ? .mint : .indigo)
            }
        }
    }
}

private struct PomodoroLockScreenView: View {
    let state: PomodoroActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                .font(.title2)
                .foregroundStyle(state.isBreak ? .mint : .indigo)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.isBreak ? "On Break" : "Focusing")
                    .font(.headline)
                Text("Session \(state.sessionNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding()
    }
}
