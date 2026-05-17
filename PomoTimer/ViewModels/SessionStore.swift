import Foundation
import Combine

/// Persists session data as a JSON array of PomodoroSession objects.
///
/// The user must choose a destination folder in Settings before any session
/// can be recorded — the app never creates files in iCloud or local Documents
/// on its own. The chosen folder is remembered via a security-scoped bookmark.
@MainActor
final class SessionStore: ObservableObject {

    // MARK: - Published
    @Published private(set) var sessions: [PomodoroSession] = []
    @Published private(set) var hasConfiguredStorage: Bool = false

    // MARK: - Settings keys (display path + bookmark data)

    static let customJSONDirectoryKey      = "customJSONDirectoryPath"
    static let customICSDirectoryKey       = "customICSDirectoryPath"
    static let customJSONBookmarkKey       = "customJSONDirectoryBookmark"
    static let customICSBookmarkKey        = "customICSDirectoryBookmark"

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
    }

    func append(_ session: PomodoroSession) async {
        sessions.append(session)
        await persist()
    }

    func deleteSession(id: UUID) async {
        sessions.removeAll { $0.id == id }
        await persist()
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
