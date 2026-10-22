import AppKit
import Foundation

struct AppLinkHandler {
    let id: String
    let name: String
    let bundleIDs: [String]
    let examples: String
    let matches: (URL) -> Bool
    let strategy: Strategy
}

enum Strategy {
    case scheme((URL) -> URL?)
    case openWithApp
}

enum AppLinks {
    static let all: [AppLinkHandler] = [
        AppLinkHandler(
            id: "zoom",
            name: String(localized: "Zoom"),
            bundleIDs: ["us.zoom.xos"],
            examples: String(localized: "zoom.us meeting links"),
            matches: isZoom,
            strategy: .scheme(zoomURL)
        ),
        AppLinkHandler(
            id: "teams",
            name: String(localized: "Microsoft Teams"),
            bundleIDs: ["com.microsoft.teams2", "com.microsoft.teams"],
            examples: String(localized: "Teams meeting links"),
            matches: isTeams,
            strategy: .scheme(teamsURL)
        ),
        AppLinkHandler(
            id: "slack",
            name: String(localized: "Slack"),
            bundleIDs: ["com.tinyspeck.slackmacgap"],
            examples: String(localized: "Slack channel links"),
            matches: isSlack,
            strategy: .openWithApp
        ),
        AppLinkHandler(
            id: "figma",
            name: String(localized: "Figma"),
            bundleIDs: ["com.figma.Desktop"],
            examples: String(localized: "Figma design links"),
            matches: isFigma,
            strategy: .openWithApp
        ),
        AppLinkHandler(
            id: "spotify",
            name: String(localized: "Spotify"),
            bundleIDs: ["com.spotify.client"],
            examples: String(localized: "Spotify track, album, and playlist links"),
            matches: isSpotify,
            strategy: .scheme(spotifyURL)
        ),
        AppLinkHandler(
            id: "notion",
            name: String(localized: "Notion"),
            bundleIDs: ["notion.id"],
            examples: String(localized: "Notion page links"),
            matches: isNotion,
            strategy: .scheme(notionURL)
        ),
        AppLinkHandler(
            id: "linear",
            name: String(localized: "Linear"),
            bundleIDs: ["com.linear"],
            examples: String(localized: "Linear issue links"),
            matches: isLinear,
            strategy: .scheme(linearURL)
        ),
        AppLinkHandler(
            id: "discord",
            name: String(localized: "Discord"),
            bundleIDs: ["com.hnc.Discord"],
            examples: String(localized: "Discord channel links"),
            matches: isDiscord,
            strategy: .scheme(discordURL)
        ),
        AppLinkHandler(
            id: "music",
            name: String(localized: "Apple Music"),
            bundleIDs: ["com.apple.Music"],
            examples: String(localized: "Apple Music links"),
            matches: isMusic,
            strategy: .scheme(musicURL)
        )
    ]

    static func match(
        _ url: URL,
        installed: Set<String>,
        disabled: Set<String>
    ) -> (AppLinkHandler, URL)? {
        for handler in all where !disabled.contains(handler.id)
            && handler.bundleIDs.contains(where: installed.contains)
            && handler.matches(url) {
            switch handler.strategy {
            case .scheme(let transform):
                if let transformed = transform(url) {
                    return (handler, transformed)
                }
            case .openWithApp:
                return (handler, url)
            }
        }
        return nil
    }

    static func installedBundleIDs() -> Set<String> {
        Set(
            all
                .flatMap(\.bundleIDs)
                .filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
        )
    }

    static func applicationURL(for handler: AppLinkHandler) -> URL? {
        handler.bundleIDs
            .compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            .first
    }

    private static func isZoom(_ url: URL) -> Bool {
        guard host(url, isOrSubdomainOf: "zoom.us") else { return false }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let segments = components?.path.split(separator: "/", omittingEmptySubsequences: true) ?? []
        return segments.count >= 2 && segments[0] == "j" && !segments[1].isEmpty
    }

    private static func zoomURL(_ url: URL) -> URL? {
        guard let source = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let segments = source.path.split(separator: "/", omittingEmptySubsequences: true)
        guard segments.count >= 2, segments[0] == "j" else { return nil }

        var target = URLComponents()
        target.scheme = "zoommtg"
        target.host = "zoom.us"
        target.path = "/join"
        target.queryItems = [
            URLQueryItem(name: "action", value: "join"),
            URLQueryItem(name: "confno", value: String(segments[1]))
        ]
        if let password = source.queryItems?.first(where: { $0.name == "pwd" })?.value {
            target.queryItems?.append(URLQueryItem(name: "pwd", value: password))
        }
        return target.url
    }

