import AppKit

protocol Dispatching {
    func open(
        url: URL,
        browser: BrowserRecord,
        row: CatalogRow,
        activates: Bool,
        forceNewInstance: Bool,
        completion: @escaping (Error?) -> Void
    ) -> DispatchOutcome
}

struct SystemDispatcher: Dispatching {
    func open(
        url: URL,
        browser: BrowserRecord,
        row: CatalogRow,
        activates: Bool,
        forceNewInstance: Bool,
        completion: @escaping (Error?) -> Void
    ) -> DispatchOutcome {
        Dispatcher.open(
            url: url,
            browser: browser,
            row: row,
            activates: activates,
            forceNewInstance: forceNewInstance,
            completion: completion
        )
    }
}

enum Dispatcher {
    static func isRunning(bundleIdentifier: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    static func open(
        url: URL,
        browser: BrowserRecord,
        row: CatalogRow,
        activates: Bool,
        forceNewInstance: Bool = false,
        completion: @escaping (Error?) -> Void = { _ in }
    ) -> DispatchOutcome {
        let running = isRunning(bundleIdentifier: browser.bundleIdentifier)
        let needsProfile = row.isProfileVariant
        let needsQuit: Bool
        switch row.kind {
        case .firefoxProfile:
            needsQuit = true
        case .firefoxPrivate:
            needsQuit = row.firefoxAbsPath != nil
        default:
            needsQuit = false
        }

        if needsProfile && running && needsQuit && !forceNewInstance {
            return .needsHostQuit(rowID: row.id, browserName: browser.displayName)
        }

        if needsProfile && running && (row.kind == .chromeProfile || row.kind == .chromePrivate),
           let arguments = argv(url: url, browser: browser, row: row, running: running) {
            do {
                try exec(browser: browser, arguments: arguments)
                if activates {
                    NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundleIdentifier).first?.activate()
                }
                completion(nil)
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
            return .opened
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates

        if needsProfile, let arguments = argv(url: url, browser: browser, row: row, running: running) {
            configuration.arguments = arguments
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: browser.bundleURL, configuration: configuration) { _, error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
            return .opened
        }

        NSWorkspace.shared.open([url], withApplicationAt: browser.bundleURL, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                completion(error)
            }
        }
        return .opened
    }

    static func executableURL(for browser: BrowserRecord) -> URL? {
        Bundle(url: browser.bundleURL)?.executableURL
    }

    static func exec(browser: BrowserRecord, arguments: [String]) throws {
        guard let executable = executableURL(for: browser) else {
            throw NSError(
                domain: "app.linkrouter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Can't find the \(browser.displayName) executable"]
            )
        }
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    static func argv(url: URL, browser: BrowserRecord, row: CatalogRow, running: Bool) -> [String]? {
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
            args.append(ProfileReader.family(for: browser.bundleIdentifier)?.privateFlag ?? "--incognito")
            args.append(url.absoluteString)
            return args
        case .firefoxProfile:
            guard let path = row.firefoxAbsPath else { return nil }
            var args: [String] = []
            if running {
                args.append("--new-instance")
            }
            args.append(contentsOf: ["--profile", path, url.absoluteString])
            return args
        case .firefoxPrivate:
            var args: [String] = []
            if let path = row.firefoxAbsPath {
                if running {
                    args.append("--new-instance")
                }
                args.append(contentsOf: ["--profile", path])
            }
            args.append(contentsOf: ["--private-window", url.absoluteString])
            return args
        }
    }
}
