import SwiftUI
import UniformTypeIdentifiers
import EventKit

struct SettingsView: View {

    @EnvironmentObject var store: SessionStore
    @EnvironmentObject var calendarService: CalendarService

    @AppStorage(SessionStore.customJSONDirectoryKey) private var customJSONPath: String = ""
    @AppStorage(SessionStore.customICSDirectoryKey) private var customICSPath: String = ""
    @AppStorage(CalendarService.selectedCalendarIdentifierKey) private var selectedCalendarID: String = ""
    @AppStorage(SessionStore.autoRolloverModeKey) private var rolloverModeRaw: String = SessionStore.RolloverMode.off.rawValue
    @AppStorage(SessionStore.weeklyRolloverWeekdayKey) private var rolloverWeekday: Int = SessionStore.defaultWeekStartWeekday

    private enum PickerTarget { case json, ics }
    @State private var activePickerTarget: PickerTarget?
    @State private var showPicker = false

    @State private var availableCalendars: [EKCalendar] = []
    @State private var showArchiveConfirm = false
    @State private var archiveResultMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 24) {
                    directorySection(
                        title: "JSON Recaps",
                        icon: "doc.text.fill",
                        currentPath: jsonDisplayPath,
                        isCustom: !customJSONPath.isEmpty,
                        onPick: {
                            activePickerTarget = .json
                            showPicker = true
                        },
                        onReset: {
                            store.resetJSONDirectoryCache()
                            SessionStore.clearBookmark(
                                pathKey: SessionStore.customJSONDirectoryKey,
                                bookmarkKey: SessionStore.customJSONBookmarkKey
                            )
                            customJSONPath = ""
                            Task { await store.load() }
                        }
                    )

                    directorySection(
                        title: "ICS Calendar Files",
                        icon: "calendar",
                        currentPath: icsDisplayPath,
                        isCustom: !customICSPath.isEmpty,
                        onPick: {
                            activePickerTarget = .ics
                            showPicker = true
                        },
                        onReset: {
                            store.resetICSDirectoryCache()
                            SessionStore.clearBookmark(
                                pathKey: SessionStore.customICSDirectoryKey,
                                bookmarkKey: SessionStore.customICSBookmarkKey
                            )
                            customICSPath = ""
                        }
                    )

                    calendarSection

                    archiveSection

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .frame(minWidth: 400, minHeight: 340)
        .background(Color.pomoBackground)
        .task { availableCalendars = await calendarService.loadWritableCalendars() }
        .confirmationDialog(
            "Archive current recaps and start a new file?",
            isPresented: $showArchiveConfirm,
            titleVisibility: .visible
        ) {
            Button("Archive & Start New", role: .destructive) {
                Task {
                    if let url = await store.archiveAndStartNew() {
                        archiveResultMessage = "Archived as \u{201C}\(url.lastPathComponent)\u{201D}"
                    } else {
                        archiveResultMessage = "Nothing to archive yet."
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current recaps.json is renamed for the dates it covers, and a fresh empty file is started.")
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            switch activePickerTarget {
            case .json:
                store.resetJSONDirectoryCache()
                SessionStore.saveBookmark(
                    for: url,
                    pathKey: SessionStore.customJSONDirectoryKey,
                    bookmarkKey: SessionStore.customJSONBookmarkKey
                )
                customJSONPath = url.path
                Task { await store.load() }
            case .ics:
                store.resetICSDirectoryCache()
                SessionStore.saveBookmark(
                    for: url,
                    pathKey: SessionStore.customICSDirectoryKey,
                    bookmarkKey: SessionStore.customICSBookmarkKey
                )
                customICSPath = url.path
            case .none:
                break
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.title2.bold())
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private func directorySection(
        title: String,
        icon: String,
        currentPath: String,
        isCustom: Bool,
        onPick: @escaping () -> Void,
        onReset: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: isCustom ? "folder.fill" : "folder.badge.questionmark")
                        .foregroundStyle(isCustom ? Color.pomoIndigo : .secondary)
                        .frame(width: 18)
                    Text(currentPath)
                        .font(.subheadline)
                        .foregroundStyle(isCustom ? .primary : .secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Spacer()
                }

                HStack(spacing: 12) {
                    Button("Choose Folder\u{2026}", action: onPick)
                        .buttonStyle(.bordered)

                    if isCustom {
                        Button("Clear", action: onReset)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            .padding(14)
            .background(Color.pomoSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Calendar selection

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Calendar for Events", systemImage: "calendar.badge.plus")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                if availableCalendars.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text("No calendars available. Grant Calendar access to choose one.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Spacer()
                    }
                } else {
                    Picker("Save events to", selection: $selectedCalendarID) {
                        Text("Default Calendar").tag("")
                        ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                            Text(calendar.title).tag(calendar.calendarIdentifier)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(Color.pomoSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Archive recaps

    private var archiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reports & Archiving", systemImage: "archivebox.fill")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Archive the current recaps and begin a fresh file, ready for the next reporting period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Archive & Start New File\u{2026}") {
                    showArchiveConfirm = true
                }
                .buttonStyle(.bordered)
                .disabled(store.sessions.isEmpty)

                if let archiveResultMessage {
                    Text(archiveResultMessage)
                        .font(.caption)
                        .foregroundStyle(Color.pomoIndigo)
                }

                Divider()
                    .padding(.vertical, 4)

                Picker("Automatic rollover", selection: $rolloverModeRaw) {
                    ForEach(SessionStore.RolloverMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }

                if rolloverModeRaw == SessionStore.RolloverMode.weekly.rawValue {
                    Picker("Week starts on", selection: $rolloverWeekday) {
                        ForEach(weekdayOptions, id: \.weekday) { option in
                            Text(option.name).tag(option.weekday)
                        }
                    }
                }

                Text(rolloverDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.pomoSurface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Weekday choices (1 = Sunday … 7 = Saturday) using localized names.
    private var weekdayOptions: [(weekday: Int, name: String)] {
        let symbols = Calendar.current.weekdaySymbols   // index 0 = Sunday
        return symbols.enumerated().map { (weekday: $0.offset + 1, name: $0.element) }
    }

    private var rolloverDescription: String {
        switch SessionStore.RolloverMode(rawValue: rolloverModeRaw) ?? .off {
        case .off:
            return "Recaps keep accumulating until you archive manually."
        case .weekly:
            let day = weekdayOptions.first { $0.weekday == rolloverWeekday }?.name ?? "Monday"
            return "Recaps from the previous week are archived automatically when a new week begins on \(day)."
        case .monthly:
            return "Recaps from the previous month are archived automatically when a new month begins."
        }
    }

    // MARK: - Display paths

    private var jsonDisplayPath: String {
        customJSONPath.isEmpty ? "No folder selected" : abbreviate(customJSONPath)
    }

    private var icsDisplayPath: String {
        if !customICSPath.isEmpty { return abbreviate(customICSPath) }
        if !customJSONPath.isEmpty { return abbreviate(customJSONPath) + "/sessions" }
        return "No folder selected"
    }

    private func abbreviate(_ path: String) -> String {
        if let home = NSHomeDirectory() as String? {
            if path.hasPrefix(home) {
                return "~" + path.dropFirst(home.count)
            }
        }
        return path
    }
}

#Preview {
    SettingsView()
        .environmentObject(SessionStore())
        .environmentObject(CalendarService())
}
