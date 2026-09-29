import AppKit

/// The Settings window is an AppKit-owned `NSWindow` rather than a SwiftUI
/// `Window` scene: SwiftUI re-materializes scene windows whenever the app
/// activates or unhides, which flashed Settings on every routed link.
@MainActor
enum SettingsPresenter {
    private static var window: NSWindow?
    // Set by the app target; the UI types aren't compiled into the test target.
    static var makeContent: (() -> NSViewController)?

    static func present() {
        guard let window = self.window ?? makeWindow() else { return }
        NSApp.setActivationPolicy(.regular)
        self.window = window
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func settingsWindow() -> NSWindow? {
        window
    }

    private static func makeWindow() -> NSWindow? {
        guard let content = makeContent?() else { return nil }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = content
        window.setContentSize(NSSize(width: 920, height: 640))
        window.title = "LinkRouter"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.identifier = NSUserInterfaceItemIdentifier("settings")
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("LinkRouterSettings")
        if !window.setFrameUsingName("LinkRouterSettings") {
            window.center()
        }
        return window
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
