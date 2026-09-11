import AppKit

enum SettingsPresenter {
    static func present(openWindow: ((String) -> Void)? = nil) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openWindow?("settings")
        DispatchQueue.main.async { reveal() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { reveal() }
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