    private static func isTeams(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              host == "teams.microsoft.com" || host == "teams.live.com"
        else { return false }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.path.hasPrefix("/l/") == true
    }

    private static func teamsURL(_ url: URL) -> URL? {
        guard let source = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var target = URLComponents()
        target.scheme = "msteams"
        target.percentEncodedPath = source.percentEncodedPath
        target.percentEncodedQuery = source.percentEncodedQuery
        return target.url
    }

    private static func isSlack(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), host.hasSuffix(".slack.com") else { return false }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.path.hasPrefix("/archives/") == true
    }

    private static func isFigma(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), host == "figma.com" || host == "www.figma.com" else { return false }
        let first = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .path.split(separator: "/", omittingEmptySubsequences: true).first
        return ["file", "design", "proto", "board", "slides"].contains(first.map(String.init) ?? "")
    }

    private static func isSpotify(_ url: URL) -> Bool {
        guard url.host?.lowercased() == "open.spotify.com" else { return false }
        var segments = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .path.split(separator: "/", omittingEmptySubsequences: true).map(String.init) ?? []
        if let first = segments.first,
           first.range(of: #"^intl-[a-z]{2}$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            segments.removeFirst()
        }
        guard segments.count >= 2 else { return false }
        return ["track", "album", "artist", "playlist", "show", "episode"].contains(segments[0].lowercased())
    }

    private static func spotifyURL(_ url: URL) -> URL? {
        var segments = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .path.split(separator: "/", omittingEmptySubsequences: true).map(String.init) ?? []
        if let first = segments.first,
           first.range(of: #"^intl-[a-z]{2}$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            segments.removeFirst()
        }
        guard segments.count >= 2 else { return nil }
        return URL(string: "spotify:\(segments[0]):\(segments[1])")
    }

    private static func isNotion(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "notion.so" || host == "www.notion.so" || host.hasSuffix(".notion.site")
    }

    private static func notionURL(_ url: URL) -> URL? {
        guard let source = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var target = URLComponents()
        target.scheme = "notion"
        target.host = source.host
        target.percentEncodedPath = source.percentEncodedPath
        target.percentEncodedQuery = source.percentEncodedQuery
        return target.url
    }

    private static func isLinear(_ url: URL) -> Bool {
        guard url.host?.lowercased() == "linear.app",
              let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath
        else { return false }
        let segments = path.split(separator: "/", omittingEmptySubsequences: true)
        guard segments.count >= 3 else { return false }
        return ["issue", "project", "view", "team"].contains(segments[1].lowercased())
    }

    private static func linearURL(_ url: URL) -> URL? {
        guard let source = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let segments = source.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: true)
        guard segments.count >= 3 else { return nil }
        var target = URLComponents()
        target.scheme = "linear"
        target.host = String(segments[0])
        target.percentEncodedPath = "/" + segments.dropFirst().joined(separator: "/")
        target.percentEncodedQuery = source.percentEncodedQuery
        return target.url
    }

    private static func isDiscord(_ url: URL) -> Bool {
        guard url.host?.lowercased() == "discord.com" else { return false }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.path.hasPrefix("/channels/") == true
    }

    private static func discordURL(_ url: URL) -> URL? {
        guard let source = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var target = URLComponents()
        target.scheme = "discord"
        target.host = "-"
        target.percentEncodedPath = source.percentEncodedPath
        target.percentEncodedQuery = source.percentEncodedQuery
        return target.url
    }

    private static func isMusic(_ url: URL) -> Bool {
        url.host?.lowercased() == "music.apple.com"
    }

    private static func musicURL(_ url: URL) -> URL? {
        guard let source = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var target = URLComponents()
        target.scheme = "music"
        target.host = "music.apple.com"
        target.percentEncodedPath = source.percentEncodedPath
        target.percentEncodedQuery = source.percentEncodedQuery
        return target.url
    }

    private static func host(_ url: URL, isOrSubdomainOf root: String) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == root || host.hasSuffix("." + root)
    }
}
