import UserNotifications

/// Manages local notifications for background timer expiration.
///
/// On iOS the app process is suspended when the user switches away, so the only
/// way to signal "your timer is done" is a UNUserNotificationCenter local
/// notification. On macOS the app stays alive, but we still schedule
/// notifications for consistency (the user may minimize the app).
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    private let center = UNUserNotificationCenter.current()

    // Stable identifiers so we can cancel them later
    private let focusNotificationID = "com.casey.PomoTimer.focus_complete"
    private let breakNotificationID = "com.casey.PomoTimer.break_complete"

    override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
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

    func scheduleFocusComplete(in interval: TimeInterval) {
        guard interval > 0 else { return }
        schedule(
            id: focusNotificationID,
            title: "Focus Session Complete 🎉",
            body: "Nice work! Open PomoLedger to log your recap and start a break.",
            interval: interval
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

    private func schedule(id: String, title: String, body: String, interval: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive

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
