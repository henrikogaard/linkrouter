import Foundation

enum URLCleaner {
    static let trackingParams: Set<String> = [
        "fbclid", "gclid", "gclsrc", "dclid", "msclkid", "mc_cid", "mc_eid",
        "igshid", "_hsenc", "_hsmi", "vero_id", "yclid", "twclid", "ttclid",
        "ref_src", "spm", "oly_anon_id", "oly_enc_id", "wickedid", "_openstat",
    ]

    static func stripTracking(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems
        else { return url }
        let kept = items.filter { !isTrackingParam($0.name) }
        guard kept.count != items.count else { return url }
        components.queryItems = kept.isEmpty ? nil : kept
        return components.url ?? url
    }

    static func unwrapRedirect(_ url: URL) -> URL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased()
        else { return url }
        let path = components.path
        func param(_ name: String) -> String? {
            components.queryItems?.first { $0.name.lowercased() == name }?.value
        }
        let candidate: String?
        if (host.hasPrefix("google.") || host.contains(".google.")) && path == "/url" {
            candidate = param("q") ?? param("url")
        } else if host.hasSuffix("safelinks.protection.outlook.com") {
            candidate = param("url")
        } else if host == "slack-redir.net" && path.hasPrefix("/link") {
            candidate = param("url")
        } else if (host == "l.facebook.com" || host == "lm.facebook.com") && path.hasPrefix("/l.php") {
            candidate = param("u")
        } else if host == "l.instagram.com" {
            candidate = param("u")
        } else if host == "out.reddit.com" {
            candidate = param("url")
        } else if host == "www.youtube.com" && path == "/redirect" {
            candidate = param("q")
        } else if host == "t.umblr.com" && path.hasPrefix("/redirect") {
            candidate = param("z")
        } else if (host == "www.linkedin.com" || host == "linkedin.com") && path.hasPrefix("/redir/redirect") {
            candidate = param("url")
        } else if host == "href.li" {
            candidate = components.query
        } else if host == "l.messenger.com" {
            candidate = param("u")
        } else {
            candidate = nil
        }
        guard let candidate,
              let unwrapped = URL(string: candidate),
              let scheme = unwrapped.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return url }
        return unwrapped
    }

    static func clean(_ url: URL, unwrap: Bool, strip: Bool) -> URL {
        var result = url
        if unwrap { result = unwrapRedirect(result) }
        if strip { result = stripTracking(result) }
        return result
    }

    private static func isTrackingParam(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("utm_") || trackingParams.contains(lower)
    }
}
