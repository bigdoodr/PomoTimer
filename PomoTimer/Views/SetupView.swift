import SwiftUI
import UniformTypeIdentifiers

/// Phase 1 — Choose focus duration and kick off a session.
/// Mirrors phase_setup in PomoTimerSD.zsh.
struct SetupView: View {

    @EnvironmentObject var vm: TimerViewModel
    @EnvironmentObject var store: SessionStore

    @State private var selectedMinutes: Int = 25
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showFolderPicker = false
    @AppStorage("hasSeenSettingsTip") private var hasSeenSettingsTip = false
    @State private var showSettingsTip = false

    private let durationOptions: [(label: String, minutes: Int)] = [
        ("15 min",              15),
        ("20 min",              20),
        ("25 min — Classic",    25),
        ("30 min",              30),
        ("45 min",              45),
        ("50 min",              50),
        ("60 min",              60),
    ]

    var body: some View {
        VStack(spacing: 32) {
            // Header
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Color.pomoIndigo)

                    Text("PomoLedger")
                        .font(.largeTitle.bold())

                    Text("Ready to focus?")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .trailing, spacing: 6) {
                    Button {
                        dismissTip()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    if showSettingsTip {
                        settingsTipBubble
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topTrailing)))
                    }
                }
            }
            .padding(.top, 8)

            // Duration picker
            VStack(alignment: .leading, spacing: 12) {
                Label("Focus Duration", systemImage: "clock")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Picker("Focus Duration", selection: $selectedMinutes) {
                    ForEach(durationOptions, id: \.minutes) { opt in
                        Text(opt.label).tag(opt.minutes)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.pomoSurface, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 4)

            // CTA
            if store.hasConfiguredStorage {
                Button {
                    vm.beginFocusSession(focusMinutes: selectedMinutes)
                } label: {
                    Label("Start Focusing", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pomoIndigo)
                .cornerRadius(14)
            } else {
                folderRequiredPrompt
            }

            // Subtle history link
            if !store.sessions.isEmpty {
                Button {
                    showHistory = true
                } label: {
                    Label(
                        "\(store.sessions.count) session\(store.sessions.count == 1 ? "" : "s") recorded",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.vertical, 28)
        .containerRelativeFrame(.horizontal) { width, _ in
            min(width * 0.88, 520)
        }
        .sheet(isPresented: $showHistory) {
            SessionHistoryView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            store.resetJSONDirectoryCache()
            SessionStore.saveBookmark(
                for: url,
                pathKey: SessionStore.customJSONDirectoryKey,
                bookmarkKey: SessionStore.customJSONBookmarkKey
            )
            Task { await store.load() }
        }
        .onAppear {
            if !hasSeenSettingsTip {
                withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
                    showSettingsTip = true
                }
            }
        }
    }

    // MARK: - First-launch settings tip

    private var settingsTipBubble: some View {
        Button {
            dismissTip()
            showSettings = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                Text("Set where your recaps and calendar files are saved")
                    .font(.caption)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.pomoIndigo, in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func dismissTip() {
        withAnimation { showSettingsTip = false }
        hasSeenSettingsTip = true
    }

    // MARK: - Folder-required prompt

    private var folderRequiredPrompt: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.title3)
                    .foregroundStyle(Color.pomoIndigo)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose where to save your recaps")
                        .font(.subheadline.weight(.semibold))
                    Text("PomoLedger needs a folder to store recaps.json and calendar files before you start.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Button {
                showFolderPicker = true
            } label: {
                Label("Choose Folder\u{2026}", systemImage: "folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.pomoIndigo)
            .cornerRadius(14)
        }
        .padding(16)
        .background(Color.pomoSurface, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    SetupView()
        .environmentObject(TimerViewModel())
        .environmentObject(SessionStore())
}
