import SwiftUI

/// Phase 4 — Break countdown.
/// Mirrors phase_break in PomoTimerSD.zsh (--blurscreen, encourages stepping away).
/// The macOS blur overlay stays on from the transition phase; this view
/// shows a calming break countdown on top of it.
struct BreakView: View {

    @EnvironmentObject var vm: TimerViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 28) {

                // Icon
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Color.pomoMint)

                VStack(spacing: 8) {
                    Text("Break Time")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text("Step away, stretch, grab a drink.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                // Countdown ring
                ZStack {
                    Circle()
                        .stroke(Color.pomoMint.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: 1 - vm.timerProgress)
                        .stroke(
                            Color.pomoMint,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: vm.timerProgress)

                    Text(vm.timerDisplay)
                        .font(.system(size: 48, weight: .thin, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                }
                .frame(width: 180, height: 180)

                Text("\(vm.breakMinutes) min break")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                // Skip button
                Button {
                    vm.skipBreak()
                } label: {
                    Label("Skip Break", systemImage: "forward.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Spacer()
            }
            .padding(.vertical, 28)
            .containerRelativeFrame(.horizontal) { width, _ in
                width * 0.88
            }
        }
    }
}

#Preview {
    BreakView()
        .environmentObject(TimerViewModel())
}
