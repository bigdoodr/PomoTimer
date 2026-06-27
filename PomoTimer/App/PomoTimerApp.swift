import SwiftUI

@main
struct PomoTimerApp: App {

    @StateObject private var vm = TimerViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 320, minHeight: 124)
                .environmentObject(vm)
                .environmentObject(vm.sessionStore)
                .environmentObject(vm.calendarService)
                .task {
                    await vm.sessionStore.load()
                    await vm.notificationService.requestAuthorization()
                    // Cold launch: clear any Live Activity left over from a
                    // session that finished while the app wasn't running.
                    vm.reconcileLiveActivityOnForeground()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Returning from the background (e.g. tapping the Live
                    // Activity): drop a stale activity if we're not mid-countdown.
                    if newPhase == .active {
                        vm.reconcileLiveActivityOnForeground()
                    }
                }
        }
#if os(macOS)
        // Compact default size; grows to full screen during blur phases automatically
        .defaultSize(width: 480, height: 540)
        .windowResizability(.contentMinSize)
#endif
    }
}
