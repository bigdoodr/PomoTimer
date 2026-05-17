import SwiftUI

/// Phase 5 — After the break, ask whether to start another session.
/// Mirrors phase_continue in PomoTimerSD.zsh.
struct ContinueView: View {

    @EnvironmentObject var vm: TimerViewModel

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            // Icon + headline
            VStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(Color.pomoIndigo)

                Text("Break's Over!")
                    .font(.title.bold())

                Text("You've completed **\(vm.sessionCount)** session\(vm.sessionCount == 1 ? "" : "s") today — \(vm.totalFocusMinutesToday) min of focused work.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Actions
            VStack(spacing: 14) {
                Button {
                    vm.startNextSession()
                } label: {
                    Label("Start Next Session", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pomoIndigo)
                .cornerRadius(14)

                Button {
                    vm.endDay()
                } label: {
                    Text("I'm Done for Now")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            .padding(.horizontal, 4)

            Spacer()
        }
        .padding(.vertical, 28)
        .containerRelativeFrame(.horizontal) { width, _ in
            min(width * 0.88, 420)
        }
    }
}

#Preview {
    ContinueView()
        .environmentObject(TimerViewModel())
}
