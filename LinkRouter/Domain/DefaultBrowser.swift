import AppKit

enum DefaultBrowser {
    static let probeURL = URL(string: "https://example.com")!

    static func isLinkRouterDefault() -> Bool {
        guard let handler = NSWorkspace.shared.urlForApplication(toOpen: probeURL) else { return false }
        return handler.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
    }

    static func requestDefault() {
        let workspace = NSWorkspace.shared
        let app = Bundle.main.bundleURL
        workspace.setDefaultApplication(at: app, toOpenURLsWithScheme: "http") { _ in }
        workspace.setDefaultApplication(at: app, toOpenURLsWithScheme: "https") { _ in }
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    static func httpHandlers() -> [URL] {
        NSWorkspace.shared.urlsForApplications(toOpen: probeURL)
            .filter { url in
                if url.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL { return false }
                if url.lastPathComponent == "LinkRouter.app" { return false }
                // Exclude LinkRouter itself and variants (e.g. LinkRouter Preview)
                // that also declare the http/https schemes.
                if let identifier = Bundle(url: url)?.bundleIdentifier,
                   identifier.hasPrefix("app.linkrouter.LinkRouter") { return false }
                return true
            }
    }
}
