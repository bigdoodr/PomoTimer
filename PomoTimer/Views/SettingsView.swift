import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @EnvironmentObject var store: SessionStore

    @AppStorage(SessionStore.customJSONDirectoryKey) private var customJSONPath: String = ""
    @AppStorage(SessionStore.customICSDirectoryKey) private var customICSPath: String = ""

    private enum PickerTarget { case json, ics }
    @State private var activePickerTarget: PickerTarget?
    @State private var showPicker = false

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

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .frame(minWidth: 400, minHeight: 340)
        .background(Color.pomoBackground)
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
}
