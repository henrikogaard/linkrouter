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
        case url, runningCount, linkType, sourceApp, schedule, focus, wifi, vpn
        var id: String { rawValue }
        var label: String {
            switch self {
            case .url: String(localized: "Web address")
            case .runningCount: String(localized: "Running browsers")
            case .linkType: String(localized: "Link type")
            case .sourceApp: String(localized: "Sent from app")
            case .schedule: String(localized: "Time of day")
            case .focus: String(localized: "Focus mode")
            case .wifi: String(localized: "Wi-Fi network")
            case .vpn: String(localized: "VPN")
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
    var vpnConnected = true

    private enum CodingKeys: String, CodingKey {
        case id, kind, urlMatcher, pattern, countComparator, count, linkKind
        case startMinute, endMinute, weekdays, vpnConnected
    }

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

    static func focus(matcher: URLMatcher = .is, mode: String = "") -> Condition {
        Condition(
            id: UUID(),
            kind: .focus,
            urlMatcher: matcher,
            pattern: mode,
            countComparator: .greaterThan,
            count: 0,
            linkKind: .website
        )
    }

    static func wifi(matcher: URLMatcher = .is, ssid: String = "") -> Condition {
        Condition(
            id: UUID(),
            kind: .wifi,
            urlMatcher: matcher,
            pattern: ssid,
            countComparator: .greaterThan,
            count: 0,
            linkKind: .website
        )
    }

    static func vpn(connected: Bool = true) -> Condition {
        Condition(
            id: UUID(),
            kind: .vpn,
            urlMatcher: .contains,
            pattern: "",
            countComparator: .greaterThan,
            count: 0,
            linkKind: .website,
            vpnConnected: connected
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
        vpnConnected = try container.decodeIfPresent(Bool.self, forKey: .vpnConnected) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(urlMatcher, forKey: .urlMatcher)
        try container.encode(pattern, forKey: .pattern)
        try container.encode(countComparator, forKey: .countComparator)
        try container.encode(count, forKey: .count)
        try container.encode(linkKind, forKey: .linkKind)
        try container.encode(startMinute, forKey: .startMinute)
        try container.encode(endMinute, forKey: .endMinute)
        try container.encode(weekdays.sorted(), forKey: .weekdays)
        try container.encode(vpnConnected, forKey: .vpnConnected)
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

enum BackgroundOverride: String, Codable, CaseIterable {
    case inherit
    case always
    case never

    func activates(openInBackground: Bool) -> Bool {
        let background = switch self {
        case .inherit: openInBackground
        case .always: true
        case .never: false
        }
        return !background
    }
}

struct RuleOptions: Codable, Equatable {
    var background: BackgroundOverride = .inherit
    var privateWindow = false
}

struct Rule: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var enabled: Bool
    var combinator: Combinator
    var conditions: [Condition]
    var behaviour: Behaviour
    var isFallback: Bool
    var options: RuleOptions = .init()

    private enum CodingKeys: String, CodingKey {
        case id, title, enabled, combinator, conditions, behaviour, isFallback, options
    }

    init(
        id: UUID,
        title: String,
        enabled: Bool,
        combinator: Combinator,
        conditions: [Condition],
        behaviour: Behaviour,
        isFallback: Bool,
        options: RuleOptions = .init()
    ) {
        self.id = id
        self.title = title
        self.enabled = enabled
        self.combinator = combinator
        self.conditions = conditions
        self.behaviour = behaviour
        self.isFallback = isFallback
        self.options = options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        combinator = try container.decode(Combinator.self, forKey: .combinator)
        conditions = try container.decode([Condition].self, forKey: .conditions)
        behaviour = try container.decode(Behaviour.self, forKey: .behaviour)
        isFallback = try container.decode(Bool.self, forKey: .isFallback)
        options = try container.decodeIfPresent(RuleOptions.self, forKey: .options) ?? .init()
    }

    var displayTitle: String {
        isFallback ? String(localized: "Everything else") : title
    }

    static func shipped() -> [Rule] {
        [
            Rule(
                id: UUID(),
                title: String(localized: "Some browsers are running"),
                enabled: true,
                combinator: .all,
                conditions: [.runningCount(.greaterThan, 0)],
                behaviour: .promptRunning,
                isFallback: false
            ),
            Rule(
                id: UUID(),
                title: String(localized: "Everything else"),
                enabled: true,
                combinator: .all,
                conditions: [],
                behaviour: .useFavourite,
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
        if filled.isEmpty { return String(localized: "No URL patterns yet") }
        if filled.count <= 3 { return filled.joined(separator: ", ") }
        return filled.prefix(3).joined(separator: ", ") + " +\(filled.count - 3)"
    }

    static func shipped() -> [RouteProfile] {
        [
            String(localized: "Personal"),
            String(localized: "Work"),
            String(localized: "Development")
        ].map { name in
            RouteProfile(id: UUID(), name: name, enabled: true, browserRowID: nil, patterns: [""])
        }
    }

    static func blank() -> RouteProfile {
        RouteProfile(id: UUID(), name: String(localized: "New profile"), enabled: true, browserRowID: nil, patterns: [""])
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
    var appLinksDisabled: Set<String> = []
    var expandShortLinks = true
    var shortcuts: [ShortcutAction: KeyCombo] = [:]
    var mail = MailSettings()
    var syncEnabled = false

    enum CodingKeys: String, CodingKey {
        case showMenuBar, forcePromptOnModifier, openInBackground, appearance
        case unwrapRedirects, stripTrackingParams, promptTimeout, onboardingDone, appLinksDisabled, expandShortLinks
        case shortcuts, mail, syncEnabled
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
        appLinksDisabled = try container.decodeIfPresent(Set<String>.self, forKey: .appLinksDisabled) ?? []
        expandShortLinks = try container.decodeIfPresent(Bool.self, forKey: .expandShortLinks) ?? true
        shortcuts = try container.decodeIfPresent([ShortcutAction: KeyCombo].self, forKey: .shortcuts) ?? [:]
        mail = try container.decodeIfPresent(MailSettings.self, forKey: .mail) ?? MailSettings()
        syncEnabled = try container.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let isSyncPayload = encoder.userInfo[.linkRouterSyncPayload] as? Bool == true

        try container.encode(forcePromptOnModifier, forKey: .forcePromptOnModifier)
        try container.encode(openInBackground, forKey: .openInBackground)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(unwrapRedirects, forKey: .unwrapRedirects)
        try container.encode(stripTrackingParams, forKey: .stripTrackingParams)
        try container.encode(promptTimeout, forKey: .promptTimeout)
        try container.encode(appLinksDisabled.sorted(), forKey: .appLinksDisabled)
        try container.encode(expandShortLinks, forKey: .expandShortLinks)
        try container.encode(mail, forKey: .mail)

        if !isSyncPayload {
            try container.encode(showMenuBar, forKey: .showMenuBar)
            try container.encode(onboardingDone, forKey: .onboardingDone)
            try container.encode(shortcuts, forKey: .shortcuts)
            try container.encode(syncEnabled, forKey: .syncEnabled)
        }
    }
}

extension CodingUserInfoKey {
    static let linkRouterSyncPayload = CodingUserInfoKey(rawValue: "LinkRouterSyncPayload")!
}

enum MailMode: String, Codable, CaseIterable {
    case ask, always
}

struct MailSettings: Codable, Equatable {
    var mode: MailMode = .ask
    var favouriteBundleID: String?
    var order: [String] = []
    var disabled: Set<String> = []

    private enum CodingKeys: String, CodingKey {
        case mode, favouriteBundleID, order, disabled
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(favouriteBundleID, forKey: .favouriteBundleID)
        try container.encode(order, forKey: .order)
        try container.encode(disabled.sorted(), forKey: .disabled)
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
    var modifiedAt: Date?
    var deviceID: String?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, browsers, rows, rules, profiles, settings, recent, modifiedAt, deviceID
    }

    init(
        browsers: [BrowserRecord],
        rows: [CatalogRow],
        rules: [Rule],
        profiles: [RouteProfile],
        settings: AppSettings,
        recent: [RoutedEntry] = [],
        modifiedAt: Date? = nil,
        deviceID: String? = nil
    ) {
        self.browsers = browsers
        self.rows = rows
        self.rules = rules
        self.profiles = profiles
        self.settings = settings
        self.recent = recent
        self.modifiedAt = modifiedAt
        self.deviceID = deviceID
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
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt)
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let isSyncPayload = encoder.userInfo[.linkRouterSyncPayload] as? Bool == true

        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(browsers, forKey: .browsers)
        try container.encode(rows, forKey: .rows)
        try container.encode(rules, forKey: .rules)
        try container.encode(profiles, forKey: .profiles)
        try container.encode(settings, forKey: .settings)

        if isSyncPayload {
            guard let modifiedAt, let deviceID else {
                throw EncodingError.invalidValue(
                    self,
                    EncodingError.Context(
                        codingPath: encoder.codingPath,
                        debugDescription: "Sync payload requires modifiedAt and deviceID."
                    )
                )
            }
            try container.encode(modifiedAt, forKey: .modifiedAt)
            try container.encode(deviceID, forKey: .deviceID)
        } else {
            try container.encode(recent, forKey: .recent)
            try container.encodeIfPresent(modifiedAt, forKey: .modifiedAt)
            try container.encodeIfPresent(deviceID, forKey: .deviceID)
        }
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
