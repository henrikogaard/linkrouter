import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var browsers: [BrowserRecord]
    @Published var rows: [CatalogRow]
    @Published var rules: [Rule]
    @Published var profiles: [RouteProfile]
    @Published var settings: AppSettings
    @Published var isDefaultBrowser: Bool
    @Published var runningIDs: Set<String>
    @Published var pendingQuit: (url: URL, row: CatalogRow, browser: BrowserRecord)?
    @Published var recent: [RoutedEntry]
    @Published var profileSnapshot: [String: [ChromeProfile]] = [:]
    private var profileWatcher: ProfileWatcher?

    let prompt = PromptController()
    let launchStart = Date()
    private var firstPromptLogged = false
    var dispatcher: Dispatching
    var onPromptShown: (() -> Void)?
    var skipsPersistence = false
    @Published var clipboardURL: URL?
    var loadIssue: String?
    private(set) var isFirstLaunch = false
    private var pasteboardChangeCount = -1
    private var promptQueue: [(link: IncomingLink, rows: [CatalogRow])] = []
    private var runningObservation: NSKeyValueObservation?
    private var saveWork: DispatchWorkItem?

    init(dispatcher: Dispatching = SystemDispatcher()) {
        self.dispatcher = dispatcher
        let initialBrowsers: [BrowserRecord]
        let initialRows: [CatalogRow]
        let initialRules: [Rule]
        let initialProfiles: [RouteProfile]
        let initialSettings: AppSettings
        var initialRecent: [RoutedEntry] = []
        var corrupted = false
        switch Persistence.load() {
        case .loaded(let persisted):
            initialBrowsers = persisted.browsers
            initialRows = persisted.rows
            initialRules = persisted.rules
            initialProfiles = persisted.profiles
            initialSettings = persisted.settings
            initialRecent = persisted.recent
        case .missing:
            isFirstLaunch = true
            let seed = BrowserCatalog.seedFromLaunchServices()
            initialBrowsers = seed.browsers
            initialRows = seed.rows
            initialRules = Rule.shipped()
            initialProfiles = RouteProfile.shipped()
            initialSettings = AppSettings()
        case .corrupt:
            corrupted = true
            let seed = BrowserCatalog.seedFromLaunchServices()
            initialBrowsers = seed.browsers
            initialRows = seed.rows
            initialRules = Rule.shipped()
            initialProfiles = RouteProfile.shipped()
            initialSettings = AppSettings()
        case .newer:
            corrupted = true
            loadIssue = "This settings file was written by a newer LinkRouter"
            let seed = BrowserCatalog.seedFromLaunchServices()
            initialBrowsers = seed.browsers
            initialRows = seed.rows
            initialRules = Rule.shipped()
            initialProfiles = RouteProfile.shipped()
            initialSettings = AppSettings()
        }
        browsers = initialBrowsers
        rows = initialRows
        rules = initialRules
        profiles = initialProfiles
        settings = initialSettings
        recent = initialRecent
        pendingQuit = nil
        isDefaultBrowser = DefaultBrowser.isLinkRouterDefault()
        runningIDs = BrowserCatalog.runningIdentifiers(in: initialBrowsers)
        observeRunning()
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.refreshProfileSnapshot()
            self.profileWatcher = ProfileWatcher { [weak self] in
                self?.refreshProfileSnapshot()
            }
            self.startProfileWatch()
        }
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isDefaultBrowser else { return }
                self.refreshDefaultStatus()
            }
        }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshClipboard()
            }
        }
        if corrupted {
            Persistence.save(
                PersistedState(
                    browsers: browsers,
                    rows: rows,
                    rules: rules,
                    profiles: profiles,
                    settings: settings,
                    recent: recent
                )
            )
        }
    }

    var enabledRows: [CatalogRow] { rows.filter(\.enabled) }

    var availableRows: [CatalogRow] { enabledRows.filter { isAvailable($0) } }

    var favourite: CatalogRow? { availableRows.first }

    var runningCount: Int {
        let ids = Set(availableRows.compactMap { browser(for: $0)?.bundleIdentifier })
        return ids.filter { runningIDs.contains($0) }.count
    }

    func browser(for row: CatalogRow) -> BrowserRecord? {
        browsers.first { $0.id == row.browserID }
    }

    func resolvedBrowser(for row: CatalogRow) -> BrowserRecord? {
        guard let record = browser(for: row) else { return nil }
        if FileManager.default.fileExists(atPath: record.path) { return record }
        guard let index = browsers.firstIndex(where: { $0.id == record.id }),
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: record.bundleIdentifier)
        else { return nil }
        var updated = record
        updated.path = url.path
        if let meta = BrowserCatalog.metadata(for: url) {
            updated.displayName = meta.displayName
        }
        browsers[index] = updated
        BrowserCatalog.invalidateIcons(for: record.path, url.path)
        save()
        return updated
    }

    func isAvailable(_ row: CatalogRow) -> Bool {
        guard profileExists(row), let record = browser(for: row) else { return false }
        if FileManager.default.fileExists(atPath: record.path) { return true }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: record.bundleIdentifier) != nil
    }

    func profileExists(_ row: CatalogRow) -> Bool {
        switch row.kind {
        case .app:
            return true
        case .chromeProfile, .chromePrivate:
            guard let directory = row.chromeDirectory else { return true }
            guard let record = browser(for: row),
                  let family = ProfileReader.family(for: record.bundleIdentifier)
            else { return false }
            if profileSnapshot[record.bundleIdentifier]?.contains(where: { $0.directory == directory }) == true {
                return true
            }
            return FileManager.default.fileExists(
                atPath: ProfileReader.userDataURL(for: family).appendingPathComponent(directory).path
            )
        case .firefoxProfile, .firefoxPrivate:
            guard let path = row.firefoxAbsPath else { return true }
            return FileManager.default.fileExists(atPath: path)
        }
    }

    func refreshProfileSnapshot() {
        var snapshot: [String: [ChromeProfile]] = [:]
        for host in chromiumHosts() {
            if let family = ProfileReader.family(for: host.bundleIdentifier) {
                snapshot[host.bundleIdentifier] = ProfileReader.chromeProfiles(family: family)
            }
        }
        profileSnapshot = snapshot
    }

    private func startProfileWatch() {
        var directories = ProfileReader.chromiumFamilies.map { ProfileReader.userDataURL(for: $0) }
        directories.append(
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Firefox")
        )
        profileWatcher?.start(directories: directories)
    }

    func title(for row: CatalogRow) -> String {
        let base = browser(for: row)?.displayName ?? "Browser"
        switch row.kind {
        case .app:
            return base
        case .chromeProfile:
            return row.chromeName.map { "\(base) · \($0)" } ?? base
        case .firefoxProfile:
            return row.firefoxName.map { "\(base) · \($0)" } ?? base
        case .chromePrivate:
            if let name = row.chromeName { return "\(base) · \(name) · Private" }
            return "\(base) · Private"
        case .firefoxPrivate:
            if let name = row.firefoxName { return "\(base) · \(name) · Private" }
            return "\(base) · Private"
        }
    }

    func subtitle(for row: CatalogRow) -> String? {
        switch row.kind {
        case .app: return nil
        case .chromeProfile: return row.chromeDirectory
        case .firefoxProfile: return row.firefoxAbsPath
        case .chromePrivate:
            let family = browser(for: row).flatMap { ProfileReader.family(for: $0.bundleIdentifier) }
            return family?.privateWord ?? "Incognito"
        case .firefoxPrivate: return "Private window"
        }
    }

    func isRunning(_ row: CatalogRow) -> Bool {
        guard let id = browser(for: row)?.bundleIdentifier else { return false }
        return runningIDs.contains(id)
    }

    @Published var pausedUntil: Date?
    private var resumeTask: Task<Void, Never>?

    var isPaused: Bool {
        guard let pausedUntil else { return false }
        return pausedUntil == .distantFuture || pausedUntil > Date()
    }

    func pause(for duration: TimeInterval?) {
        resumeTask?.cancel()
        if let duration {
            pausedUntil = Date().addingTimeInterval(duration)
            resumeTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.resume() }
            }
        } else {
            pausedUntil = .distantFuture
        }
    }

    func resume() {
        resumeTask?.cancel()
        resumeTask = nil
        pausedUntil = nil
    }

    func handleIncoming(_ url: URL, source: (bundleID: String, name: String)? = nil) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }
        pendingQuit = nil
        let cleaned = URLCleaner.clean(
            url,
            unwrap: settings.unwrapRedirects,
            strip: settings.stripTrackingParams
        )
        if cleaned != url {
            Log.routing.info("Cleaned \(url.absoluteString) -> \(cleaned.absoluteString)")
        }
        let link = IncomingLink(url: cleaned, sourceBundleID: source?.bundleID, sourceName: source?.name)
        if isPaused, let row = favourite ?? bestRunning() {
            dispatch(link, row: row)
            return
        }
        let flags = NSEvent.modifierFlags
        let force = settings.forcePromptOnModifier && !flags.intersection([.shift, .control, .option, .command]).isEmpty
        let result = RuleEngine.evaluate(
            link: link,
            profiles: profiles,
            rules: rules,
            runningCount: runningCount,
            modifierForcePrompt: force
        )
        apply(result, link: link)
    }

    func apply(_ result: EngineResult, link: IncomingLink) {
        switch result {
        case .favourite:
            if let row = favourite { dispatch(link, row: row) }
            else { showPrompt(link: link, rows: availableRows) }
        case .bestRunning:
            if let row = bestRunning() { dispatch(link, row: row) }
            else if let row = favourite { dispatch(link, row: row) }
            else { showPrompt(link: link, rows: availableRows) }
        case .open(let ids):
            let targets = ids.compactMap { id in rows.first { $0.id == id } }.filter { isAvailable($0) }
            if targets.isEmpty {
                showPrompt(link: link, rows: availableRows)
            } else {
                for row in targets { dispatch(link, row: row) }
            }
        case .promptAll:
            showPrompt(link: link, rows: availableRows)
        case .promptRunning:
            let running = availableRows.filter { isRunning($0) }
            showPrompt(link: link, rows: running.isEmpty ? availableRows : running)
        case .prompt(let ids):
            let subset = ids.compactMap { id in rows.first { $0.id == id } }.filter { isAvailable($0) }
            showPrompt(link: link, rows: subset.isEmpty ? availableRows : subset)
        }
    }

    func bestRunning() -> CatalogRow? {
        availableRows.first { isRunning($0) }
    }

    func showPrompt(link: IncomingLink, rows: [CatalogRow]) {
        if prompt.isVisible {
            if !promptQueue.contains(where: { $0.link.url == link.url }) {
                promptQueue.append((link, rows))
            }
            return
        }
        if let onPromptShown {
            onPromptShown()
            return
        }
        let items = rows.map { row in
            PromptItem(
                id: row.id,
                title: title(for: row),
                running: isRunning(row),
                icon: BrowserCatalog.icon(for: browser(for: row)?.path ?? "")
            )
        }
        prompt.show(
            items: items,
            link: link,
            timeout: settings.promptTimeout,
            onPick: { [weak self] picked, keepOpen in
                guard let self else { return }
                if let picked, let row = self.rows.first(where: { $0.id == picked }) {
                    self.dispatch(link, row: row, isRetry: true)
                }
                if !keepOpen {
                    self.showNextQueuedPrompt()
                }
            },
            onAlways: { [weak self] rowID in
                guard let self else { return }
                self.alwaysOpen(host: link.host, in: rowID)
                if let row = self.rows.first(where: { $0.id == rowID }) {
                    self.dispatch(link, row: row, isRetry: true)
                }
                self.showNextQueuedPrompt()
            },
            onTimeout: { [weak self] in
                guard let self else { return }
                if let row = self.favourite {
                    self.dispatch(link, row: row, isRetry: true)
                }
                self.showNextQueuedPrompt()
            }
        )
        if !firstPromptLogged {
            firstPromptLogged = true
            Log.app.info("Launch to first prompt: \(String(format: "%.2f", Date().timeIntervalSince(self.launchStart)))s")
        }
    }

    func refreshClipboard() {
        let count = NSPasteboard.general.changeCount
        guard count != pasteboardChangeCount else { return }
        pasteboardChangeCount = count
        clipboardURL = ClipboardLink.firstURL(in: NSPasteboard.general.string(forType: .string))
    }

    private func showNextQueuedPrompt() {
        while !promptQueue.isEmpty {
            let next = promptQueue.removeFirst()
            guard !next.rows.isEmpty else { continue }
            showPrompt(link: next.link, rows: next.rows)
            return
        }
    }

    func dispatch(_ link: IncomingLink, row: CatalogRow, isRetry: Bool = false) {
        guard let browser = resolvedBrowser(for: row) else {
            Log.routing.error("No browser available for \(self.title(for: row))")
            let candidates = availableRows
            if candidates.isEmpty {
                presentNoBrowserAlert()
            } else {
                showPrompt(link: link, rows: candidates)
            }
            return
        }
        let outcome = dispatcher.open(
            url: link.url,
            browser: browser,
            row: row,
            activates: !settings.openInBackground,
            forceNewInstance: false
        ) { [weak self] error in
            guard let self, let error else { return }
            self.handleOpenError(error, link: link, browser: browser, isRetry: isRetry)
        }
        switch outcome {
        case .opened:
            pendingQuit = nil
            let entry = RoutedEntry(id: UUID(), url: link.url, rowID: row.id, title: title(for: row), date: .now)
            recent.removeAll { $0.url == entry.url && $0.rowID == entry.rowID }
            recent.insert(entry, at: 0)
            if recent.count > 200 {
                recent.removeLast(recent.count - 200)
            }
            save()
        case .needsHostQuit(_, let name):
            pendingQuit = (link.url, row, browser)
            prompt.dismiss()
            presentQuitAlert(browserName: name, url: link.url, row: row, browser: browser)
        case .failed(let message):
            Log.routing.error("Dispatch failed: \(message)")
        }
    }

    func reopen(_ entry: RoutedEntry) {
        let link = IncomingLink(url: entry.url)
        if let row = rows.first(where: { $0.id == entry.rowID }) {
            dispatch(link, row: row, isRetry: true)
        } else {
            showPrompt(link: link, rows: availableRows)
        }
    }

    func clearRecent() {
        recent.removeAll()
        save()
    }

    private func handleOpenError(_ error: Error, link: IncomingLink, browser: BrowserRecord, isRetry: Bool) {
        Log.routing.error("Failed to open \(browser.displayName): \(error.localizedDescription)")
        if isRetry {
            presentOpenFailedAlert(browserName: browser.displayName, error: error)
        } else {
            showPrompt(link: link, rows: availableRows)
        }
    }

    private func presentNoBrowserAlert() {
        let alert = NSAlert()
        alert.messageText = "No browser available"
        alert.informativeText = "Add a browser in LinkRouter → Browsers."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }

    private func presentOpenFailedAlert(browserName: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn't open \(browserName)"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func openWithoutProfile() {
        guard let pending = pendingQuit else { return }
        var plain = pending.row
        plain.kind = .app
        plain.chromeDirectory = nil
        plain.firefoxAbsPath = nil
        _ = dispatcher.open(
            url: pending.url,
            browser: pending.browser,
            row: plain,
            activates: !settings.openInBackground,
            forceNewInstance: false
        ) { error in
            if let error {
                Log.routing.error("Failed to open \(pending.browser.displayName): \(error.localizedDescription)")
            }
        }
        pendingQuit = nil
    }

    func presentQuitAlert(browserName: String, url: URL, row: CatalogRow, browser: BrowserRecord) {
        let alert = NSAlert()
        alert.messageText = "\(browserName) is already running"
        alert.informativeText = "\(browserName) applies a profile only when it starts cold. Open a separate \(browserName) instance for this profile, or open the link in the running \(browserName) without a profile."
        alert.addButton(withTitle: "Open in new instance")
        alert.addButton(withTitle: "Open without profile")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openInNewInstance()
        } else if response == .alertSecondButtonReturn {
            openWithoutProfile()
        } else {
            pendingQuit = nil
        }
    }

    func openInNewInstance() {
        guard let pending = pendingQuit else { return }
        _ = dispatcher.open(
            url: pending.url,
            browser: pending.browser,
            row: pending.row,
            activates: !settings.openInBackground,
            forceNewInstance: true
        ) { error in
            if let error {
                Log.routing.error("Failed to open \(pending.browser.displayName): \(error.localizedDescription)")
            }
        }
        pendingQuit = nil
    }

    func refreshDefaultStatus() {
        isDefaultBrowser = DefaultBrowser.isLinkRouterDefault()
    }

    private var defaultPollTask: Task<Void, Never>?

    func requestDefault() {
        DefaultBrowser.requestDefault()
        defaultPollTask?.cancel()
        defaultPollTask = Task { [weak self] in
            for _ in 0..<60 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.refreshDefaultStatus()
                }
                if self?.isDefaultBrowser == true {
                    return
                }
            }
        }
    }

    func refreshDiscovered() {
        for row in rows {
            _ = resolvedBrowser(for: row)
        }
        refreshProfileSnapshot()
        startProfileWatch()
        BrowserCatalog.appendDiscovered(browsers: &browsers, rows: &rows)
        let selfPaths = [Bundle.main.bundleURL.standardizedFileURL.path, "LinkRouter.app"]
        let removed = browsers.filter { record in
            record.path.hasSuffix("/LinkRouter.app") || selfPaths.contains(record.path)
        }
        if !removed.isEmpty {
            let ids = Set(removed.map(\.id))
            browsers.removeAll { ids.contains($0.id) }
            rows.removeAll { ids.contains($0.browserID) }
        }
        runningIDs = BrowserCatalog.runningIdentifiers(in: browsers)
        save()
    }

    func addApp(url: URL) {
        if BrowserCatalog.addApp(at: url, browsers: &browsers, rows: &rows) {
            save()
        }
    }

    func removeRow(_ row: CatalogRow) {
        rows.removeAll { $0.id == row.id }
        for index in rules.indices {
            rules[index].behaviour.rowIDs.removeAll { $0 == row.id }
        }
        for index in profiles.indices where profiles[index].browserRowID == row.id {
            profiles[index].browserRowID = nil
        }
        let stillUsed = rows.contains { $0.browserID == row.browserID }
        if !stillUsed {
            browsers.removeAll { $0.id == row.browserID }
        }
        save()
    }

    func moveRows(from offsets: IndexSet, to destination: Int) {
        rows.move(fromOffsets: offsets, toOffset: destination)
        save()
    }

    func moveRow(id: UUID, to target: UUID) {
        guard let from = rows.firstIndex(where: { $0.id == id }),
              let to = rows.firstIndex(where: { $0.id == target }),
              from != to else { return }
        rows.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        save()
    }

    func addChromeProfile(_ profile: ChromeProfile, browserID: UUID, isPrivate: Bool) {
        let kind: RowKind = isPrivate ? .chromePrivate : .chromeProfile
        guard !rows.contains(where: {
            $0.browserID == browserID && $0.kind == kind && $0.chromeDirectory == profile.directory
        }) else { return }
        rows.append(
            CatalogRow(
                id: UUID(),
                browserID: browserID,
                kind: kind,
                chromeDirectory: profile.directory,
                chromeName: profile.name
            )
        )
        save()
    }

    func addChromePrivate(browserID: UUID) {
        guard !rows.contains(where: { $0.browserID == browserID && $0.kind == .chromePrivate && $0.chromeDirectory == nil }) else { return }
        rows.append(CatalogRow(id: UUID(), browserID: browserID, kind: .chromePrivate))
        save()
    }

    func addFirefoxProfile(_ profile: FirefoxProfile, browserID: UUID, isPrivate: Bool) {
        let kind: RowKind = isPrivate ? .firefoxPrivate : .firefoxProfile
        guard !rows.contains(where: {
            $0.browserID == browserID && $0.kind == kind && $0.firefoxAbsPath == profile.absPath
        }) else { return }
        rows.append(
            CatalogRow(
                id: UUID(),
                browserID: browserID,
                kind: kind,
                firefoxName: profile.name,
                firefoxAbsPath: profile.absPath
            )
        )
        save()
    }

    func addFirefoxPrivate(browserID: UUID) {
        guard !rows.contains(where: { $0.browserID == browserID && $0.kind == .firefoxPrivate && $0.firefoxAbsPath == nil }) else { return }
        rows.append(CatalogRow(id: UUID(), browserID: browserID, kind: .firefoxPrivate))
        save()
    }

    func chromiumHosts() -> [BrowserRecord] {
        browsers.filter { ProfileReader.family(for: $0.bundleIdentifier) != nil }
    }

    func firefoxHost() -> BrowserRecord? {
        browsers.first { ProfileReader.isFirefoxApp($0.bundleURL) }
    }

    func addProfile() {
        profiles.append(.blank())
        save()
    }

    func updateProfile(_ profile: RouteProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        save()
    }

    func removeProfile(_ profile: RouteProfile) {
        profiles.removeAll { $0.id == profile.id }
        save()
    }

    func moveProfiles(from offsets: IndexSet, to destination: Int) {
        profiles.move(fromOffsets: offsets, toOffset: destination)
        save()
    }

    func addRule() {
        let insertAt = rules.lastIndex(where: \.isFallback) ?? rules.count
        let rule = Rule(
            id: UUID(),
            title: "New rule",
            enabled: true,
            combinator: .all,
            conditions: [.url()],
            behaviour: .promptAll,
            isFallback: false
        )
        rules.insert(rule, at: insertAt)
        save()
    }

    func updateRule(_ rule: Rule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        var next = rule
        if rules[index].isFallback {
            next.isFallback = true
        }
        rules[index] = next
        save()
    }

    func removeRule(_ rule: Rule) {
        guard !rule.isFallback else { return }
        rules.removeAll { $0.id == rule.id }
        save()
    }

    func moveRules(from offsets: IndexSet, to destination: Int) {
        var working = rules
        let fallback = working.last(where: \.isFallback)
        working.removeAll(where: \.isFallback)
        working.move(fromOffsets: offsets, toOffset: min(destination, working.count))
        if let fallback { working.append(fallback) }
        rules = working
        save()
    }

    func duplicateRule(_ rule: Rule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        var copy = rule
        copy.id = UUID()
        copy.title = rule.title + " copy"
        copy.isFallback = false
        copy.conditions = rule.conditions.map { condition in
            var next = condition
            next.id = UUID()
            return next
        }
        let fallbackIndex = rules.firstIndex(where: \.isFallback) ?? rules.count
        rules.insert(copy, at: min(index + 1, fallbackIndex))
        save()
    }

    func alwaysOpen(host: String, in rowID: UUID) {
        guard let row = rows.first(where: { $0.id == rowID }) else { return }
        if let index = profiles.firstIndex(where: { $0.enabled && $0.browserRowID == rowID }) {
            profiles[index] = profiles[index].adding(host: host)
        } else {
            profiles.append(
                RouteProfile(
                    id: UUID(),
                    name: title(for: row),
                    enabled: true,
                    browserRowID: rowID,
                    patterns: [host]
                )
            )
        }
        save()
    }

    func describe(_ result: EngineResult) -> String {
        switch result {
        case .favourite:
            return favourite.map { "Opens \(title(for: $0))" } ?? "No favourite set"
        case .bestRunning:
            return bestRunning().map { "Opens \(title(for: $0))" } ?? "No running browser"
        case .open(let ids):
            return "Opens \(rowTitles(ids))"
        case .promptAll:
            return "Prompt for all browsers"
        case .promptRunning:
            return "Prompt for running browsers"
        case .prompt(let ids):
            return "Prompt for \(rowTitles(ids))"
        }
    }

    private func rowTitles(_ ids: [UUID]) -> String {
        let titles = ids.compactMap { id in rows.first { $0.id == id } }.map { title(for: $0) }
        return titles.isEmpty ? "no browsers" : titles.joined(separator: ", ")
    }

    func setLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("Login item: \(error.localizedDescription)")
        }
    }

    var loginItemOn: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func openSettings() {
        SettingsPresenter.present()
    }

    func exportSettings() throws -> Data {
        try Persistence.exportData(
            PersistedState(
                browsers: browsers,
                rows: rows,
                rules: rules,
                profiles: profiles,
                settings: settings,
                recent: recent
            )
        )
    }

    func importSettings(from url: URL) throws {
        let imported = try Persistence.importState(from: Data(contentsOf: url))
        browsers = imported.browsers
        rows = imported.rows
        rules = imported.rules
        profiles = imported.profiles
        settings = imported.settings
        for index in browsers.indices {
            guard !FileManager.default.fileExists(atPath: browsers[index].path),
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browsers[index].bundleIdentifier)
            else { continue }
            browsers[index].path = url.path
        }
        refreshProfileSnapshot()
        save()
    }

    func save() {
        guard !skipsPersistence else { return }
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Persistence.save(
                PersistedState(
                    browsers: self.browsers,
                    rows: self.rows,
                    rules: self.rules,
                    profiles: self.profiles,
                    settings: self.settings,
                    recent: self.recent
                )
            )
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    func flushSave() {
        guard !skipsPersistence else { return }
        saveWork?.cancel()
        saveWork = nil
        Persistence.save(
            PersistedState(
                browsers: browsers,
                rows: rows,
                rules: rules,
                profiles: profiles,
                settings: settings,
                recent: recent
            )
        )
    }

    private func observeRunning() {
        runningObservation = NSWorkspace.shared.observe(\.runningApplications, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.runningIDs = BrowserCatalog.runningIdentifiers(in: self.browsers)
            }
        }
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.runningIDs = BrowserCatalog.runningIdentifiers(in: self.browsers)
            }
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.runningIDs = BrowserCatalog.runningIdentifiers(in: self.browsers)
            }
        }
    }
}

enum ClipboardLink {
    static func firstURL(in string: String?) -> URL? {
        guard let string,
              let match = try? NSRegularExpression(pattern: #"https?://[^\s"'<>\)\]]+"#)
              .firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range, in: string)
        else { return nil }
        var candidate = String(string[range])
        while let last = candidate.last, ".,;:'\"!?)>".contains(last) {
            candidate.removeLast()
        }
        return URL(string: candidate)
    }
}
