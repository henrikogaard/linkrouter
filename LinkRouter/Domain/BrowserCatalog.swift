import AppKit

enum BrowserCatalog {
    /// Apps that merely *can* open an https URL (Launch Services document types,
    /// universal links) are not browsers — a real browser declares the http and
    /// https URL schemes in its Info.plist.
    static func isBrowser(_ appURL: URL) -> Bool {
        guard let bundle = Bundle(url: appURL),
              let types = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        else { return false }
        let schemes = Set(
            types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
                .map { $0.lowercased() }
        )
        return schemes.contains("http") && schemes.contains("https")
    }

    static func metadata(for appURL: URL) -> (bundleIdentifier: String, displayName: String)? {
        guard let bundle = Bundle(url: appURL),
              let identifier = bundle.bundleIdentifier
        else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        return (identifier, name)
    }

    @MainActor private static var iconCache: [String: NSImage] = [:]

    @MainActor
    static func icon(for path: String) -> NSImage {
        if let cached = iconCache[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        iconCache[path] = image
        return image
    }

    @MainActor
    static func invalidateIcons(for paths: String...) {
        for path in paths {
            iconCache.removeValue(forKey: path)
        }
    }

    static func seedFromLaunchServices() -> (browsers: [BrowserRecord], rows: [CatalogRow]) {
        var browsers: [BrowserRecord] = []
        var rows: [CatalogRow] = []
        for url in DefaultBrowser.httpHandlers() where isBrowser(url) {
            guard let meta = metadata(for: url) else { continue }
            if browsers.contains(where: { $0.path == url.path || $0.bundleIdentifier == meta.bundleIdentifier }) { continue }
            let record = BrowserRecord(
                id: UUID(),
                path: url.path,
                bundleIdentifier: meta.bundleIdentifier,
                displayName: meta.displayName
            )
            browsers.append(record)
            rows.append(
                CatalogRow(
                    id: UUID(),
                    browserID: record.id,
                    kind: .app,
                    chromeDirectory: nil,
                    chromeName: nil,
                    firefoxName: nil,
                    firefoxAbsPath: nil,
                    enabled: true
                )
            )
        }
        return (browsers, rows)
    }

    static func appendDiscovered(browsers: inout [BrowserRecord], rows: inout [CatalogRow]) {
        let known = Set(browsers.map(\.path))
        let knownIDs = Set(browsers.map(\.bundleIdentifier))
        for url in DefaultBrowser.httpHandlers() where !known.contains(url.path) && isBrowser(url) {
            guard let meta = metadata(for: url), !knownIDs.contains(meta.bundleIdentifier) else { continue }
            let record = BrowserRecord(
                id: UUID(),
                path: url.path,
                bundleIdentifier: meta.bundleIdentifier,
                displayName: meta.displayName
            )
            browsers.append(record)
            rows.append(
                CatalogRow(
                    id: UUID(),
                    browserID: record.id,
                    kind: .app,
                    enabled: true
                )
            )
        }
    }

    /// Collapses the catalog to one record per bundle identifier and one row
    /// per (browser, kind, target). Older versions could persist the same app
    /// several times — or apps that merely *can* open https URLs — so loading
    /// also drops records that still exist on disk but aren't browsers.
    /// Records whose app is missing are kept so their rows can show Missing.
    static func normalized(browsers: [BrowserRecord], rows: [CatalogRow]) -> (browsers: [BrowserRecord], rows: [CatalogRow]) {
        var canonicalIDs: [String: UUID] = [:]
        var remappedIDs: [UUID: UUID] = [:]
        var keptBrowsers: [BrowserRecord] = []
        for browser in browsers {
            if let canonical = canonicalIDs[browser.bundleIdentifier] {
                remappedIDs[browser.id] = canonical
                continue
            }
            let appURL = browser.bundleURL
            if FileManager.default.fileExists(atPath: appURL.path), !isBrowser(appURL) {
                continue
            }
            canonicalIDs[browser.bundleIdentifier] = browser.id
            keptBrowsers.append(browser)
        }
        var seenKeys = Set<String>()
        var keptRows: [CatalogRow] = []
        for row in rows {
            var row = row
            if let canonical = remappedIDs[row.browserID] {
                row.browserID = canonical
            }
            guard canonicalIDs.values.contains(row.browserID) else { continue }
            let key = [
                row.browserID.uuidString, row.kind.rawValue,
                row.chromeDirectory ?? "", row.chromeName ?? "",
                row.firefoxName ?? "", row.firefoxAbsPath ?? ""
            ].joined(separator: "\u{1f}")
            guard seenKeys.insert(key).inserted else { continue }
            keptRows.append(row)
        }
        return (keptBrowsers, keptRows)
    }

    static func addApp(at url: URL, browsers: inout [BrowserRecord], rows: inout [CatalogRow]) -> Bool {
        guard url.pathExtension == "app", let meta = metadata(for: url) else { return false }
        if let existing = browsers.first(where: { $0.path == url.path || $0.bundleIdentifier == meta.bundleIdentifier }) {
            if !rows.contains(where: { $0.browserID == existing.id && $0.kind == .app }) {
                rows.append(CatalogRow(id: UUID(), browserID: existing.id, kind: .app, enabled: true))
            }
            return true
        }
        let record = BrowserRecord(
            id: UUID(),
            path: url.path,
            bundleIdentifier: meta.bundleIdentifier,
            displayName: meta.displayName
        )
        browsers.append(record)
        rows.append(CatalogRow(id: UUID(), browserID: record.id, kind: .app, enabled: true))
        return true
    }

    static func runningIdentifiers(in browsers: [BrowserRecord]) -> Set<String> {
        Set(
            browsers
                .map(\.bundleIdentifier)
                .filter { Dispatcher.isRunning(bundleIdentifier: $0) }
        )
    }
}
