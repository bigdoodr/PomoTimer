import UserNotifications

/// Manages local notifications for background timer expiration.
///
/// On iOS the app process is suspended when the user switches away, so the only
/// way to signal "your timer is done" is a UNUserNotificationCenter local
/// notification. On macOS the app stays alive, but we still schedule
/// notifications for consistency (the user may minimize the app).
///
/// The focus-complete notification is *actionable* (Messages-style): expanding
/// it reveals an inline recap text field plus break-length buttons. The reply
/// is handled in the background — even at cold launch — and the completed
/// session is persisted directly via `SessionStore`, so the user never has to
/// open the app to log a recap.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    private let center = UNUserNotificationCenter.current()

    // Stable identifiers so we can cancel them later
    private let focusNotificationID = "com.casey.PomoTimer.focus_complete"
    private let breakNotificationID = "com.casey.PomoTimer.break_complete"

    // Actionable-notification identifiers
    private static let categoryFocusComplete = "FOCUS_COMPLETE"
    private static let actionRecapBreak5  = "RECAP_BREAK_5"
    private static let actionRecapBreak15 = "RECAP_BREAK_15"
    private static let actionFiveMore     = "FIVE_MORE"

    // userInfo keys carrying the pending-session context
    private static let sessionNumberKey = "session_number"
    private static let startEpochKey    = "start_epoch"
    private static let endEpochKey       = "end_epoch"

    /// Dependencies needed to finalize a recap from the background handler.
    /// Injected after construction via `configure(sessionStore:calendarService:)`.
    private var sessionStore: SessionStore?
    private var calendarService: CalendarService?

    override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    /// Wires up the services the background recap handler needs. Called once
    /// during app launch (see TimerViewModel.init) so a notification reply can
    /// be handled even if the app was cold-launched to process it.
    func configure(sessionStore: SessionStore, calendarService: CalendarService) {
        self.sessionStore = sessionStore
        self.calendarService = calendarService
    }

    // MARK: - Category registration

    private func registerCategories() {
        let recap5 = UNTextInputNotificationAction(
            identifier: Self.actionRecapBreak5,
            title: "Recap → 5-min Break",
            options: [],
            textInputButtonTitle: "Start 5-min Break",
            textInputPlaceholder: "What did you work on?"
        )
        let recap15 = UNTextInputNotificationAction(
            identifier: Self.actionRecapBreak15,
            title: "Recap → 15-min Break",
            options: [],
            textInputButtonTitle: "Start 15-min Break",
            textInputPlaceholder: "What did you work on?"
        )
        let fiveMore = UNNotificationAction(
            identifier: Self.actionFiveMore,
            title: "5 More Minutes",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryFocusComplete,
            actions: [recap5, recap15, fiveMore],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Pull the pending-session context out of userInfo up front so we only
        // pass Sendable scalars across the actor hop in `recordRecap`.
        let userInfo = response.notification.request.content.userInfo
        let sessionNumber = userInfo[Self.sessionNumberKey] as? Int ?? 1
        let startEpoch = userInfo[Self.startEpochKey] as? Double
            ?? Date().timeIntervalSince1970
        let endEpoch = userInfo[Self.endEpochKey] as? Double
            ?? Date().timeIntervalSince1970
        let userText = (response as? UNTextInputNotificationResponse)?.userText ?? ""

        switch response.actionIdentifier {
        case Self.actionRecapBreak5:
            await recordRecap(
                userText: userText, breakMinutes: 5,
                sessionNumber: sessionNumber,
                startEpoch: startEpoch, endEpoch: endEpoch
            )
        case Self.actionRecapBreak15:
            await recordRecap(
                userText: userText, breakMinutes: 15,
                sessionNumber: sessionNumber,
                startEpoch: startEpoch, endEpoch: endEpoch
            )
        case Self.actionFiveMore:
            // Continue the same session: reschedule a 5-minute focus completion
            // preserving the original start so the eventual recap spans it all.
            scheduleFocusComplete(
                in: 5 * 60,
                sessionNumber: sessionNumber,
                startEpoch: startEpoch
            )
        default:
            break   // Plain tap opens the app; the in-app flow takes over.
        }
    }

    // MARK: - Background recap handling

    private func recordRecap(
        userText: String,
        breakMinutes: Int,
        sessionNumber: Int,
        startEpoch: Double,
        endEpoch: Double
    ) async {
        guard let sessionStore, let calendarService else { return }

        let start = Date(timeIntervalSince1970: startEpoch)
        let end = Date(timeIntervalSince1970: endEpoch)
        let duration = max(1, Int(end.timeIntervalSince(start) / 60))
        let recap = userText.trimmingCharacters(in: .whitespacesAndNewlines)

        var session = PomodoroSession(
            sessionNumber: sessionNumber,
            start: start,
            end: end,
            durationMinutes: duration,
            breakDurationMinutes: breakMinutes,
            recap: recap
        )

        // Load existing sessions first so we append rather than overwrite the
        // recaps file — the app may have been cold-launched just for this reply.
        await sessionStore.load()
        if let eventID = await calendarService.createEvent(for: session) {
            session.calendarEventIdentifier = eventID
        }
        await sessionStore.append(session)

        // Continue the Messages-style loop: notify when the break finishes.
        scheduleBreakComplete(in: TimeInterval(breakMinutes * 60))
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted {
                print("[Notifications] Authorization not granted.")
            }
        } catch {
            print("[Notifications] Auth error: \(error)")
        }
    }

    // MARK: - Scheduling

    func scheduleFocusComplete(
        in interval: TimeInterval,
        sessionNumber: Int,
        startEpoch: TimeInterval
    ) {
        guard interval > 0 else { return }
        let userInfo: [String: Any] = [
            Self.sessionNumberKey: sessionNumber,
            Self.startEpochKey: startEpoch,
            // Planned completion time — used as the session's end timestamp
            // when the recap is logged from the notification.
            Self.endEpochKey: Date().addingTimeInterval(interval).timeIntervalSince1970
        ]
        schedule(
            id: focusNotificationID,
            title: "Focus Session Complete 🎉",
            body: "Nice work! Pull down to log your recap and pick a break.",
            interval: interval,
            categoryIdentifier: Self.categoryFocusComplete,
            userInfo: userInfo
        )
    }

    func scheduleBreakComplete(in interval: TimeInterval) {
        guard interval > 0 else { return }
        schedule(
            id: breakNotificationID,
            title: "Break's Over ☕️",
            body: "Ready for another round? Tap to start your next session.",
            interval: interval
        )
    }

    // MARK: - Cancel

    func cancelAll() {
        center.removePendingNotificationRequests(
            withIdentifiers: [focusNotificationID, breakNotificationID]
        )
        center.removeDeliveredNotifications(
            withIdentifiers: [focusNotificationID, breakNotificationID]
        )
    }

    // MARK: - Private

    private func schedule(
        id: String,
        title: String,
        body: String,
        interval: TimeInterval,
        categoryIdentifier: String? = nil,
        userInfo: [String: Any] = [:]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = userInfo
        if let categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: false
        )

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        // Remove any stale request with the same ID first
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(request) { error in
            if let error { print("[Notifications] Schedule failed: \(error)") }
        }
    }
}
