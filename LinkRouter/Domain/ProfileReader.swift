import Foundation

struct ChromeProfile: Equatable {
    var directory: String
    var name: String
}

struct FirefoxProfile: Equatable {
    var name: String
    var absPath: String
}

struct ChromiumFamily: Equatable {
    let bundleID: String
    let shortName: String
    let userDataDir: String
    let privateFlag: String

    var privateWord: String {
        privateFlag == "--inprivate" ? "InPrivate" : "Incognito"
    }
}

enum ProfileReader {
    static let chromeBundleID = "com.google.Chrome"
    static let safariBundleID = "com.apple.Safari"

    static let chromiumFamilies: [ChromiumFamily] = [
        ChromiumFamily(bundleID: "com.google.Chrome", shortName: "Chrome", userDataDir: "Google/Chrome", privateFlag: "--incognito"),
        ChromiumFamily(bundleID: "com.google.Chrome.canary", shortName: "Chrome Canary", userDataDir: "Google/Chrome Canary", privateFlag: "--incognito"),
        ChromiumFamily(bundleID: "com.google.Chrome.beta", shortName: "Chrome Beta", userDataDir: "Google/Chrome Beta", privateFlag: "--incognito"),
        ChromiumFamily(bundleID: "com.brave.Browser", shortName: "Brave", userDataDir: "BraveSoftware/Brave-Browser", privateFlag: "--incognito"),
        ChromiumFamily(bundleID: "com.microsoft.edgemac", shortName: "Edge", userDataDir: "Microsoft Edge", privateFlag: "--inprivate"),
        ChromiumFamily(bundleID: "com.vivaldi.Vivaldi", shortName: "Vivaldi", userDataDir: "Vivaldi", privateFlag: "--incognito"),
        ChromiumFamily(bundleID: "org.chromium.Chromium", shortName: "Chromium", userDataDir: "Chromium", privateFlag: "--incognito"),
        ChromiumFamily(bundleID: "company.thebrowser.Browser", shortName: "Arc", userDataDir: "Arc/User Data", privateFlag: "--incognito"),
    ]

    static func family(for bundleID: String) -> ChromiumFamily? {
        chromiumFamilies.first { $0.bundleID == bundleID }
    }

    static func userDataURL(for family: ChromiumFamily) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(family.userDataDir)")
    }

    static func chromeProfiles(family: ChromiumFamily) -> [ChromeProfile] {
        let url = userDataURL(for: family).appendingPathComponent("Local State")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return parseChromeProfiles(localState: data)
    }

    static func chromeProfiles() -> [ChromeProfile] {
        guard let family = family(for: chromeBundleID) else { return [] }
        return chromeProfiles(family: family)
    }

    static func parseChromeProfiles(localState data: Data) -> [ChromeProfile] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cache = json["profile"] as? [String: Any],
              let info = cache["info_cache"] as? [String: Any]
        else { return [] }

        return info.keys.sorted().compactMap { key in
            let name: String
            if let entry = info[key] as? [String: Any], let n = entry["name"] as? String, !n.isEmpty {
                name = n
            } else {
                name = key
            }
            return ChromeProfile(directory: key, name: name)
        }
    }

    static func firefoxProfiles(appURL: URL) -> [FirefoxProfile] {
        guard appURL.lastPathComponent == "Firefox.app" else { return [] }
        let support = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Firefox")
        let iniURL = support.appendingPathComponent("profiles.ini")
        guard let text = try? String(contentsOf: iniURL, encoding: .utf8) else { return [] }
        return parseFirefoxProfiles(ini: text, support: support)
    }

    static func parseFirefoxProfiles(ini text: String, support: URL) -> [FirefoxProfile] {
        var profiles: [FirefoxProfile] = []
        var current: [String: String] = [:]
        var inProfile = false

        func flush() {
            guard inProfile,
                  let name = current["Name"], !name.isEmpty,
                  let path = current["Path"], !path.isEmpty
            else { return }
            let relative = current["IsRelative"] != "0"
            let abs: String
            if relative {
                abs = support.appendingPathComponent(path).path
            } else {
                abs = path
            }
            profiles.append(FirefoxProfile(name: name, absPath: abs))
        }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") && line.hasSuffix("]") {
                flush()
                current = [:]
                let header = String(line.dropFirst().dropLast())
                inProfile = header.lowercased().hasPrefix("profile")
                continue
            }
            guard inProfile, let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq])
            let value = String(line[line.index(after: eq)...])
            current[key] = value
        }
        flush()
        return profiles
    }

    static func isFirefoxApp(_ url: URL) -> Bool {
        url.lastPathComponent == "Firefox.app"
    }
}
