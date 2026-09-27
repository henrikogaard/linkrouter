import AppKit

enum BrowserCatalog {
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
        for url in DefaultBrowser.httpHandlers() {
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
        for url in DefaultBrowser.httpHandlers() where !known.contains(url.path) {
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

    static func addApp(at url: URL, browsers: inout [BrowserRecord], rows: inout [CatalogRow]) -> Bool {
        guard url.pathExtension == "app", let meta = metadata(for: url) else { return false }
        if let existing = browsers.first(where: { $0.path == url.path }) {
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
