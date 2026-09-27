import AppIntents

struct OpenLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Link with LinkRouter"
    static var openAppWhenRun = true

    @Parameter(title: "URL") var url: URL

    init() {}

    init(url: URL) {
        self.url = url
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppState.shared.handleIncoming(url, source: ("app.linkrouter.shortcuts", "Shortcuts"))
        return .result()
    }
}

struct DestinationEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Browser")
    static var defaultQuery = DestinationQuery()

    var id: UUID
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct DestinationQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [DestinationEntity] {
        AppState.shared.enabledRows
            .filter { identifiers.contains($0.id) }
            .map { DestinationEntity(id: $0.id, title: AppState.shared.title(for: $0)) }
    }

    @MainActor
    func suggestedEntities() async throws -> [DestinationEntity] {
        AppState.shared.enabledRows
            .map { DestinationEntity(id: $0.id, title: AppState.shared.title(for: $0)) }
    }
}

struct OpenLinkInBrowserIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Link in a Browser"
    static var openAppWhenRun = true

    @Parameter(title: "URL") var url: URL
    @Parameter(title: "Browser") var destination: DestinationEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        let state = AppState.shared
        guard let row = state.rows.first(where: { $0.id == destination.id }) else {
            return .result()
        }
        state.dispatch(IncomingLink(url: url), row: row)
        return .result()
    }
}

struct LinkRouterShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenLinkIntent(),
            phrases: ["Open \(.applicationName) link"],
            shortTitle: "Open Link",
            systemImageName: "link"
        )
        AppShortcut(
            intent: OpenLinkInBrowserIntent(),
            phrases: ["Open \(.applicationName) link in browser"],
            shortTitle: "Open Link in Browser",
            systemImageName: "safari"
        )
    }
}
