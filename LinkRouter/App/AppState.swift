import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
extension AppearanceMode {
    func apply() {
        guard NSApp != nil else { return }
        switch self {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    static var lastForeignApp: NSRunningApplication?

    @Published var browsers: [BrowserRecord]
    @Published var rows: [CatalogRow]
    @Published var rules: [Rule]
    @Published var profiles: [RouteProfile]
    @Published var settings: AppSettings
    @Published var focusMode: String?
    @Published var frontmostForeignBundleID: String? = nil
    @Published var isDefaultBrowser: Bool
    @Published var runningIDs: Set<String>
    @Published var pendingQuit: (url: URL, row: CatalogRow, browser: BrowserRecord, options: RuleOptions)?
    @Published var recent: [RoutedEntry]
    @Published var profileSnapshot: [String: [ChromeProfile]] = [:]
    private var profileWatcher: ProfileWatcher?

    let prompt = PromptController()
    let networkContext = NetworkContext.shared
    let syncStore: SyncStore
    let launchStart = Date()
    private var firstPromptLogged = false
    var dispatcher: Dispatching
    private let shortLinkExpander = ShortLinkExpander()
    private var hotKeys: HotKeys?
    var onPromptShown: (() -> Void)?
    var skipsPersistence = false
    @Published var clipboardURL: URL?
    var loadIssue: String?
    private(set) var isFirstLaunch = false
    private var pasteboardChangeCount = -1
    private var promptQueue: [(link: IncomingLink, rows: [CatalogRow], options: RuleOptions)] = []
    private var runningObservation: NSKeyValueObservation?
    private var saveWork: DispatchWorkItem?
    private var syncReconcileTimer: Timer?

    init(dispatcher: Dispatching = SystemDispatcher(), syncStore: SyncStore? = nil) {
        self.dispatcher = dispatcher
        self.syncStore = syncStore ?? SyncStore()
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
        let normalized = BrowserCatalog.normalized(browsers: initialBrowsers, rows: initialRows)
        browsers = normalized.browsers
        rows = normalized.rows
        rules = initialRules
        profiles = initialProfiles
        settings = initialSettings
        focusMode = FocusModeStore.current()
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
            for browser in self.browsers { _ = BrowserCatalog.icon(for: browser.path) }
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

    var routingContext: RoutingContext {
        networkContext.refresh()
        return RoutingContext(
            runningCount: runningCount,
            focusMode: focusMode,
            wifiSSID: networkContext.wifiSSID,
            vpnConnected: NetworkContext.currentVPNConnected()
        )
    }

    func setFocusMode(_ mode: String) {
        FocusModeStore.set(mode)
        focusMode = FocusModeStore.current()
    }

    func reconcileSync() {
        let isICloudDriveAvailable = syncStore.isICloudDriveAvailable
        if !settings.syncEnabled || (syncStore.isRunning && !isICloudDriveAvailable) {
            syncStore.stopWatching(preservingPendingEdits: settings.syncEnabled)
        } else if settings.syncEnabled && isICloudDriveAvailable && !syncStore.isRunning {
            syncStore.startWatching { [weak self] incoming in
                self?.applySyncedState(incoming)
            }
        }

        if settings.syncEnabled && !syncStore.isRunning {
            if syncReconcileTimer == nil {
                syncReconcileTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.reconcileSync()
                    }
                }
            }
        } else {
            syncReconcileTimer?.invalidate()
            syncReconcileTimer = nil
        }
    }

    func setSyncEnabled(_ enabled: Bool) {
        guard enabled != settings.syncEnabled else {
            reconcileSync()
            return
        }
        guard enabled else {
            settings.syncEnabled = false
            reconcileSync()
            save()
            return
        }
        guard syncStore.isICloudDriveAvailable else { return }
        if syncStore.isRemotePendingDownload {
            _ = syncStore.readRemoteState()
            let alert = NSAlert()
            alert.messageText = String(localized: "iCloud Drive is still downloading your settings")
            alert.informativeText = String(localized: "Try turning on sync again in a moment.")
            alert.addButton(withTitle: String(localized: "OK"))
            alert.runModal()
            return
        }

        let onApply: (PersistedState) -> Void = { [weak self] incoming in
            self?.applySyncedState(incoming)
        }
        if let remote = syncStore.remoteStateFromAnotherDevice() {
            let alert = NSAlert()
            alert.messageText = String(localized: "Use settings from iCloud Drive?")
            alert.addButton(withTitle: String(localized: "Use iCloud Drive Settings"))
            alert.addButton(withTitle: String(localized: "Use This Mac's Settings"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                settings.syncEnabled = true
                guard syncStore.startWatching(onApply: onApply, checkImmediately: false) else {
                    settings.syncEnabled = false
                    return
                }
                syncStore.applyRemote(remote, onApply: onApply)
            case .alertSecondButtonReturn:
                settings.syncEnabled = true
                guard syncStore.startWatching(onApply: onApply, checkImmediately: false) else {
                    settings.syncEnabled = false
                    return
                }
                syncStore.ignoreRemote(remote)
                save()
            default:
                return
            }
        } else {
            settings.syncEnabled = true
            guard syncStore.startWatching(onApply: onApply, checkImmediately: false) else {
                settings.syncEnabled = false
                return
            }
            save()
        }
    }

    private func applySyncedState(_ incoming: PersistedState) {
        let appearanceChanged = settings.appearance != incoming.settings.appearance
        browsers = incoming.browsers
        rows = incoming.rows
        rules = incoming.rules
        profiles = incoming.profiles
        var syncedSettings = incoming.settings
        syncedSettings.showMenuBar = settings.showMenuBar
        syncedSettings.onboardingDone = settings.onboardingDone
        syncedSettings.syncEnabled = settings.syncEnabled
        syncedSettings.shortcuts = settings.shortcuts
        settings = syncedSettings
        if appearanceChanged {
            settings.appearance.apply()
        }
        for index in browsers.indices {
            guard !FileManager.default.fileExists(atPath: browsers[index].path),
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browsers[index].bundleIdentifier)
            else { continue }
            browsers[index].path = url.path
        }
        for index in rows.indices {
            guard rows[index].kind == .firefoxProfile || rows[index].kind == .firefoxPrivate,
                  let path = rows[index].firefoxAbsPath,
                  !FileManager.default.fileExists(atPath: path),
                  let browser = browsers.first(where: { $0.id == rows[index].browserID })
            else { continue }
            let localProfiles = ProfileReader.firefoxProfiles(appURL: browser.bundleURL)
            if let localPath = ProfileReader.remapFirefoxProfilePath(
                path,
                name: rows[index].firefoxName,
                support: ProfileReader.firefoxSupportURL,
                localProfiles: localProfiles
            ) {
                rows[index].firefoxAbsPath = localPath
            }
        }
        runningIDs = BrowserCatalog.runningIdentifiers(in: browsers)
        refreshProfileSnapshot()
        save()
    }

    func browser(for row: CatalogRow) -> BrowserRecord? {
        browsers.first { $0.id == row.browserID }
    }

    func privateVariant(for row: CatalogRow) -> CatalogRow {
        guard let sourceBrowser = browser(for: row) else { return row }

        let kind: RowKind
        let chromeDirectory: String?
        let chromeName: String?
        let firefoxAbsPath: String?
        let firefoxName: String?
        switch row.kind {
        case .app:
            if ProfileReader.family(for: sourceBrowser.bundleIdentifier) != nil {
                kind = .chromePrivate
                chromeDirectory = nil
                chromeName = nil
                firefoxAbsPath = nil
                firefoxName = nil
            } else if ProfileReader.isFirefoxApp(sourceBrowser.bundleURL) {
                kind = .firefoxPrivate
                chromeDirectory = nil
                chromeName = nil
                firefoxAbsPath = nil
                firefoxName = nil
            } else {
                return row
            }
        case .chromeProfile:
            kind = .chromePrivate
            chromeDirectory = row.chromeDirectory
            chromeName = row.chromeName
            firefoxAbsPath = nil
            firefoxName = nil
        case .firefoxProfile:
            kind = .firefoxPrivate
            chromeDirectory = nil
            chromeName = nil
            firefoxAbsPath = row.firefoxAbsPath
            firefoxName = row.firefoxName
        case .chromePrivate, .firefoxPrivate:
            return row
        }

        if let existing = rows.first(where: { candidate in
            guard candidate.kind == kind,
                  browser(for: candidate)?.bundleIdentifier == sourceBrowser.bundleIdentifier
            else { return false }
            if kind == .chromePrivate {
                return candidate.chromeDirectory == chromeDirectory
            }
            return candidate.firefoxAbsPath == firefoxAbsPath
        }) {
            return existing
        }

        return CatalogRow(
            id: UUID(),
            browserID: sourceBrowser.id,
            kind: kind,
            chromeDirectory: chromeDirectory,
            chromeName: chromeName,
            firefoxName: firefoxName,
            firefoxAbsPath: firefoxAbsPath,
            enabled: true
        )
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
        let base = browser(for: row)?.displayName ?? String(localized: "Browser")
        switch row.kind {
        case .app:
            return base
        case .chromeProfile:
            return row.chromeName.map { String(localized: "\(base) · \($0)") } ?? base
        case .firefoxProfile:
            return row.firefoxName.map { String(localized: "\(base) · \($0)") } ?? base
        case .chromePrivate:
            let suffix = String(localized: "Private")
            if let name = row.chromeName { return String(localized: "\(base) · \(name) · \(suffix)") }
            return String(localized: "\(base) · \(suffix)")
        case .firefoxPrivate:
            let suffix = String(localized: "Private")
            if let name = row.firefoxName { return String(localized: "\(base) · \(name) · \(suffix)") }
            return String(localized: "\(base) · \(suffix)")
        }
    }

    func subtitle(for row: CatalogRow) -> String? {
        switch row.kind {
        case .app: return nil
        case .chromeProfile: return row.chromeDirectory
        case .firefoxProfile: return row.firefoxAbsPath
        case .chromePrivate:
            let family = browser(for: row).flatMap { ProfileReader.family(for: $0.bundleIdentifier) }
            return family?.privateWord ?? String(localized: "Incognito")
        case .firefoxPrivate: return String(localized: "Private window")
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
        let flags = NSEvent.modifierFlags
        let force = settings.forcePromptOnModifier && !flags.intersection([.shift, .control, .option, .command]).isEmpty
        if url.scheme?.lowercased() == "mailto" {
            routeMailto(url, forcePrompt: force)
            return
        }
        let isHTMLFile = url.isFileURL && ["html", "htm", "xhtml"].contains(url.pathExtension.lowercased())
        let isWebLink = ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        guard isHTMLFile || isWebLink else { return }
        pendingQuit = nil
        let cleaned = isHTMLFile
            ? url
            : URLCleaner.clean(url, unwrap: settings.unwrapRedirects, strip: settings.stripTrackingParams)
        if cleaned != url {
            Log.routing.info("Cleaned \(url.absoluteString) -> \(cleaned.absoluteString)")
        }
        let link = IncomingLink(url: cleaned, sourceBundleID: source?.bundleID, sourceName: source?.name)
        if isPaused, let row = favourite ?? bestRunning() {
            dispatch(link, row: row)
            return
        }
        if settings.expandShortLinks && ShortLinkExpander.isShortLink(cleaned) {
            let sourceBundleID = source?.bundleID
            let sourceName = source?.name
            Task { @MainActor [weak self] in
                guard let self else { return }
                let expanded = await self.shortLinkExpander.expand(cleaned)
                let cleanedExpanded = URLCleaner.clean(
                    expanded,
                    unwrap: self.settings.unwrapRedirects,
                    strip: self.settings.stripTrackingParams
                )
                if cleanedExpanded != expanded {
                    Log.routing.info("Cleaned \(expanded.absoluteString) -> \(cleanedExpanded.absoluteString)")
                }
                self.route(
                    IncomingLink(url: cleanedExpanded, sourceBundleID: sourceBundleID, sourceName: sourceName),
                    modifierForcePrompt: force
                )
            }
            return
        }
        route(link, modifierForcePrompt: force)
    }

    func configureHotKeys() {
        if hotKeys == nil {
            hotKeys = HotKeys { [weak self] action in
                switch action {
                case .openClipboardLink: self?.openClipboardLink()
                case .sendCurrentPage: self?.openCurrentPage()
                }
            }
        }
        hotKeys?.configure(settings.shortcuts)
    }

    func setShortcut(_ combo: KeyCombo?, for action: ShortcutAction) -> Bool {
        if let combo {
            if settings.shortcuts.contains(where: { $0.key != action && $0.value == combo })
                || hotKeys?.set(combo, for: action) == false {
                NSSound.beep()
                return false
            }
            settings.shortcuts[action] = combo
        } else {
            hotKeys?.clear(action)
            settings.shortcuts.removeValue(forKey: action)
        }
        save()
        return true
    }

    func openClipboardLink() {
        refreshClipboard()
        guard let url = ClipboardLink.firstURL(in: NSPasteboard.general.string(forType: .string)) else { return }
        handleIncoming(url)
    }

    func openCurrentPage() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let source = frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier
            ? Self.lastForeignApp : frontmost
        guard let source, let bundleID = source.bundleIdentifier else { return }
        guard FrontmostPage.isSupported(bundleID) else {
            showCurrentPageAlert(source.localizedName ?? bundleID)
            return
        }
        FrontmostPage.readURL(bundleID: bundleID) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let url):
                let rows = FrontmostPage.pickerRows(self.availableRows, sourceBundleID: bundleID) {
                    self.browser(for: $0)?.bundleIdentifier
                }
                self.showPrompt(link: IncomingLink(url: url, sourceBundleID: bundleID, sourceName: source.localizedName),
                                rows: rows)
            case .failure(.automationDenied):
                self.showAutomationSettingsAlert()
            case .failure:
                self.showCurrentPageAlert(source.localizedName ?? bundleID)
            }
        }
    }

    private func routeMailto(_ url: URL, forcePrompt: Bool) {
        let apps = MailCatalog.installed()
        let enabled = apps.filter { !settings.mail.disabled.contains($0.bundleIdentifier) }
        switch MailRouting.decide(
            mode: settings.mail.mode,
            favourite: settings.mail.favouriteBundleID,
            installed: Set(apps.map(\.bundleIdentifier)),
            enabled: enabled.map(\.bundleIdentifier),
            forcePrompt: forcePrompt
        ) {
        case .open(let bundleID):
            if let app = apps.first(where: { $0.bundleIdentifier == bundleID }) { openMailto(url, with: app) }
        case .prompt(let ids):
            showMailPrompt(url, apps: ids.compactMap { id in apps.first { $0.bundleIdentifier == id } })
        case .none:
            break
        }
    }

    private func openMailto(_ url: URL, with app: MailApp) {
        NSWorkspace.shared.open([url], withApplicationAt: app.url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func showMailPrompt(_ url: URL, apps: [MailApp]) {
        var appByID: [UUID: MailApp] = [:]
        let items = apps.map { app -> PromptItem in
            let id = UUID()
            appByID[id] = app
            return PromptItem(id: id, title: app.name, running: !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).isEmpty,
                              icon: NSWorkspace.shared.icon(forFile: app.url.path))
        }
        prompt.show(items: items, link: IncomingLink(url: url), allowsAlways: false, onPick: { [weak self] id, _ in
            guard let self, let app = id.flatMap({ appByID[$0] }) else { return }
            self.openMailto(url, with: app)
        }, onAlways: { _ in })
    }

    private func showCurrentPageAlert(_ browser: String) {
        let alert = NSAlert()
        alert.messageText = String(localized: "\(browser) doesn't let other apps read its current page.")
        alert.addButton(withTitle: String(localized: "OK"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showAutomationSettingsAlert() {
        let alert = NSAlert()
        alert.messageText = String(localized: "LinkRouter needs permission to read the current page.")
        alert.addButton(withTitle: String(localized: "Open Privacy Settings"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    private func route(
        _ link: IncomingLink,
        modifierForcePrompt: Bool,
        allowAppLinks: Bool = true
    ) {
        if allowAppLinks, !modifierForcePrompt,
           let (handler, transformedURL) = AppLinks.match(
            link.url,
            installed: AppLinks.installedBundleIDs(),
            disabled: settings.appLinksDisabled
           ),
           openAppLink(handler, transformedURL: transformedURL, link: link, modifierForcePrompt: modifierForcePrompt) {
            return
        }
        let explanation = RuleEngine.explain(
            link: link,
            profiles: profiles,
            rules: rules,
            context: routingContext,
            modifierForcePrompt: modifierForcePrompt
        )
        let options: RuleOptions
        switch explanation.source {
        case .rule(let id), .fallback(let id):
            options = rules.first(where: { $0.id == id })?.options ?? .init()
        case .modifier, .profile, .none:
            options = .init()
        }
        apply(explanation.result, link: link, options: options)
    }

    private func openAppLink(
        _ handler: AppLinkHandler,
        transformedURL: URL,
        link: IncomingLink,
        modifierForcePrompt: Bool
    ) -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = !settings.openInBackground
        switch handler.strategy {
        case .scheme:
            NSWorkspace.shared.open(transformedURL, configuration: configuration) { [weak self] _, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        Log.routing.error("Could not open app link for \(handler.name): \(error.localizedDescription)")
                        self.route(link, modifierForcePrompt: modifierForcePrompt, allowAppLinks: false)
                    } else {
                        self.recordAppLink(link, handler: handler)
                    }
                }
            }
            return true
        case .openWithApp:
            guard let appURL = AppLinks.applicationURL(for: handler) else {
                Log.routing.error("No application found for app link handler \(handler.id)")
                return false
            }
            NSWorkspace.shared.open([link.url], withApplicationAt: appURL, configuration: configuration) { [weak self] _, error in
                guard let self else { return }
                Task { @MainActor in
                    if let error {
                        Log.routing.error("Could not open app link for \(handler.name): \(error.localizedDescription)")
                        self.route(link, modifierForcePrompt: modifierForcePrompt, allowAppLinks: false)
                    } else {
                        self.recordAppLink(link, handler: handler)
                    }
                }
            }
            return true
        }
    }

    private func recordAppLink(_ link: IncomingLink, handler: AppLinkHandler) {
        let entry = RoutedEntry(id: UUID(), url: link.url, rowID: UUID(), title: handler.name, date: .now)
        recent.removeAll { $0.url == entry.url && $0.title == entry.title }
        recent.insert(entry, at: 0)
        if recent.count > 200 {
            recent.removeLast(recent.count - 200)
        }
        save()
    }

    func apply(_ result: EngineResult, link: IncomingLink, options: RuleOptions = .init()) {
        switch result {
        case .favourite:
            if let row = favourite { dispatch(link, row: row, options: options) }
            else { showPrompt(link: link, rows: availableRows, options: options) }
        case .bestRunning:
            if let row = bestRunning() { dispatch(link, row: row, options: options) }
            else if let row = favourite { dispatch(link, row: row, options: options) }
            else { showPrompt(link: link, rows: availableRows, options: options) }
        case .open(let ids):
            let targets = ids.compactMap { id in rows.first { $0.id == id } }.filter { isAvailable($0) }
            if targets.isEmpty {
                showPrompt(link: link, rows: availableRows, options: options)
            } else {
                for row in targets { dispatch(link, row: row, options: options) }
            }
        case .promptAll:
            showPrompt(link: link, rows: availableRows, options: options)
        case .promptRunning:
            let running = availableRows.filter { isRunning($0) }
            showPrompt(link: link, rows: running.isEmpty ? availableRows : running, options: options)
        case .prompt(let ids):
            let subset = ids.compactMap { id in rows.first { $0.id == id } }.filter { isAvailable($0) }
            showPrompt(link: link, rows: subset.isEmpty ? availableRows : subset, options: options)
        }
    }

    func bestRunning() -> CatalogRow? {
        availableRows.first { isRunning($0) }
    }

    func showPrompt(link: IncomingLink, rows: [CatalogRow], options: RuleOptions = .init()) {
        if prompt.isVisible {
            if !promptQueue.contains(where: { $0.link.url == link.url }) {
                promptQueue.append((link, rows, options))
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
                    self.dispatch(link, row: row, isRetry: true, options: options)
                }
                if !keepOpen {
                    self.showNextQueuedPrompt()
                }
            },
            onAlways: { [weak self] rowID in
                guard let self else { return }
                self.alwaysOpen(host: link.host, in: rowID)
                if let row = self.rows.first(where: { $0.id == rowID }) {
                    self.dispatch(link, row: row, isRetry: true, options: options)
                }
                self.showNextQueuedPrompt()
            },
            onTimeout: { [weak self] in
                guard let self else { return }
                if let row = self.favourite {
                    self.dispatch(link, row: row, isRetry: true, options: options)
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
            showPrompt(link: next.link, rows: next.rows, options: next.options)
            return
        }
    }

    func dispatch(
        _ link: IncomingLink,
        row: CatalogRow,
        isRetry: Bool = false,
        options: RuleOptions = .init()
    ) {
        let targetRow = options.privateWindow ? privateVariant(for: row) : row
        guard let browser = resolvedBrowser(for: targetRow) else {
            Log.routing.error("No browser available for \(self.title(for: targetRow))")
            let candidates = availableRows
            if candidates.isEmpty {
                presentNoBrowserAlert()
            } else {
                showPrompt(link: link, rows: candidates, options: options)
            }
            return
        }
        let outcome = dispatcher.open(
            url: link.url,
            browser: browser,
            row: targetRow,
            activates: options.background.activates(openInBackground: settings.openInBackground),
            forceNewInstance: false
        ) { [weak self] error in
            guard let self, let error else { return }
            self.handleOpenError(error, link: link, browser: browser, isRetry: isRetry)
        }
        switch outcome {
        case .opened:
            pendingQuit = nil
            let entry = RoutedEntry(id: UUID(), url: link.url, rowID: targetRow.id, title: title(for: targetRow), date: .now)
            recent.removeAll { $0.url == entry.url && $0.rowID == entry.rowID }
            recent.insert(entry, at: 0)
            if recent.count > 200 {
                recent.removeLast(recent.count - 200)
            }
            save()
        case .needsHostQuit(_, let name):
            pendingQuit = (link.url, targetRow, browser, options)
            prompt.dismiss()
            presentQuitAlert(browserName: name, url: link.url, row: targetRow, browser: browser)
        case .failed(let message):
            Log.routing.error("Dispatch failed: \(message)")
        }
    }

    func reopen(_ entry: RoutedEntry) {
        let link = IncomingLink(url: entry.url)
        if let (handler, transformedURL) = AppLinks.match(
            entry.url,
            installed: AppLinks.installedBundleIDs(),
            disabled: settings.appLinksDisabled
        ), openAppLink(
            handler,
            transformedURL: transformedURL,
            link: link,
            modifierForcePrompt: false
        ) {
            return
        }
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
        alert.messageText = String(localized: "No browser available")
        alert.informativeText = String(localized: "Add a browser in LinkRouter → Browsers.")
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }

    private func presentOpenFailedAlert(browserName: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Couldn't open \(browserName)")
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
            activates: pending.options.background.activates(openInBackground: settings.openInBackground),
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
        alert.messageText = String(localized: "\(browserName) is already running")
        alert.informativeText = String(localized: "\(browserName) applies a profile only when it starts cold. Open a separate \(browserName) instance for this profile, or open the link in the running \(browserName) without a profile.")
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
            activates: pending.options.background.activates(openInBackground: settings.openInBackground),
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
        let normalized = BrowserCatalog.normalized(browsers: browsers, rows: rows)
        if normalized.browsers != browsers || normalized.rows != rows {
            let keptRowIDs = Set(normalized.rows.map(\.id))
            for index in rules.indices {
                rules[index].behaviour.rowIDs.removeAll { !keptRowIDs.contains($0) }
            }
            for index in profiles.indices {
                if let id = profiles[index].browserRowID, !keptRowIDs.contains(id) {
                    profiles[index].browserRowID = nil
                }
            }
            browsers = normalized.browsers
            rows = normalized.rows
        }
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

    func moveProfile(id: UUID, to target: UUID) {
        guard let from = profiles.firstIndex(where: { $0.id == id }),
              let to = profiles.firstIndex(where: { $0.id == target }),
              from != to else { return }
        profiles.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        save()
    }

    @discardableResult
    func addRule() -> Rule {
        let rule = Rule(
            id: UUID(),
            title: String(localized: "New rule"),
            enabled: true,
            combinator: .all,
            conditions: [.url()],
            behaviour: .promptAll,
            isFallback: false
        )
        rules.insert(rule, at: 0)
        save()
        return rule
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

    func moveRule(id: UUID, to target: UUID) {
        guard let from = rules.firstIndex(where: { $0.id == id && !$0.isFallback }),
              let to = rules.firstIndex(where: { $0.id == target && !$0.isFallback }),
              from != to else { return }
        rules.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
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
            return favourite.map { String(localized: "Opens \(title(for: $0))") } ?? String(localized: "No favourite set")
        case .bestRunning:
            return bestRunning().map { String(localized: "Opens \(title(for: $0))") } ?? String(localized: "No running browser")
        case .open(let ids):
            return String(localized: "Opens \(rowTitles(ids))")
        case .promptAll:
            return String(localized: "Prompt for all browsers")
        case .promptRunning:
            return String(localized: "Prompt for running browsers")
        case .prompt(let ids):
            return String(localized: "Prompt for \(rowTitles(ids))")
        }
    }

    private func rowTitles(_ ids: [UUID]) -> String {
        let titles = ids.compactMap { id in rows.first { $0.id == id } }.map { title(for: $0) }
        return titles.isEmpty ? String(localized: "no browsers") : titles.joined(separator: ", ")
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
        var importedSettings = imported.settings
        importedSettings.syncEnabled = settings.syncEnabled
        settings = importedSettings
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
        let state = persistedState()
        syncStore.scheduleWrite(state)
        let work = DispatchWorkItem {
            Persistence.save(state)
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    func flushSave() {
        guard !skipsPersistence else { return }
        saveWork?.cancel()
        saveWork = nil
        let state = persistedState()
        syncStore.scheduleWrite(state)
        syncStore.flushPendingWrite()
        saveWork?.cancel()
        saveWork = nil
        Persistence.save(persistedState())
    }

    private func persistedState() -> PersistedState {
        PersistedState(
            browsers: browsers,
            rows: rows,
            rules: rules,
            profiles: profiles,
            settings: settings,
            recent: recent
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
