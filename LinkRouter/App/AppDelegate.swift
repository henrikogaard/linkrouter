import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var lastForeignApp: NSRunningApplication?
    private var suppressReopenSettingsUntil = Date.distantPast
    private var reopenSettingsWork: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSClassFromString("XCTestCase") != nil { return }
        NSApp.setActivationPolicy(.accessory)
        AppState.shared.settings.appearance.apply()
        AppState.shared.refreshDefaultStatus()
        NSApp.servicesProvider = self
        if let loadIssue = AppState.shared.loadIssue {
            let alert = NSAlert()
            alert.messageText = loadIssue
            alert.informativeText = String(localized: "Starting with default settings. The original file was kept next to state.json in Application Support.")
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        if AppState.shared.isFirstLaunch {
            SettingsPresenter.present()
        }
        lastForeignApp = NSWorkspace.shared.frontmostApplication
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            MainActor.assumeIsolated {
                self?.lastForeignApp = app
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { note in
            let window = note.object as? NSWindow
            DispatchQueue.main.async {
                SettingsPresenter.noteWindowClosed(window)
                SettingsPresenter.resignToAccessoryIfNeeded()
                // Sync the close into the SwiftUI scene so it doesn't
                // re-materialize the window when the app unhides.
                SettingsPresenter.dismissSettingsScene?()
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
        // A URL delivery cancels any pending reopen-driven Settings show and
        // suppresses a following one: some launchers send rapp alongside GURL.
        suppressReopenSettingsUntil = Date().addingTimeInterval(1.5)
        reopenSettingsWork?.cancel()
        reopenSettingsWork = nil
        let source = sender()
        SettingsPresenter.suppressAutoReveal(for: 1.5)
        for url in urls {
            AppState.shared.handleIncoming(url, source: source)
        }
    }

    private func sender() -> (bundleID: String, name: String)? {
        let ownID = Bundle.main.bundleIdentifier
        func attributed(_ app: NSRunningApplication?) -> (bundleID: String, name: String)? {
            guard let app, app.bundleIdentifier != ownID else { return nil }
            return (app.bundleIdentifier ?? "", app.localizedName ?? "")
        }
        if let event = NSAppleEventManager.shared().currentAppleEvent {
            if let descriptor = event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr)) {
                Log.app.debug("Sender address descriptor type: \(self.fourCC(descriptor.descriptorType))")
                if let pid = descriptor.coerce(toDescriptorType: typeKernelProcessID),
                   let source = attributed(NSRunningApplication(processIdentifier: pid_t(pid.int32Value))) {
                    return source
                }
                if let bundleID = descriptor.coerce(toDescriptorType: typeApplicationBundleID)?.stringValue,
                   let source = attributed(NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first) {
                    return source
                }
                if descriptor.descriptorType == typeProcessSerialNumber,
                   let pid = descriptor.coerce(toDescriptorType: typeKernelProcessID),
                   let source = attributed(NSRunningApplication(processIdentifier: pid_t(pid.int32Value))) {
                    return source
                }
            } else {
                Log.app.debug("Apple Event has no address descriptor")
            }
        } else {
            Log.app.debug("No current Apple Event when handling open URLs")
        }
        if let source = attributed(NSWorkspace.shared.frontmostApplication) {
            return source
        }
        return attributed(lastForeignApp)
    }

    private func fourCC(_ code: OSType) -> String {
        let bytes = (0..<4).map { UInt8((code >> (24 - $0 * 8)) & 0xFF) }
        return String(bytes: bytes, encoding: .ascii) ?? String(format: "%08x", code)
    }

    @objc func routeLink(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        Log.app.info("Service invoked with types: \(pboard.types?.map(\.rawValue) ?? [])")
        guard let string = pboard.string(forType: .string),
              let url = ClipboardLink.firstURL(in: string) else { return }
        let front = NSWorkspace.shared.frontmostApplication
        let source: (bundleID: String, name: String)? = {
            guard let front, front.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
            return (front.bundleIdentifier ?? "", front.localizedName ?? "")
        }()
        DispatchQueue.main.async {
            SettingsPresenter.suppressAutoReveal(for: 1.5)
            AppState.shared.handleIncoming(url, source: source)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard Date() >= suppressReopenSettingsUntil else { return false }
        // Delay so a URL delivered with (or right after) this reopen — e.g.
        // `open -a LinkRouter url` — can cancel presenting Settings.
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, Date() >= self.suppressReopenSettingsUntil else { return }
                SettingsPresenter.present()
            }
        }
        reopenSettingsWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        // Returning false skips the default reopen handling, which re-orders
        // the app's windows — including the Settings window the user closed.
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
