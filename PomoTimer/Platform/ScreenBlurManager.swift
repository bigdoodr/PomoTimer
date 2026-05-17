#if os(macOS)
import AppKit

/// Covers all connected screens with a dark semi-transparent overlay,
/// approximating swiftDialog's `--blurscreen` flag.
///
/// Uses NSPanel (non-activating) at screen-saver level so the main
/// app window can remain interactive on top of the overlay.
/// This approach is App Store sandbox-compatible.
final class ScreenBlurManager {

    static let shared = ScreenBlurManager()
    private init() {}

    private var overlayPanels: [NSPanel] = []
    private var previousWindowLevel: NSWindow.Level?

    // MARK: - Public

    func showBlur() {
        guard overlayPanels.isEmpty else { return }   // already showing

        for screen in NSScreen.screens {
            let panel = makeOverlayPanel(for: screen)
            panel.orderFront(nil)
            overlayPanels.append(panel)
        }

        raiseAppWindow()
    }

    func hideBlur() {
        overlayPanels.forEach { $0.orderOut(nil) }
        overlayPanels.removeAll()
        restoreAppWindow()
    }

    // MARK: - App window management

    private func raiseAppWindow() {
        guard let window = NSApplication.shared.mainWindow
                ?? NSApplication.shared.keyWindow
                ?? NSApplication.shared.windows.first(where: { $0.isVisible && !($0 is NSPanel) })
        else { return }

        previousWindowLevel = window.level
        let overlayLevel = Int(CGWindowLevelForKey(.screenSaverWindow)) - 1
        window.level = NSWindow.Level(rawValue: overlayLevel + 1)

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func restoreAppWindow() {
        guard let level = previousWindowLevel else { return }
        for window in NSApplication.shared.windows where !(window is NSPanel) {
            if window.level.rawValue > NSWindow.Level.normal.rawValue {
                window.level = level
            }
        }
        previousWindowLevel = nil
    }

    // MARK: - Private

    private func makeOverlayPanel(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Sit just below screen-saver level so system overlays (Spotlight,
        // notifications) can still appear on top.
        panel.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1
        )

        // Dark semi-transparent backdrop matching swiftDialog's --blurscreen
        panel.backgroundColor = NSColor(white: 0.0, alpha: 0.70)
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true     // don't capture clicks; app window handles them
        panel.collectionBehavior = [
            .canJoinAllSpaces,              // visible on every Space
            .fullScreenAuxiliary            // compatible with full-screen apps
        ]

        return panel
    }
}
#endif
