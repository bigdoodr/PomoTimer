import Foundation
import Combine

/// Persists session data as a JSON array of PomodoroSession objects.
///
/// The user must choose a destination folder in Settings before any session
/// can be recorded — the app never creates files in iCloud or local Documents
/// on its own. The chosen folder is remembered via a security-scoped bookmark.
@MainActor
final class SessionStore: ObservableObject {

    /// How often the recaps file rolls over into a dated archive automatically.
    enum RolloverMode: String, CaseIterable, Identifiable {
        case off, weekly, monthly
        var id: String { rawValue }
        var label: String {
            switch self {
            case .off:     return "Off"
            case .weekly:  return "Weekly"
            case .monthly: return "Monthly"
            }
        }
    }

    // MARK: - Published
    @Published private(set) var sessions: [PomodoroSession] = []
    @Published private(set) var hasConfiguredStorage: Bool = false

    // MARK: - Settings keys (display path + bookmark data)

    static let customJSONDirectoryKey      = "customJSONDirectoryPath"
    static let customICSDirectoryKey       = "customICSDirectoryPath"
    static let customJSONBookmarkKey       = "customJSONDirectoryBookmark"
    static let customICSBookmarkKey        = "customICSDirectoryBookmark"

    // Automatic rollover settings
    static let autoRolloverModeKey         = "autoRolloverMode"        // RolloverMode.rawValue
    static let weeklyRolloverWeekdayKey    = "weeklyRolloverWeekday"   // 1 = Sun … 7 = Sat
    static let defaultWeekStartWeekday     = 2                          // Monday

    /// Parses a session `date` string ("YYYY-MM-DD").
    private static let dateParser: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Private

    private let filename = "recaps.json"

    private var recapsURL: URL? {
        didSet { hasConfiguredStorage = recapsURL != nil }
    }

    private var jsonScopedURL: URL?
    private var icsScopedURL: URL?

    // MARK: - Init

    init() {}

    // MARK: - Public API

    func load() async {
        recapsURL = resolveStorageURL()
        guard let url = recapsURL else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([PomodoroSession].self, from: data)
            sessions = decoded.sorted { $0.startEpoch < $1.startEpoch }
        } catch CocoaError.fileReadNoSuchFile, CocoaError.fileNoSuchFile {
            // First launch — empty file is fine
            sessions = []
        } catch {
            print("[SessionStore] Load failed: \(error)")
        }

