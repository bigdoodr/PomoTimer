#if os(iOS)
import ActivityKit
import Foundation

/// Describes the Pomodoro timer Live Activity shown on the Lock Screen and in
/// the Dynamic Island while the app is backgrounded.
///
/// IMPORTANT: this file must belong to BOTH targets — the app (which starts /
/// updates / ends the activity) and the Live Activity widget extension (which
/// renders it). After creating the widget extension in Xcode, add this file to
/// the extension's Target Membership.
struct PomodoroActivityAttributes: ActivityAttributes {

    /// The part of the activity that changes over time.
    public struct ContentState: Codable, Hashable {
        /// `false` for a focus countdown, `true` for a break countdown.
        var isBreak: Bool
        /// The session number currently in progress.
        var sessionNumber: Int
        /// When the current countdown began.
        var startDate: Date
        /// When the current countdown reaches zero (drives the live timer text).
        var endDate: Date
    }
}
#endif
