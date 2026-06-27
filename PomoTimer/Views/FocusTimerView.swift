import SwiftUI

/// Phase 2 — Running focus countdown.
///
/// On macOS this view lives in a compact, always-on-top window. It also
/// supports a "mini player" mode (à la Apple Music): a tiny floating window
/// showing just the ring, time, and a couple of controls. The window grows
/// back to full size automatically when the timer expires (see
/// TimerViewModel.showBlur → MacWindowManager.growForRecap).
///
/// On iOS the view always fills the screen.
struct FocusTimerView: View {

    @EnvironmentObject var vm: TimerViewModel

#if os(macOS)
    /// Persisted so the user's mini-player preference survives across sessions.
    @AppStorage("pomoMiniPlayer") private var isMiniPlayer: Bool = false
#endif

    var body: some View {
#if os(macOS)
        Group {
            if isMiniPlayer {
                miniLayout
            } else {
                fullLayout
            }
        }
        .onAppear {
            if isMiniPlayer {
                MacWindowManager.shared.enterMiniPlayer()
            } else {
                MacWindowManager.shared.enterFocus()
            }
        }
#else
        fullLayout
#endif
    }

    // MARK: - Full layout

    private var fullLayout: some View {
        VStack(spacing: 28) {

            // Session badge
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.caption)
                Text("Session \(vm.sessionCount)")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.pomoSurface, in: Capsule())

            // Big countdown ring
            ZStack {
                Circle()
                    .stroke(Color.pomoIndigo.opacity(0.15), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: 1 - vm.timerProgress)
                    .stroke(
                        Color.pomoIndigo,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: vm.timerProgress)

                VStack(spacing: 4) {
                    Text(vm.timerDisplay)
                        .font(.system(size: 54, weight: .thin, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))

                    Text("\(vm.focusMinutes) min session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)

            // Status label
            Text("Focusing 🧐")
                .font(.title3.weight(.medium))

            // End early button
            Button(role: .destructive) {
                vm.endFocusEarly()
            } label: {
                Label("End Session Early", systemImage: "stop.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Spacer()
        }
        .padding(.vertical, 28)
        .containerRelativeFrame(.horizontal) { width, _ in
            min(width * 0.88, 400)
        }
#if os(macOS)
        // Mini-player toggle, tucked in the top-trailing corner.
        .overlay(alignment: .topTrailing) {
            Button {
                setMiniPlayer(true)
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(12)
            .help("Mini Player")
        }
#endif
    }

#if os(macOS)
    // MARK: - Mini player layout (macOS only)

    private var miniLayout: some View {
        HStack(spacing: 14) {
            // Small countdown ring
            ZStack {
                Circle()
                    .stroke(Color.pomoIndigo.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: 1 - vm.timerProgress)
                    .stroke(
                        Color.pomoIndigo,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: vm.timerProgress)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 1) {
                Text(vm.timerDisplay)
                    .font(.system(size: 24, weight: .regular, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                Text("Session \(vm.sessionCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button {
                    setMiniPlayer(false)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("Expand")

                Button(role: .destructive) {
                    vm.endFocusEarly()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .help("End Session Early")
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Toggle mini-player mode and resize the window to match.
    private func setMiniPlayer(_ enabled: Bool) {
        isMiniPlayer = enabled
        if enabled {
            MacWindowManager.shared.enterMiniPlayer()
        } else {
            MacWindowManager.shared.enterFocus()
        }
    }
#endif
}

#Preview {
    FocusTimerView()
        .environmentObject(TimerViewModel())
}
