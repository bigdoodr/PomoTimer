import SwiftUI

/// Phase 3 — Blur screen, collect recap, choose break length.
/// Mirrors phase_break_transition in PomoTimerSD.zsh
/// (--blurscreen, --textfield editor, --selecttitle Break Length, --button2 "5 More Minutes").
///
/// On macOS the ScreenBlurManager overlay is already showing behind this window.
/// On iOS this view fills the screen with a deep background, approximating the blur.
struct BreakTransitionView: View {

    @EnvironmentObject var vm: TimerViewModel

    @State private var recap: String = ""
    @State private var selectedBreakMinutes: Int = 5
    @FocusState private var recapFocused: Bool

    private let breakOptions: [(label: String, minutes: Int)] = [
        ("5 min — Standard",    5),
        ("10 min — Extended",   10),
        ("15 min — Long Break", 15),
        ("30 min — Lunch",      30),
        ("60 min — Long Lunch", 60),
    ]

    var body: some View {
        ZStack {
            // Deep backdrop (iOS blur stand-in; on macOS the NSPanel handles this)
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {

                    // Completion badge
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 52))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.pomoRed, Color.pomoMint)

                        Text("Session \(vm.sessionCount) Complete!")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        Text("You focused for **\(vm.elapsedFocusMinutes) min**. Nice work.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // Recap editor
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What did you work on?", systemImage: "pencil.line")
                            .font(.headline)
                            .foregroundStyle(.white)

                        TextEditor(text: $recap)
                            .focused($recapFocused)
                            .frame(minHeight: 80)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.white.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .overlay(alignment: .topLeading) {
                                if recap.isEmpty {
                                    Text("Describe what you accomplished…")
                                        .foregroundStyle(.white.opacity(0.35))
                                        .padding(.top, 20)
                                        .padding(.leading, 16)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    // Break length picker
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Break Length", systemImage: "cup.and.saucer")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Picker("Break Length", selection: $selectedBreakMinutes) {
                            ForEach(breakOptions, id: \.minutes) { opt in
                                Text(opt.label).tag(opt.minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.white.opacity(0.15))
                        )
                        .accentColor(.white)
                    }

                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            recapFocused = false
                            vm.startBreak(recap: recap, breakMinutes: selectedBreakMinutes)
                        } label: {
                            Label("Start Break", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pomoMint)
                        .cornerRadius(14)
                        .disabled(recap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button {
                            vm.requestFiveMoreMinutes()
                        } label: {
                            Label("5 More Minutes", systemImage: "plus.circle")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 28)
            }
            .containerRelativeFrame(.horizontal) { width, _ in
                width * 0.88
            }
        }
        .onAppear { recapFocused = true }
    }
}

#Preview {
    BreakTransitionView()
        .environmentObject(TimerViewModel())
}