        // A new period may have begun while the app was closed.
        await performAutoRolloverIfNeeded()
    }

    func append(_ session: PomodoroSession) async {
        // Roll the previous period into an archive before the new session
        // starts populating a fresh file.
        await performAutoRolloverIfNeeded()
        sessions.append(session)
        await persist()
    }

    func deleteSession(id: UUID) async {
        sessions.removeAll { $0.id == id }
        await persist()
    }

    // MARK: - Archiving

    /// Archives the current `recaps.json`, renaming it for the date range it
    /// covers (e.g. `recaps.2026-05-28-thru-2026-06-02.json`), then starts a
    /// fresh empty recaps file. Returns the archive URL, or nil if there is
    /// nothing to archive.
    @discardableResult
    func archiveAndStartNew() async -> URL? {
        guard let url = recapsURL, !sessions.isEmpty else { return nil }

        let dates = sessions.map { $0.date }.sorted()
        let first = dates.first ?? dates.last ?? ""
        let last = dates.last ?? first
        let archiveName = "recaps.\(first)-thru-\(last).json"
        let archiveURL = url.deletingLastPathComponent().appendingPathComponent(archiveName)

        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: url.path) {
                if fm.fileExists(atPath: archiveURL.path) {
                    try fm.removeItem(at: archiveURL)
                }
                try fm.moveItem(at: url, to: archiveURL)
            }
            // Start fresh — persist() recreates recaps.json with an empty array.
            sessions = []
            await persist()
            return archiveURL
        } catch {
            print("[SessionStore] Archive failed: \(error)")
            return nil
        }
    }

    /// If automatic rollover is enabled and the recaps file holds sessions from
    /// a period that has already ended, archives them and starts a fresh file.
    func performAutoRolloverIfNeeded(now: Date = Date()) async {
        let defaults = UserDefaults.standard
        let mode = RolloverMode(
            rawValue: defaults.string(forKey: Self.autoRolloverModeKey) ?? ""
        ) ?? .off
        guard mode != .off, !sessions.isEmpty else { return }

        // Earliest date currently covered by the file.
        guard let earliest = sessions.map(\.date).min(),
              let earliestDate = Self.dateParser.date(from: earliest) else { return }

        let storedWeekday = defaults.integer(forKey: Self.weeklyRolloverWeekdayKey)
        let weekStart = storedWeekday == 0 ? Self.defaultWeekStartWeekday : storedWeekday
        let currentPeriodStart = Self.periodStart(
            for: now, mode: mode, weekStartWeekday: weekStart
        )

        // Anything dated before the current period belongs to a closed period.
        if earliestDate < currentPeriodStart {
            await archiveAndStartNew()
        }
    }

    /// First moment of the period (week or month) containing `date`.
    private static func periodStart(
        for date: Date, mode: RolloverMode, weekStartWeekday: Int
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: date)
        switch mode {
        case .off:
            return startOfDay
        case .weekly:
            calendar.firstWeekday = weekStartWeekday
            return calendar.dateInterval(of: .weekOfYear, for: startOfDay)?.start ?? startOfDay
        case .monthly:
            return calendar.dateInterval(of: .month, for: startOfDay)?.start ?? startOfDay
        }
    }

    // MARK: - ICS export helpers

    /// Returns the URL of the ICS output directory.
    /// Uses a custom bookmark from Settings if configured, otherwise the `sessions/`
    /// subfolder next to `recaps.json`.
    var icsDirectoryURL: URL? {
        if let url = resolveBookmark(
            dataKey: Self.customICSBookmarkKey,
            pathKey: Self.customICSDirectoryKey,
            cached: &icsScopedURL
        ) {
            return ensureDirectory(url)
        }
        guard let sessionsDir = recapsURL?
            .deletingLastPathComponent()
            .appendingPathComponent("sessions") else { return nil }
        return ensureDirectory(sessionsDir)
    }

    // MARK: - Private

    /// Returns the recaps.json URL inside the user-selected directory, or nil
    /// if the user has not yet chosen a folder. The app never falls back to a
    /// system-chosen location.
    private func resolveStorageURL() -> URL? {
        guard let dir = resolveBookmark(
            dataKey: Self.customJSONBookmarkKey,
            pathKey: Self.customJSONDirectoryKey,
            cached: &jsonScopedURL
        ) else { return nil }
        return ensureDirectory(dir)?.appendingPathComponent(filename)
    }

    @discardableResult
    private func ensureDirectory(_ url: URL) -> URL? {
        do {
            try FileManager.default.createDirectory(
                at: url, withIntermediateDirectories: true
            )
            return url
        } catch {
            print("[SessionStore] Could not create directory \(url.path): \(error)")
            return nil
        }
    }

    /// Resolves a security-scoped bookmark stored in UserDefaults.
    /// Returns nil if no bookmark is saved or if the path key is empty.
    private func resolveBookmark(
        dataKey: String, pathKey: String, cached: inout URL?
    ) -> URL? {
        if let cached { return cached }

        let defaults = UserDefaults.standard
        guard !(defaults.string(forKey: pathKey) ?? "").isEmpty,
              let data = defaults.data(forKey: dataKey) else { return nil }

        var isStale = false
        #if os(macOS)
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        #else
        guard let url = try? URL(
            resolvingBookmarkData: data,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        #endif

        if isStale {
            #if os(macOS)
            let fresh = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #else
            let fresh = try? url.bookmarkData()
            #endif
            if let fresh { defaults.set(fresh, forKey: dataKey) }
        }

        _ = url.startAccessingSecurityScopedResource()
        cached = url
        return url
    }

    /// Saves a security-scoped bookmark for a URL chosen by the user.
    static func saveBookmark(
        for url: URL, pathKey: String, bookmarkKey: String
    ) {
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }

        let defaults = UserDefaults.standard
        defaults.set(url.path, forKey: pathKey)
        #if os(macOS)
        let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #else
        let data = try? url.bookmarkData()
        #endif
        if let data { defaults.set(data, forKey: bookmarkKey) }
    }

    func resetJSONDirectoryCache() {
        jsonScopedURL?.stopAccessingSecurityScopedResource()
        jsonScopedURL = nil
    }

    func resetICSDirectoryCache() {
        icsScopedURL?.stopAccessingSecurityScopedResource()
        icsScopedURL = nil
    }

    /// Clears a custom directory setting and its bookmark.
    static func clearBookmark(pathKey: String, bookmarkKey: String) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: pathKey)
        defaults.removeObject(forKey: bookmarkKey)
    }

    private func persist() async {
        guard let url = recapsURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sessions)
            try data.write(to: url, options: .atomicWrite)
        } catch {
            print("[SessionStore] Save failed: \(error)")
        }
    }
}
