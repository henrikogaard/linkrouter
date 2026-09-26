import Foundation

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }
}

enum Combinator: String, Codable, CaseIterable, Identifiable {
    case any, all, none
    var id: String { rawValue }
    var label: String {
        switch self {
        case .any: String(localized: "any of the following are true")
        case .all: String(localized: "all of the following are true")
        case .none: String(localized: "none of the following are true")
        }
    }
    var shortLabel: String {
        switch self {
        case .any: String(localized: "Any")
        case .all: String(localized: "All")
        case .none: String(localized: "None")
        }
    }
}

enum URLMatcher: String, Codable, CaseIterable, Identifiable {
    case `is`, isNot, contains, beginsWith, endsWith, like, regex
    var id: String { rawValue }
    var label: String {
        switch self {
        case .is: String(localized: "is")
        case .isNot: String(localized: "is not")
        case .contains: String(localized: "contains")
        case .beginsWith: String(localized: "begins with")
        case .endsWith: String(localized: "ends with")
        case .like: String(localized: "is like")
        case .regex: String(localized: "matches regex")
        }
    }
}

enum CountComparator: String, Codable, CaseIterable, Identifiable {
    case `is`, isNot, lessThan, greaterThan
    var id: String { rawValue }
    var label: String {
        switch self {
        case .is: String(localized: "is")
        case .isNot: String(localized: "is not")
        case .lessThan: String(localized: "is less than")
        case .greaterThan: String(localized: "is greater than")
        }
    }
}

enum LinkKind: String, Codable, CaseIterable, Identifiable {
    case website, localHTML
    var id: String { rawValue }
    var label: String {
        switch self {
        case .website: String(localized: "website link")
        case .localHTML: String(localized: "local HTML file")
        }
    }
}

struct Condition: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case url, runningCount, linkType, sourceApp, schedule
        var id: String { rawValue }
        var label: String {
            switch self {
            case .url: String(localized: "Web address")
            case .runningCount: String(localized: "Running browsers")
            case .linkType: String(localized: "Link type")
            case .sourceApp: String(localized: "Sent from app")
            case .schedule: String(localized: "Time of day")
            }
        }
    }

    var id: UUID
    var kind: Kind
    var urlMatcher: URLMatcher
    var pattern: String
    var countComparator: CountComparator
    var count: Int
    var linkKind: LinkKind
    var startMinute: Int = 540
    var endMinute: Int = 1020
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]

    static func url(matcher: URLMatcher = .contains, pattern: String = "") -> Condition {
        Condition(
            id: UUID(),
            kind: .url,
            urlMatcher: matcher,
            pattern: pattern,
            countComparator: .greaterThan,
            count: 0,
            linkKind: .website
        )
    }

    static func runningCount(_ comparator: CountComparator = .greaterThan, _ n: Int = 0) -> Condition {
        Condition(
            id: UUID(),
            kind: .runningCount,
            urlMatcher: .contains,
            pattern: "",
            countComparator: comparator,
            count: n,
            linkKind: .website
        )
    }
}

extension Condition {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        urlMatcher = try container.decodeIfPresent(URLMatcher.self, forKey: .urlMatcher) ?? .contains
        pattern = try container.decodeIfPresent(String.self, forKey: .pattern) ?? ""
        countComparator = try container.decodeIfPresent(CountComparator.self, forKey: .countComparator) ?? .greaterThan
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
        linkKind = try container.decodeIfPresent(LinkKind.self, forKey: .linkKind) ?? .website
        startMinute = try container.decodeIfPresent(Int.self, forKey: .startMinute) ?? 540
        endMinute = try container.decodeIfPresent(Int.self, forKey: .endMinute) ?? 1020
        weekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? [2, 3, 4, 5, 6]
    }
}

struct Behaviour: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case useFavourite
        case useBestRunning
        case promptAll
        case promptRunning
        case promptBrowsers
        case openBrowser
        case openBrowsersInOrder
        case useDefaultBehaviour
        var id: String { rawValue }
        var label: String {
            switch self {
            case .useFavourite: String(localized: "Use favourite browser")
            case .useBestRunning: String(localized: "Use best running browser")
            case .promptAll: String(localized: "Prompt for all browsers")
            case .promptRunning: String(localized: "Prompt for running browsers")
            case .promptBrowsers: String(localized: "Prompt for these browsers")
            case .openBrowser: String(localized: "Always use this browser")
            case .openBrowsersInOrder: String(localized: "Use these browsers in order")
            case .useDefaultBehaviour: String(localized: "Use default behaviour")
            }
        }
        var needsRows: Bool {
            switch self {
            case .promptBrowsers, .openBrowser, .openBrowsersInOrder: true
            default: false
            }
        }
    }

    var kind: Kind
    var rowIDs: [UUID]

    static let useFavourite = Behaviour(kind: .useFavourite, rowIDs: [])
    static let useBestRunning = Behaviour(kind: .useBestRunning, rowIDs: [])
    static let promptAll = Behaviour(kind: .promptAll, rowIDs: [])
    static let promptRunning = Behaviour(kind: .promptRunning, rowIDs: [])
    static let useDefaultBehaviour = Behaviour(kind: .useDefaultBehaviour, rowIDs: [])
}

struct Rule: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var enabled: Bool
    var combinator: Combinator
    var conditions: [Condition]
    var behaviour: Behaviour
    var isFallback: Bool

    static func shipped() -> [Rule] {
        [
            Rule(
                id: UUID(),
                title: "Some browsers are running",
                enabled: true,
                combinator: .all,
                conditions: [.runningCount(.greaterThan, 0)],
                behaviour: .promptRunning,
                isFallback: false
            ),
            Rule(
                id: UUID(),
                title: "Everything else",
                enabled: true,
                combinator: .all,
                conditions: [],
                behaviour: .promptAll,
                isFallback: true
            )
        ]
    }
}

