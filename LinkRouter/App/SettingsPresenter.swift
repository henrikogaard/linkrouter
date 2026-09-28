import AppKit

enum SettingsPresenter {
    private static var suppressUntil = Date.distantPast
    private static var dismissedSettings = false
    private static var observersInstalled = false
    // Registered by the settings window's content; calls the SwiftUI
    // dismissWindow environment action so the scene marks itself closed.
    static var dismissSettingsScene: (() -> Void)?

    static func present(openWindow: ((String) -> Void)? = nil) {
        dismissedSettings = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openWindow?("settings")
        DispatchQueue.main.async { reveal() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { reveal() }
    }

    // SwiftUI re-inflates the closed Settings scene when the app activates
    // (e.g. `open -a`, which fires alongside URL delivery). While suppressed,
    // any Settings window that materializes is ordered back out. A window the
    // user never closed (or one we presented) is left alone.
    static func suppressAutoReveal(for seconds: TimeInterval) {
        installObserversIfNeeded()
        suppressUntil = Date().addingTimeInterval(seconds)
        if dismissedSettings, let window = settingsWindow(), window.isVisible {
            window.orderOut(nil)
        }
    }

    static func noteWindowClosed(_ window: NSWindow?) {
        if let window, settingsWindow() == window { dismissedSettings = true }
    }

    private static func installObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true
        NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: nil,
            queue: .main
        ) { _ in
            guard Date() < suppressUntil, dismissedSettings,
                  let window = settingsWindow(), window.isVisible else { return }
            window.orderOut(nil)
        }
    }

    static func reveal() {
        guard let window = settingsWindow() else { return }
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    static func settingsWindow() -> NSWindow? {
        let titled = NSApp.windows.filter { window in
            guard window.canBecomeKey else { return false }
            if window is NSPanel { return false }
            let className = String(describing: type(of: window))
            if className.localizedCaseInsensitiveContains("status") { return false }
            if window.frame.height < 80 { return false }
            return true
        }
        if let match = titled.first(where: { $0.identifier?.rawValue == "settings" }) {
            return match
        }
        let titles: Set<String> = ["LinkRouter", "Browsers", "Rules", "General"]
        return titled.first(where: { titles.contains($0.title) }) ?? titled.first
    }

    static func resignToAccessoryIfNeeded() {
        let visible = NSApp.windows.contains { window in
            window.isVisible && window.canBecomeKey && !(window is NSPanel) && window.frame.height >= 80
        }
        if !visible {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
