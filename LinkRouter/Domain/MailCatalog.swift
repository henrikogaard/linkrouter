import AppKit
import Foundation

struct MailApp: Identifiable, Equatable {
    let bundleIdentifier: String
    let name: String
    let url: URL
    var id: String { bundleIdentifier }
}

enum MailCatalog {
    static func installed() -> [MailApp] {
        guard let mailto = URL(string: "mailto:") else { return [] }
        var seen = Set<String>()
        return NSWorkspace.shared.urlsForApplications(toOpen: mailto).compactMap { url in
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier,
                  bundleID != Bundle.main.bundleIdentifier,
                  seen.insert(bundleID).inserted else { return nil }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            return MailApp(bundleIdentifier: bundleID, name: name, url: url)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func isDefault() -> Bool {
        guard let mailto = URL(string: "mailto:"),
              let defaultURL = NSWorkspace.shared.urlForApplication(toOpen: mailto) else { return false }
        return defaultURL.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
    }

    static func setDefault(completion: @escaping (Error?) -> Void) {
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "mailto") { error in
            completion(error)
        }
    }
}
