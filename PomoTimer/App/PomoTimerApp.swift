import SwiftUI

@main
struct PomoTimerApp: App {

    @StateObject private var vm = TimerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 480, minHeight: 540)
                .environmentObject(vm)
                .environmentObject(vm.sessionStore)
                .environmentObject(vm.calendarService)
                .task {
                    await vm.sessionStore.load()
                    await vm.notificationService.requestAuthorization()
                }
        }
#if os(macOS)
        // Compact default size; grows to full screen during blur phases automatically
        .defaultSize(width: 480, height: 540)
        .windowResizability(.contentMinSize)
#endif
    }
}
