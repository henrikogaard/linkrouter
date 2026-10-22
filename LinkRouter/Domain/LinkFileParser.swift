import Foundation

enum LinkFileParser {
    static func link(in fileURL: URL) -> URL? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        switch fileURL.pathExtension.lowercased() {
        case "webloc":
            return webLocationURL(from: data)
        case "url":
            return internetShortcutURL(from: data)
        default:
            return nil
        }
    }

    static func webLocationURL(from data: Data) -> URL? {
        guard let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = object as? [String: Any],
              let value = dictionary["URL"] as? String
        else { return nil }
        return httpURL(value)
    }

    static func internetShortcutURL(from data: Data) -> URL? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for rawLine in text.replacingOccurrences(of: "\u{feff}", with: "").components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix(";"), !line.hasPrefix("#"),
                  let separator = line.firstIndex(of: "=")
            else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            guard key.caseInsensitiveCompare("URL") == .orderedSame else { continue }
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            return httpURL(value)
        }
        return nil
    }

    private static func httpURL(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil
        else { return nil }
        return url
    }
}
