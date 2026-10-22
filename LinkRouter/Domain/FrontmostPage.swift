import AppKit
import Foundation

enum FrontmostPage {
    enum ReadError: Error {
        case unsupported
        case automationDenied
        case failed
    }

    private static let safariIDs: Set<String> = [
        "com.apple.Safari", "com.apple.SafariTechnologyPreview"
    ]
    private static let chromiumIDs: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.canary", "com.google.Chrome.beta",
        "org.chromium.Chromium", "com.brave.Browser", "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi", "company.thebrowser.Browser"
    ]
    private static let scriptQueue = DispatchQueue(label: "app.linkrouter.frontmost-page")

    static func script(forBundleID bundleID: String) -> String? {
        if safariIDs.contains(bundleID) {
            return "tell application id \"\(bundleID)\" to get URL of front document"
        }
        guard chromiumIDs.contains(bundleID) else { return nil }
        return "tell application id \"\(bundleID)\" to get URL of active tab of front window"
    }

    static func isSupported(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return script(forBundleID: bundleID) != nil
    }

    static func parseResult(_ value: String?) -> URL? {
        guard let value else { return nil }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let url = URL(string: text),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    static func pickerRows(
        _ rows: [CatalogRow],
        sourceBundleID: String,
        browserBundleID: (CatalogRow) -> String?
    ) -> [CatalogRow] {
        let filtered = rows.filter { row in
            row.kind != .app || browserBundleID(row) != sourceBundleID
        }
        return filtered.isEmpty ? rows : filtered
    }

    static func readURL(
        bundleID: String,
        completion: @escaping (Result<URL, ReadError>) -> Void
    ) {
        guard let source = script(forBundleID: bundleID) else {
            DispatchQueue.main.async { completion(.failure(.unsupported)) }
            return
        }
        scriptQueue.async {
            let appleScript = NSAppleScript(source: source)!
            var errorInfo: NSDictionary?
            let result = appleScript.executeAndReturnError(&errorInfo)
            let outcome: Result<URL, ReadError>
            if let errorInfo {
                let number = errorInfo["NSAppleScriptErrorNumber"] as? Int
                outcome = .failure(number == -1743 ? .automationDenied : .failed)
            } else if let url = parseResult(result.stringValue) {
                outcome = .success(url)
            } else {
                outcome = .failure(.failed)
            }
            DispatchQueue.main.async { completion(outcome) }
        }
    }
}
