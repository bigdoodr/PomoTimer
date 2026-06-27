#if os(macOS)
import AppKit

/// Centralizes sizing and on-top behavior of the main app window on macOS.
///
/// The app uses a single window that changes shape per phase:
///   • `.focus`  — compact, floating, on top of other apps
///   • mini      — a tiny always-on-top "mini player" (à la Apple Music)
///   • recap     — grows back to a comfortable, centered size so the recap
///                 editor in BreakTransitionView is fully usable
///
/// Window level while the blur overlay is showing is handled by
/// `ScreenBlurManager`; this type only owns size and the floating level used
/// during the focus countdown.
@MainActor
final class MacWindowManager {

    static let shared = MacWindowManager()
    private init() {}

    // MARK: - Sizes

    /// Compact-but-readable size used during a normal focus countdown.
    private let focusSize = NSSize(width: 360, height: 520)
    /// Tiny mini-player size. Must stay >= the window's content min size
    /// (see PomoTimerApp's `.frame(minWidth:minHeight:)`).
    private let miniSize = NSSize(width: 320, height: 124)
    /// Roomy, centered size for the recap / break-transition screen.
    private let recapSize = NSSize(width: 480, height: 600)

    // MARK: - Public

    /// Enter the standard floating focus window.
    func enterFocus() {
        guard let window = mainWindow else { return }
        window.level = .floating
        resize(window, to: focusSize)
    }

    /// Shrink to the always-on-top mini player.
    func enterMiniPlayer() {
        guard let window = mainWindow else { return }
        window.level = .floating
        resize(window, to: miniSize)
    }

    /// Grow back to a comfortable, screen-centered size so the recap editor
    /// is fully visible — even if the user had dragged the window mostly
    /// off-screen while it was compact.
    func growForRecap() {
        guard let window = mainWindow else { return }
        var frame = window.frame
        frame.size = recapSize
        if let visible = (window.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = visible.midX - recapSize.width / 2
            frame.origin.y = visible.midY - recapSize.height / 2
        }
        window.setFrame(frame, display: true, animate: true)
    }

    // MARK: - Private

    /// The main content window (excludes the blur `NSPanel` overlays).
    private var mainWindow: NSWindow? {
        NSApplication.shared.windows.first { $0.isVisible && !($0 is NSPanel) }
    }

    /// Resize while keeping the window's top-left corner anchored, so the
    /// title bar stays put as the window grows or shrinks.
    private func resize(_ window: NSWindow, to size: NSSize) {
        var frame = window.frame
        let topEdge = frame.origin.y + frame.height
        frame.size = size
        frame.origin.y = topEdge - size.height
        window.setFrame(frame, display: true, animate: true)
    }
}
#endif
