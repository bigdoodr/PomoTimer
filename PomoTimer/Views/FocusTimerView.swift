import SwiftUI

/// Phase 2 — Running focus countdown.
/// On macOS this view lives in the app's compact window (position it in a
/// corner via Window menu or drag). On iOS it fills the screen.
/// Mirrors phase_focus in PomoTimerSD.zsh (--position bottomright, --ontop).
struct FocusTimerView: View {

    @EnvironmentObject var vm: TimerViewModel

    var body: some View {
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
        // Keep window compact and on top while focusing
        .onAppear {
            NSApplication.shared.windows.forEach { win in
                win.level = .floating
                win.setContentSize(NSSize(width: 340, height: 480))
            }
        }
        .onDisappear {
            NSApplication.shared.windows.forEach { $0.level = .normal }
        }
#endif
    }
}

#Preview {
    FocusTimerView()
        .environmentObject(TimerViewModel())
}