enum RowKind: String, Codable {
    case app
    case chromeProfile
    case firefoxProfile
    case chromePrivate
    case firefoxPrivate
}

struct BrowserRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var path: String
    var bundleIdentifier: String
    var displayName: String

    var bundleURL: URL { URL(fileURLWithPath: path) }
}

struct CatalogRow: Codable, Equatable, Identifiable {
    var id: UUID
    var browserID: UUID
    var kind: RowKind
    var chromeDirectory: String? = nil
    var chromeName: String? = nil
    var firefoxName: String? = nil
    var firefoxAbsPath: String? = nil
    var enabled: Bool = true

    var isPrivate: Bool {
        kind == .chromePrivate || kind == .firefoxPrivate
    }

    var isProfileVariant: Bool {
        kind != .app
    }
}

struct RouteProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var enabled: Bool
    var browserRowID: UUID?
    var patterns: [String]

    var filledPatterns: [String] {
        patterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func adding(host: String) -> RouteProfile {
        var copy = self
        copy.patterns = filledPatterns
        if !copy.patterns.contains(host) {
            copy.patterns.append(host)
        }
        return copy
    }

    var patternSummary: String {
        let filled = filledPatterns
        if filled.isEmpty { return "No URL patterns yet" }
        if filled.count <= 3 { return filled.joined(separator: ", ") }
        return filled.prefix(3).joined(separator: ", ") + " +\(filled.count - 3)"
    }

    static func shipped() -> [RouteProfile] {
        ["Personal", "Work", "Development"].map { name in
            RouteProfile(id: UUID(), name: name, enabled: true, browserRowID: nil, patterns: [""])
        }
    }

    static func blank() -> RouteProfile {
        RouteProfile(id: UUID(), name: "New profile", enabled: true, browserRowID: nil, patterns: [""])
    }
}

struct AppSettings: Codable, Equatable {
    var showMenuBar: Bool = true
    var forcePromptOnModifier: Bool = true
    var openInBackground: Bool = false
    var appearance: AppearanceMode = .system
    var unwrapRedirects = true
    var stripTrackingParams = true
    var promptTimeout: Int = 0
    var onboardingDone = false

    enum CodingKeys: String, CodingKey {
        case showMenuBar, forcePromptOnModifier, openInBackground, appearance
        case unwrapRedirects, stripTrackingParams, promptTimeout, onboardingDone
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showMenuBar) ?? true
        forcePromptOnModifier = try container.decodeIfPresent(Bool.self, forKey: .forcePromptOnModifier) ?? true
        openInBackground = try container.decodeIfPresent(Bool.self, forKey: .openInBackground) ?? false
        appearance = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearance) ?? .system
        unwrapRedirects = try container.decodeIfPresent(Bool.self, forKey: .unwrapRedirects) ?? true
        stripTrackingParams = try container.decodeIfPresent(Bool.self, forKey: .stripTrackingParams) ?? true
        promptTimeout = try container.decodeIfPresent(Int.self, forKey: .promptTimeout) ?? 0
        onboardingDone = try container.decodeIfPresent(Bool.self, forKey: .onboardingDone) ?? false
    }
}

struct RoutedEntry: Codable, Equatable, Identifiable {
    var id: UUID
    var url: URL
    var rowID: UUID
    var title: String
    var date: Date
}

struct PersistedState: Codable {
    static let currentSchemaVersion = 2

    var schemaVersion = currentSchemaVersion
    var browsers: [BrowserRecord]
    var rows: [CatalogRow]
    var rules: [Rule]
    var profiles: [RouteProfile]
    var settings: AppSettings
    var recent: [RoutedEntry]

    init(
        browsers: [BrowserRecord],
        rows: [CatalogRow],
        rules: [Rule],
        profiles: [RouteProfile],
        settings: AppSettings,
        recent: [RoutedEntry] = []
    ) {
        self.browsers = browsers
        self.rows = rows
        self.rules = rules
        self.profiles = profiles
        self.settings = settings
        self.recent = recent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        browsers = try container.decode([BrowserRecord].self, forKey: .browsers)
        rows = try container.decode([CatalogRow].self, forKey: .rows)
        rules = try container.decode([Rule].self, forKey: .rules)
        profiles = try container.decodeIfPresent([RouteProfile].self, forKey: .profiles) ?? RouteProfile.shipped()
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        settings = try container.decode(AppSettings.self, forKey: .settings)
        recent = try container.decodeIfPresent([RoutedEntry].self, forKey: .recent) ?? []
    }
}

struct IncomingLink: Equatable {
    var url: URL
    var sourceBundleID: String? = nil
    var sourceName: String? = nil
    var absoluteString: String { url.absoluteString }
    var host: String { url.host ?? url.absoluteString }
    var isSecure: Bool { url.scheme?.lowercased() == "https" }
    var isFileURL: Bool { url.isFileURL }
}

enum EngineResult: Equatable {
    case favourite
    case bestRunning
    case open([UUID])
    case promptAll
    case promptRunning
    case prompt(ids: [UUID])
}

enum DispatchOutcome: Equatable {
    case opened
    case needsHostQuit(rowID: UUID, browserName: String)
    case failed(String)
}

extension Notification.Name {
    static let linkRouterOpenSettings = Notification.Name("LinkRouterOpenSettings")
    static let linkRouterIncomingURLs = Notification.Name("LinkRouterIncomingURLs")
}
