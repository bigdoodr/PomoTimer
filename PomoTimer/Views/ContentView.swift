#if os(iOS)
import UIKit
#else
import AppKit
#endif
import SwiftUI

/// Root view — routes to the correct phase screen based on vm.phase.
struct ContentView: View {

    @EnvironmentObject var vm: TimerViewModel

    var body: some View {
        ZStack {
            Color.pomoBackground.ignoresSafeArea()

            switch vm.phase {
            case .setup:
                SetupView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .opacity
                    ))

            case .focus:
                FocusTimerView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .opacity
                    ))

            case .breakTransition:
                BreakTransitionView()
                    .transition(.opacity)

            case .takingBreak:
                BreakView()
                    .transition(.opacity)

            case .continuePrompt:
                ContinueView()
                    .transition(.scale(scale: 0.95).combined(with: .opacity))

            case .summary:
                SummaryView()
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.phase)
        .onReceive(
            NotificationCenter.default.publisher(for: .pomoAppForeground)
        ) { _ in
            // Timer drives itself via Date arithmetic — nothing needed here.
        }
    }
}

// MARK: - Cross-platform foreground notification

extension NSNotification.Name {
    /// Fires when the app returns to the foreground (iOS) or becomes active (macOS).
    static let pomoAppForeground: NSNotification.Name = {
        #if os(iOS)
        UIApplication.willEnterForegroundNotification
        #else
        NSApplication.willBecomeActiveNotification
        #endif
    }()
}

// MARK: - Color palette
// All names are prefixed with "pomo" to guarantee no collision with current
// or future SwiftUI built-in Color static members (e.g. Color.background,
// Color.mint, Color.indigo are all system-defined in iOS 15+/macOS 12+).

extension Color {
    static let pomoBackground = Color("Background",  bundle: nil)
    static let pomoRed        = Color("PomodoroRed", bundle: nil)
    static let pomoIndigo     = Color("FocusIndigo", bundle: nil)
    static let pomoMint       = Color("BreakMint",   bundle: nil)
    static let pomoSurface    = Color("CardSurface", bundle: nil)
}
