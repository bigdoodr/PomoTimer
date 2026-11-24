import SwiftUI

/// Final screen — day summary with stats, storage location, and share options.
/// Mirrors show_summary in PomoTimerSD.zsh, extended with ICS export.
struct SummaryView: View {

    @EnvironmentObject var vm: TimerViewModel
    @EnvironmentObject var store: SessionStore
    @EnvironmentObject var calendarService: CalendarService

    @AppStorage(SessionStore.customJSONDirectoryKey) private var customJSONPath: String = ""

    @State private var showShareSheet = false
    @State private var icsURLsToShare: [URL] = []

    var body: some View {
        GeometryReader { proxy in
        ScrollView {
            VStack(spacing: 14) {
                Spacer(minLength: 0)

                // Trophy header
                VStack(spacing: 8) {
                    Image(systemName: "trophy.circle.fill")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.4), radius: 16)

                    Text("Great Work!")
                        .font(.largeTitle.bold())

                    Text("You crushed it today.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                // Stats cards
                HStack(spacing: 16) {
                    StatCard(
                        value: "\(todaySessions.count)",
                        label: "Sessions",
                        icon: "flame.fill",
                        color: .pomoRed
                    )
                    StatCard(
                        value: "\(todaySessions.reduce(0) { $0 + $1.durationMinutes })",
                        label: "Minutes focused",
                        icon: "clock.fill",
                        color: .pomoIndigo
                    )
                }

                // Storage info
                VStack(alignment: .leading, spacing: 6) {
                    storageRow(
                        icon: "doc.text.fill",
                        label: "Recaps saved",
                        detail: recapsSavedDetail
                    )
                    storageRow(
                        icon: "calendar.badge.plus",
                        label: "Calendar events",
                        detail: calendarService.isAuthorized ? "Added to Calendar.app" : "Not connected"
                    )
                }
                .padding(12)
                .background(Color.pomoSurface, in: RoundedRectangle(cornerRadius: 14))

                // Commitments ("I'm tasked to…")
                CommitmentQuickAddView(store: store)

                // Export ICS files for Outlook
                Button {
                    exportICSFiles()
                } label: {
                    Label("Export .ics for Outlook", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(Color.pomoIndigo)

                // Start a new day
                Button {
                    vm.resetForNewDay()
                } label: {
                    Label("Start Fresh", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pomoIndigo)
                .cornerRadius(14)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .frame(minHeight: proxy.size.height)
        }
        .scrollBounceBehavior(.basedOnSize)
        }
        .containerRelativeFrame(.horizontal) { width, _ in
            min(width * 0.88, 520)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: icsURLsToShare)
        }
    }

    // MARK: - Private

    /// Sessions that started today. Derived from the store (not the in-memory
    /// counters) so the totals respect the date change and survive relaunches.
    private var todaySessions: [PomodoroSession] {
        store.sessions.filter { Calendar.current.isDateInToday($0.startDate) }
    }

    private var recapsSavedDetail: String {
        customJSONPath.isEmpty ? "Not saved" : abbreviate(customJSONPath)
    }

    private func abbreviate(_ path: String) -> String {
        if let home = NSHomeDirectory() as String?, path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        // Folders picked via the document picker (Files app, iCloud Drive,
        // "On My iPhone") resolve to a File Provider path that never starts
        // with our sandbox's home directory — fall back to just the folder
        // name so we never show raw internal container paths.
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent().lastPathComponent
        return parent.isEmpty ? url.lastPathComponent : "\u{2026}/\(parent)/\(url.lastPathComponent)"
    }

    private func storageRow(icon: String, label: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.pomoIndigo)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(detail).font(.subheadline.weight(.medium))
            }
            Spacer()
        }
    }

    private func exportICSFiles() {
        guard let icsDir = store.icsDirectoryURL else { return }

        let todaySessions = vm.completedSessions
        let sourceURLs = todaySessions.compactMap { session in
            calendarService.writeICSFile(for: session, into: icsDir)
        }
        guard !sourceURLs.isEmpty else { return }

#if os(macOS)
        NSWorkspace.shared.activateFileViewerSelecting(sourceURLs)
#else
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PomoTimer-Export")
        try? FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )

        icsURLsToShare = sourceURLs.compactMap { source in
            let dest = tempDir.appendingPathComponent(source.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.copyItem(at: source, to: dest)
                return dest
            } catch {
                print("[Export] Copy failed: \(error)")
                return nil
            }
        }
        guard !icsURLsToShare.isEmpty else { return }
        showShareSheet = true
#endif
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.pomoSurface, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - ShareSheet (cross-platform)

struct ShareSheet: View {
    let items: [Any]

    var body: some View {
#if os(iOS)
        ActivityViewControllerRepresentable(items: items)
#else
        // On macOS, use NSSharingServicePicker via a hosting approach
        MacShareView(items: items)
#endif
    }
}

#if os(iOS)
import UIKit

private struct ActivityViewControllerRepresentable: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
#else
import AppKit

private struct MacShareView: View {
    let items: [Any]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("ICS files ready to share")
                .font(.headline)
            Button("Show in Finder") {
                let urls = items.compactMap { $0 as? URL }
                if !urls.isEmpty {
                    NSWorkspace.shared.activateFileViewerSelecting(urls)
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}
#endif

#Preview {
    SummaryView()
        .environmentObject(TimerViewModel())
        .environmentObject(SessionStore())
        .environmentObject(CalendarService())
}
