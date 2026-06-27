// PomoWidgLiveActivity.swift
//
// The Pomodoro Live Activity (Lock Screen + Dynamic Island).
//
// The countdown uses Text(timerInterval:) so the system ticks it down on its
// own. When the countdown reaches the activity's staleDate (the end time), the
// system marks it stale and re-renders — we use `context.isStale` to swap the
// timer for a clear "Time's up!" completion state. The audible alert at zero
// comes from the app's scheduled local notification, not the activity itself.

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
            PomodoroLockScreenView(state: context.state, isDone: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            let done = context.isStale
            let accent: Color = context.state.isBreak ? .mint : .indigo

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(
                        context.state.isBreak ? "Break" : "Focus",
                        systemImage: context.state.isBreak
                            ? "cup.and.saucer.fill" : "brain.head.profile"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Session \(context.state.sessionNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if done {
                        Text(context.state.isBreak ? "Break's over ☕️" : "Time's up! 🎉")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(
                            timerInterval: context.state.startDate...context.state.endDate,
                            countsDown: true
                        )
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isBreak
                    ? "cup.and.saucer.fill" : "brain.head.profile")
                    .foregroundStyle(accent)
            } compactTrailing: {
                if done {
                    Image(systemName: "bell.fill").foregroundStyle(accent)
                } else {
                    Text(
                        timerInterval: context.state.startDate...context.state.endDate,
                        countsDown: true
                    )
                    .monospacedDigit()
                    .frame(maxWidth: 56)
                }
            } minimal: {
                Image(systemName: done
                    ? "bell.fill"
                    : (context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile"))
                    .foregroundStyle(accent)
            }
        }
    }
}

private struct PomodoroLockScreenView: View {
    let state: PomodoroActivityAttributes.ContentState
    let isDone: Bool

    private var accent: Color { state.isBreak ? .mint : .indigo }

    private var symbol: String {
        if isDone { return "bell.fill" }
        return state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile"
    }
    private var title: String {
        if isDone { return state.isBreak ? "Break's over" : "Time's up!" }
        return state.isBreak ? "On Break" : "Focusing"
    }
    private var subtitle: String {
        if isDone {
            return state.isBreak ? "Tap to start your next session" : "Tap to log your recap"
        }
        return "Session \(state.sessionNumber)"
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if isDone {
                Text("0:00")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            } else {
                Text(timerInterval: state.startDate...state.endDate, countsDown: true)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .padding()
    }
}
