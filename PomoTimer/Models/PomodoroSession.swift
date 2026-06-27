import Foundation

/// One completed Pomodoro focus session.
/// Matches the JSON schema written by PomoTimerSD.zsh:
///   { session, date, start, end, duration_min, recap }
/// Extended with break duration, iCloud-safe UUID, and raw epoch timestamps
/// needed for ICS generation.
struct PomodoroSession: Codable, Identifiable {
    var id: UUID = UUID()
    var sessionNumber: Int
    var date: String            // "YYYY-MM-DD"
    var startTime: String       // "HH:MM"
    var endTime: String         // "HH:MM"
    var durationMinutes: Int
    var breakDurationMinutes: Int
    var recap: String
    var calendarEventIdentifier: String?

    // Raw Unix timestamps — used for ICS DTSTART / DTEND generation
    var startEpoch: TimeInterval
    var endEpoch: TimeInterval

    // MARK: - CodingKeys mapping to the legacy zsh JSON field names
    enum CodingKeys: String, CodingKey {
        case id
        case sessionNumber   = "session"
        case date
        case startTime       = "start"
        case endTime         = "end"
        case durationMinutes = "duration_min"
        case breakDurationMinutes = "break_duration_min"
        case recap
        case calendarEventIdentifier = "calendar_event_id"
        case startEpoch      = "start_epoch"
        case endEpoch        = "end_epoch"
    }

    // MARK: - Computed helpers
    var startDate: Date { Date(timeIntervalSince1970: startEpoch) }
    var endDate: Date   { Date(timeIntervalSince1970: endEpoch) }

    /// Human-readable duration, e.g. "42 min"
    var durationLabel: String { "\(durationMinutes) min" }

    /// ICS-formatted timestamp (local time, no timezone suffix)
    var icsStart: String { isoCompact(from: startDate) }
    var icsEnd: String   { isoCompact(from: endDate) }

    private func isoCompact(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd'T'HHmmss"
        return fmt.string(from: date)
    }
}

// MARK: - Convenience construction

extension PomodoroSession {
    /// Builds a session from raw start/end dates, deriving the legacy
    /// "YYYY-MM-DD" / "HH:mm" string fields. Used by the background
    /// notification recap handler (and available to the in-app flow).
    init(
        sessionNumber: Int,
        start: Date,
        end: Date,
        durationMinutes: Int,
        breakDurationMinutes: Int,
        recap: String,
        calendarEventIdentifier: String? = nil
    ) {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        self.init(
            sessionNumber: sessionNumber,
            date: dateFmt.string(from: start),
            startTime: timeFmt.string(from: start),
            endTime: timeFmt.string(from: end),
            durationMinutes: durationMinutes,
            breakDurationMinutes: breakDurationMinutes,
            recap: recap,
            calendarEventIdentifier: calendarEventIdentifier,
            startEpoch: start.timeIntervalSince1970,
            endEpoch: end.timeIntervalSince1970
        )
    }
}
