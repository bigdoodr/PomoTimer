import Foundation

/// One completed Pomodoro focus session.
/// Matches the JSON schema written by PomoTimerSD.zsh:
///   { session, date, start, end, duration_min, recap }
/// Extended with break duration, iCloud-safe UUID, raw epoch timestamps
/// needed for ICS generation, and optional intention/calendar-title fields.
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

    // Optional fields added in v2 — default to "" so older JSON still loads.
    var intention: String = ""
    var calendarTitle: String = ""

    // Optional field added in v3 — defaults to true so older JSON loads without
    // spuriously annotating descriptions on pre-existing sessions.
    var intentionAchieved: Bool = true

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
        case intention
        case calendarTitle   = "calendar_title"
        case intentionAchieved = "intention_achieved"
    }

    // MARK: - Computed helpers
    var startDate: Date { Date(timeIntervalSince1970: startEpoch) }
    var endDate: Date   { Date(timeIntervalSince1970: endEpoch) }

    /// Human-readable duration, e.g. "42 min"
    var durationLabel: String { "\(durationMinutes) min" }

    /// ICS-formatted timestamp (local time, no timezone suffix)
    var icsStart: String { isoCompact(from: startDate) }
    var icsEnd: String   { isoCompact(from: endDate) }

    /// The title used for the calendar event. Falls back to the default
    /// "Pomodoro Focus Session N" when no custom title was set.
    var effectiveCalendarTitle: String {
        calendarTitle.isEmpty ? "Pomodoro Focus Session \(sessionNumber)" : calendarTitle
    }

    private func isoCompact(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd'T'HHmmss"
        return fmt.string(from: date)
    }
}

// MARK: - Backward-compatible Decodable

extension PomodoroSession {
    /// Custom decoder so that JSON written before intention/calendarTitle/intentionAchieved were
    /// added still loads correctly — missing keys fall back to safe defaults.
    /// Defined in an extension so Swift preserves the synthesized memberwise init.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                      = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        sessionNumber           = try c.decode(Int.self, forKey: .sessionNumber)
        date                    = try c.decode(String.self, forKey: .date)
        startTime               = try c.decode(String.self, forKey: .startTime)
        endTime                 = try c.decode(String.self, forKey: .endTime)
        durationMinutes         = try c.decode(Int.self, forKey: .durationMinutes)
        breakDurationMinutes    = (try? c.decode(Int.self, forKey: .breakDurationMinutes)) ?? 0
        recap                   = try c.decode(String.self, forKey: .recap)
        calendarEventIdentifier = try? c.decode(String.self, forKey: .calendarEventIdentifier)
        startEpoch              = try c.decode(TimeInterval.self, forKey: .startEpoch)
        endEpoch                = try c.decode(TimeInterval.self, forKey: .endEpoch)
        intention               = (try? c.decode(String.self, forKey: .intention)) ?? ""
        calendarTitle           = (try? c.decode(String.self, forKey: .calendarTitle)) ?? ""
        intentionAchieved       = (try? c.decode(Bool.self, forKey: .intentionAchieved)) ?? true
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
        calendarEventIdentifier: String? = nil,
        intention: String = "",
        intentionAchieved: Bool = true,
        calendarTitle: String = ""
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
            endEpoch: end.timeIntervalSince1970,
            intention: intention,
            calendarTitle: calendarTitle,
            intentionAchieved: intentionAchieved
        )
    }
}
