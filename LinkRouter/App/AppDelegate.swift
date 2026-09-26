import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSClassFromString("XCTestCase") != nil { return }
        NSApp.setActivationPolicy(.accessory)
        AppState.shared.settings.appearance.apply()
        AppState.shared.refreshDefaultStatus()
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                SettingsPresenter.resignToAccessoryIfNeeded()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppState.shared.refreshDefaultStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.flushSave()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let source = sender()
        for url in urls {
            AppState.shared.handleIncoming(url, source: source)
        }
    }

    private func sender() -> (bundleID: String, name: String)? {
        let ownID = Bundle.main.bundleIdentifier
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           let descriptor = event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr)),
           let pid = descriptor.coerce(toDescriptorType: typeKernelProcessID),
           let app = NSRunningApplication(processIdentifier: pid_t(pid.int32Value)),
           app.bundleIdentifier != ownID {
            return (app.bundleIdentifier ?? "", app.localizedName ?? "")
        }
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != ownID {
            return (front.bundleIdentifier ?? "", front.localizedName ?? "")
        }
        return nil
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsPresenter.present()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
