#if os(macOS)
import AppKit

/// Preferred screen corner for the floating focus / mini-player window.
enum WindowCorner: String, CaseIterable, Identifiable {
    case none        = "none"
    case topLeft     = "topLeft"
    case topRight    = "topRight"
    case bottomLeft  = "bottomLeft"
    case bottomRight = "bottomRight"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:        return "No preference"
        case .topLeft:     return "Top Left"
        case .topRight:    return "Top Right"
        case .bottomLeft:  return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
}

/// Centralizes sizing and on-top behavior of the main app window on macOS.
///
/// The app uses a single window that changes shape per phase:
///   • `.focus`  — compact, floating, on top of other apps
///   • mini      — a tiny always-on-top "mini player" (à la Apple Music)
///   • recap     — grows back to a comfortable, centered size so the recap
///                 editor in BreakTransitionView is fully usable
///
/// When the user has set a preferred corner in Settings, `enterFocus()` and
/// `enterMiniPlayer()` snap the window to that corner. The user can then drag
/// freely; the snap only fires on mode transitions, not continuously.
///
/// Window level while the blur overlay is showing is handled by
/// `ScreenBlurManager`; this type only owns size and the floating level used
/// during the focus countdown.
@MainActor
final class MacWindowManager {

    static let shared = MacWindowManager()
    private init() {}

    static let cornerPreferenceKey = "windowCornerPreference"

    // MARK: - Sizes

    /// Compact-but-readable size used during a normal focus countdown.
    private let focusSize = NSSize(width: 360, height: 520)
    /// Tiny mini-player size. Must stay >= the window's content min size
    /// (see PomoTimerApp's `.frame(minWidth:minHeight:)`).
    private let miniSize = NSSize(width: 320, height: 124)
    /// Roomy, centered size for the recap / break-transition screen.
    private let recapSize = NSSize(width: 480, height: 600)

    private let cornerMargin: CGFloat = 16

    // MARK: - Public

    /// Enter the standard floating focus window, snapping to the preferred
    /// corner when one is set in Settings.
    func enterFocus() {
        guard let window = mainWindow else { return }
        window.level = .floating
        resizeAndPosition(window, to: focusSize)
    }

    /// Shrink to the always-on-top mini player, snapping to the preferred
    /// corner when one is set in Settings.
    func enterMiniPlayer() {
        guard let window = mainWindow else { return }
        window.level = .floating
        resizeAndPosition(window, to: miniSize)
    }

    /// Grow back to a comfortable, screen-centered size so the recap editor
    /// is fully visible — even if the user had dragged the window mostly
    /// off-screen or minimized it to the dock while the timer was running.
    func growForRecap() {
        guard let window = mainWindow else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
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
    /// Includes miniaturized windows so the window can be found and restored
    /// when the focus timer expires while the window is docked.
    private var mainWindow: NSWindow? {
        NSApplication.shared.windows.first {
            !($0 is NSPanel) && ($0.isVisible || $0.isMiniaturized)
        }
    }

    /// The corner preference stored in UserDefaults by SettingsView.
    private var preferredCorner: WindowCorner {
        let raw = UserDefaults.standard.string(forKey: Self.cornerPreferenceKey) ?? ""
        return WindowCorner(rawValue: raw) ?? .none
    }

    /// Resize and optionally snap to the user's preferred corner.
    /// Falls back to anchoring on the top-left corner (existing behavior) when
    /// no corner preference is set.
    private func resizeAndPosition(_ window: NSWindow, to size: NSSize) {
        let corner = preferredCorner
        var frame = window.frame
        frame.size = size

        if corner != .none,
           let visible = (window.screen ?? NSScreen.main)?.visibleFrame {
            switch corner {
            case .topLeft:
                frame.origin.x = visible.minX + cornerMargin
                frame.origin.y = visible.maxY - size.height - cornerMargin
            case .topRight:
                frame.origin.x = visible.maxX - size.width - cornerMargin
                frame.origin.y = visible.maxY - size.height - cornerMargin
            case .bottomLeft:
                frame.origin.x = visible.minX + cornerMargin
                frame.origin.y = visible.minY + cornerMargin
            case .bottomRight:
                frame.origin.x = visible.maxX - size.width - cornerMargin
                frame.origin.y = visible.minY + cornerMargin
            case .none:
                break
            }
        } else {
            // No corner pref: anchor the top-left so the title bar stays put.
            let topEdge = window.frame.origin.y + window.frame.height
            frame.origin.y = topEdge - size.height
        }

        window.setFrame(frame, display: true, animate: true)
    }
}
#endif
