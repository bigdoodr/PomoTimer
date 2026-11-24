import Foundation

/// A focus session that has started but whose recap hasn't been saved yet.
///
/// Persisted in UserDefaults so that, on iOS, a session that expired while the
/// app was terminated can still reopen on the recap screen instead of being
/// lost. Cleared as soon as the session is recorded (in-app or from the
/// notification's inline reply).
struct PendingSession: Codable, Equatable {
    var startEpoch: TimeInterval
    var endEpoch: TimeInterval
    var sessionNumber: Int
    var intention: String

    private static let defaultsKey = "pendingFocusSession"

    /// Pending sessions older than this are discarded rather than restored.
    static let maxAge: TimeInterval = 6 * 60 * 60

    static func load() -> PendingSession? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(PendingSession.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    /// Moves the end time of the stored session (e.g. "5 More Minutes" chosen
    /// from the notification while the app isn't running).
    static func updateEnd(to endEpoch: TimeInterval) {
        guard var pending = load() else { return }
        pending.endEpoch = endEpoch
        pending.save()
    }
}
