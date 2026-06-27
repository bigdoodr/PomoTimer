import SwiftUI
import Combine

// MARK: - Phase enum

/// The full session state machine, mirroring the zsh script's phase_* functions.
enum AppPhase: Equatable {
    case setup              // phase_setup: pick focus duration
    case focus              // phase_focus: countdown running
    case breakTransition    // phase_break_transition: recap + break picker
    case takingBreak        // phase_break: break countdown
    case continuePrompt     // phase_continue: start another or quit
    case summary            // show_summary: final stats screen
}

// MARK: - TimerViewModel

@MainActor
final class TimerViewModel: ObservableObject {

    // MARK: Published state (drives all views)
    @Published var phase: AppPhase = .setup
    @Published var focusMinutes: Int = 25
    @Published var breakMinutes: Int = 5
    @Published var secondsRemaining: Int = 0
    @Published var sessionCount: Int = 0
    @Published var totalFocusMinutesToday: Int = 0
    @Published var completedSessions: [PomodoroSession] = []

    // MARK: Internal session state
    private(set) var sessionStartDate: Date?
    private(set) var sessionEndDate: Date?
    /// True when the user requested "5 more minutes" — preserves SESSION_START
    private(set) var isContinuingSession: Bool = false

    // MARK: Services
    let sessionStore: SessionStore
    let notificationService = NotificationService()
    let calendarService: CalendarService

    // MARK: Timer internals
    private var timerCancellable: AnyCancellable?
    /// The Date at which the current timer should reach zero
    private var timerTarget: Date?

    // MARK: - Init

    init() {
        self.sessionStore = SessionStore()
        self.calendarService = CalendarService()
        // Give the notification service the dependencies it needs to finalize
        // a recap entered from a notification — possibly at cold launch.
        notificationService.configure(
            sessionStore: sessionStore,
            calendarService: calendarService
        )
        Task { await sessionStore.load() }
    }

    // MARK: - Setup phase

    /// Called when the user taps "Start Focusing" from SetupView.
    func beginFocusSession(focusMinutes: Int) {
        self.focusMinutes = focusMinutes
        sessionCount += 1

        if !isContinuingSession {
            sessionStartDate = Date()
        }

        scheduleTimer(seconds: focusMinutes * 60)
        notificationService.scheduleFocusComplete(
            in: TimeInterval(focusMinutes * 60),
            sessionNumber: sessionCount,
            startEpoch: (sessionStartDate ?? Date()).timeIntervalSince1970
        )
        LiveActivityManager.shared.start(
            isBreak: false,
            sessionNumber: sessionCount,
            start: Date(),
            end: Date().addingTimeInterval(TimeInterval(focusMinutes * 60))
        )
        phase = .focus
    }

    // MARK: - Focus phase

    /// User taps "End Session Early".
    func endFocusEarly() {
        cancelTimer()
        notificationService.cancelAll()
        LiveActivityManager.shared.end()
        sessionEndDate = Date()
        showBlur()
        phase = .breakTransition
    }

    /// Called internally when the focus countdown reaches zero.
    private func focusTimerExpired() {
        // Handled in-app — drop the actionable notification so the recap can't
        // also be logged from the notification (which would double-record it).
        notificationService.cancelAll()
        LiveActivityManager.shared.end()
        sessionEndDate = Date()
        showBlur()
        phase = .breakTransition
    }

    // MARK: - Break transition phase

    /// User taps "5 More Minutes" in BreakTransitionView.
    func requestFiveMoreMinutes() {
        // Preserve sessionStartDate; just tack on 5 more minutes to same session
        isContinuingSession = true
        sessionCount -= 1   // will be re-incremented in beginFocusSession
        hideBlur()
        beginFocusSession(focusMinutes: 5)
    }

    /// User fills in recap + picks break length, taps "Start Break".
    func startBreak(recap: String, breakMinutes: Int) {
        self.breakMinutes = breakMinutes

        // Persist the completed session
        if let start = sessionStartDate, let end = sessionEndDate {
            let duration = max(1, Int(end.timeIntervalSince(start) / 60))
            let session = buildSession(
                start: start,
                end: end,
                duration: duration,
                breakMinutes: breakMinutes,
                recap: recap
            )
            totalFocusMinutesToday += duration
            completedSessions.append(session)

            Task {
                await sessionStore.append(session)
                // Fire-and-forget calendar event creation
                _ = await calendarService.createEvent(for: session)
            }
        }

        isContinuingSession = false
        scheduleTimer(seconds: breakMinutes * 60)
        notificationService.scheduleBreakComplete(in: TimeInterval(breakMinutes * 60))
        // Transition the same Live Activity from focus → break in place.
        LiveActivityManager.shared.start(
            isBreak: true,
            sessionNumber: sessionCount,
            start: Date(),
            end: Date().addingTimeInterval(TimeInterval(breakMinutes * 60))
        )
        // Blur stays on during the break screen (already shown from transition)
        phase = .takingBreak
    }

