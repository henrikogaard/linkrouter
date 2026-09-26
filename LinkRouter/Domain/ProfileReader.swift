import Foundation

struct ChromeProfile: Equatable {
    var directory: String
    var name: String
}

struct FirefoxProfile: Equatable {
    var name: String
    var absPath: String
}

enum ProfileReader {
    static let chromeBundleID = "com.google.Chrome"
    static let safariBundleID = "com.apple.Safari"

    static func chromeProfiles() -> [ChromeProfile] {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome/Local State")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return parseChromeProfiles(localState: data)
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
