import Foundation
#if os(iOS)
import ActivityKit
#endif

/// Starts, updates, and ends the Pomodoro Live Activity (iOS 16.2+).
///
/// All ActivityKit usage is gated behind `#if os(iOS)` and an availability
/// check, so every method is a safe no-op on macOS or when the user has Live
/// Activities turned off. The public API deliberately uses only Foundation
/// types so call sites (TimerViewModel) stay platform-agnostic.
///
/// Note: a Live Activity can only be *started* while the app is in the
/// foreground, so these are driven from the in-app focus/break lifecycle. A
/// focus session that completes while the device is locked is handled by the
/// notification flow instead; its activity is reclaimed and ended by `endAll()`
/// when the app next becomes active.
@MainActor
final class LiveActivityManager {

    static let shared = LiveActivityManager()
    private init() {}

    #if os(iOS)
    /// Stored as `Any?` to avoid an availability annotation on the property.
    /// Holds an `Activity<PomodoroActivityAttributes>` when one is running.
    private var currentActivity: Any?
    #endif

    /// Begin a Live Activity for a countdown — or, if one is already running,
    /// transition it (e.g. focus → break) in place.
    func start(isBreak: Bool, sessionNumber: Int, start: Date, end: Date) {
        #if os(iOS)
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = PomodoroActivityAttributes.ContentState(
            isBreak: isBreak, sessionNumber: sessionNumber,
            startDate: start, endDate: end
        )

        // Already tracking one — just update it so the panel flows seamlessly
        // from the focus countdown into the break countdown.
        if let activity = currentActivity as? Activity<PomodoroActivityAttributes> {
            Task { await activity.update(ActivityContent(state: state, staleDate: end)) }
            return
        }

        // Reclaim and end any orphan from a previous run (e.g. a focus session
        // that finished while the app was suspended) before starting fresh.
        for orphan in Activity<PomodoroActivityAttributes>.activities {
            Task { await orphan.end(nil, dismissalPolicy: .immediate) }
        }

        do {
            currentActivity = try Activity.request(
                attributes: PomodoroActivityAttributes(),
                content: ActivityContent(state: state, staleDate: end),
                pushType: nil
            )
        } catch {
            print("[LiveActivity] start failed: \(error)")
        }
        #endif
    }

    /// Update the running activity's countdown / phase.
    func update(isBreak: Bool, sessionNumber: Int, start: Date, end: Date) {
        #if os(iOS)
        guard #available(iOS 16.2, *),
              let activity = currentActivity as? Activity<PomodoroActivityAttributes>
        else { return }

        let state = PomodoroActivityAttributes.ContentState(
            isBreak: isBreak, sessionNumber: sessionNumber,
            startDate: start, endDate: end
        )
        Task { await activity.update(ActivityContent(state: state, staleDate: end)) }
        #endif
    }

    /// End the activity we're currently tracking and remove it immediately.
    func end() {
        #if os(iOS)
        guard #available(iOS 16.2, *),
              let activity = currentActivity as? Activity<PomodoroActivityAttributes>
        else { return }
        currentActivity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        #endif
    }

    /// End *every* Pomodoro Live Activity the system currently knows about.
    ///
    /// Needed because after a cold launch the in-memory `currentActivity`
    /// reference is gone, so `end()` alone can't reach an activity left over
    /// from a session that finished while the app was suspended. Querying
    /// `Activity.activities` reclaims those orphans.
    func endAll() {
        #if os(iOS)
        guard #available(iOS 16.2, *) else { return }
        currentActivity = nil
        Task {
            for activity in Activity<PomodoroActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
