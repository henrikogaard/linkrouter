import AppKit

enum Dispatcher {
    static func isRunning(bundleIdentifier: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    static func open(
        url: URL,
        browser: BrowserRecord,
        row: CatalogRow,
        activates: Bool
    ) -> DispatchOutcome {
        let running = isRunning(bundleIdentifier: browser.bundleIdentifier)
        let needsProfile = row.isProfileVariant

        if needsProfile && running {
            return .needsHostQuit(rowID: row.id, browserName: browser.displayName)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates

        if needsProfile, let arguments = argv(url: url, browser: browser, row: row, running: running) {
            configuration.arguments = arguments
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: browser.bundleURL, configuration: configuration) { _, error in
                if let error {
                    NSLog("LinkRouter: launch failed: \(error.localizedDescription)")
                }
            }
            return .opened
        }

        NSWorkspace.shared.open([url], withApplicationAt: browser.bundleURL, configuration: configuration) { _, error in
            if let error {
                NSLog("LinkRouter: open failed: \(error.localizedDescription)")
            }
        }
        return .opened
    }

    static func argv(url: URL, browser: BrowserRecord, row: CatalogRow, running: Bool) -> [String]? {
        if running { return nil }
        switch row.kind {
        case .app:
            return nil
        case .chromeProfile:
            guard let directory = row.chromeDirectory else { return nil }
            return ["--profile-directory=\(directory)", url.absoluteString]
        case .chromePrivate:
            var args: [String] = []
            if let directory = row.chromeDirectory {
                args.append("--profile-directory=\(directory)")
            }
            args.append("--incognito")
            args.append(url.absoluteString)
            return args
        case .firefoxProfile:
            guard let path = row.firefoxAbsPath else { return nil }
            return ["--profile", path, url.absoluteString]
        case .firefoxPrivate:
            var args: [String] = []
            if let path = row.firefoxAbsPath {
                args.append(contentsOf: ["--profile", path])
            }
            args.append(contentsOf: ["--private-window", url.absoluteString])
            return args
        }
    }
}