    // MARK: - Break phase

    /// User taps "Skip Break".
    func skipBreak() {
        cancelTimer()
        notificationService.cancelAll()
        LiveActivityManager.shared.end()
        hideBlur()
        phase = .continuePrompt
    }

    /// Called internally when the break countdown reaches zero.
    private func breakTimerExpired() {
        notificationService.cancelAll()
        LiveActivityManager.shared.end()
        hideBlur()
        phase = .continuePrompt
    }

    // MARK: - Continue prompt

    func startNextSession() {
        phase = .setup
    }

    // MARK: - Live Activity reconciliation

    /// Called whenever the app becomes active. If no countdown is genuinely
    /// running, clear any Live Activity left over from a finished session —
    /// including an orphan that completed while the app was suspended (whose
    /// in-memory reference is gone after a cold launch).
    func reconcileLiveActivityOnForeground() {
        switch phase {
        case .focus, .takingBreak:
            break   // a countdown is live — keep its Live Activity
        default:
            LiveActivityManager.shared.endAll()
        }
    }

    func endDay() {
        LiveActivityManager.shared.end()
        phase = .summary
    }

    // MARK: - Summary / reset

    func resetForNewDay() {
        cancelTimer()
        LiveActivityManager.shared.end()
        sessionCount = 0
        totalFocusMinutesToday = 0
        sessionStartDate = nil
        sessionEndDate = nil
        isContinuingSession = false
        completedSessions = []
        phase = .setup
    }

    // MARK: - Computed helpers

    /// Minutes elapsed in the current session (start → end).
    var elapsedFocusMinutes: Int {
        guard let s = sessionStartDate, let e = sessionEndDate else { return 0 }
        return max(1, Int(e.timeIntervalSince(s) / 60))
    }

    /// Formatted countdown string, e.g. "24:07".
    var timerDisplay: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    /// Progress 0.0 → 1.0 for the current timer phase.
    var timerProgress: Double {
        let totalSeconds: Int
        if phase == .focus {
            totalSeconds = focusMinutes * 60
        } else {
            totalSeconds = breakMinutes * 60
        }
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(secondsRemaining) / Double(totalSeconds)
    }

    // MARK: - Private helpers

    private func scheduleTimer(seconds: Int) {
        cancelTimer()
        secondsRemaining = seconds
        timerTarget = Date().addingTimeInterval(TimeInterval(seconds))
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let target = self.timerTarget else { return }
                let remaining = max(0, Int(target.timeIntervalSinceNow.rounded()))
                self.secondsRemaining = remaining
                if remaining == 0 {
                    self.cancelTimer()
                    switch self.phase {
                    case .focus:       self.focusTimerExpired()
                    case .takingBreak: self.breakTimerExpired()
                    default: break
                    }
                }
            }
    }

    private func cancelTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        timerTarget = nil
    }

    private func buildSession(
        start: Date, end: Date,
        duration: Int, breakMinutes: Int, recap: String
    ) -> PomodoroSession {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        return PomodoroSession(
            sessionNumber: sessionCount,
            date: dateFmt.string(from: start),
            startTime: timeFmt.string(from: start),
            endTime: timeFmt.string(from: end),
            durationMinutes: duration,
            breakDurationMinutes: breakMinutes,
            recap: recap,
            calendarEventIdentifier: nil,
            startEpoch: start.timeIntervalSince1970,
            endEpoch: end.timeIntervalSince1970
        )
    }

    // MARK: - Platform blur (macOS only)

    private func showBlur() {
        #if os(macOS)
        ScreenBlurManager.shared.showBlur()
        // Grow the (possibly mini-player–sized) window back to a comfortable,
        // centered size so the recap editor is fully usable.
        MacWindowManager.shared.growForRecap()
        #endif
    }

    private func hideBlur() {
        #if os(macOS)
        ScreenBlurManager.shared.hideBlur()
        #endif
    }
}
