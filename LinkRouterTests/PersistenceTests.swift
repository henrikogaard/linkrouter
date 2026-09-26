import XCTest

final class PersistenceTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LinkRouterTests-\(UUID().uuidString)", isDirectory: true)
        Persistence.directoryOverride = dir
    }

    override func tearDown() {
        Persistence.directoryOverride = nil
        try? FileManager.default.removeItem(at: dir)
        dir = nil
        super.tearDown()
    }

    private func sampleState() -> PersistedState {
        let browser = BrowserRecord(id: UUID(), path: "/Applications/Chrome.app", bundleIdentifier: "com.google.Chrome", displayName: "Chrome")
        let row = CatalogRow(id: UUID(), browserID: browser.id, kind: .app)
        let entry = RoutedEntry(id: UUID(), url: URL(string: "https://example.com/x")!, rowID: row.id, title: "Chrome", date: Date())
        return PersistedState(
            browsers: [browser],
            rows: [row],
            rules: Rule.shipped(),
            profiles: RouteProfile.shipped(),
            settings: AppSettings(),
            recent: [entry]
        )
    }

    func testRoundTrip() {
        let state = sampleState()
        Persistence.save(state)
        guard case .loaded(let loaded) = Persistence.load() else {
            XCTFail("expected loaded")
            return
        }
        XCTAssertEqual(loaded.browsers, state.browsers)
        XCTAssertEqual(loaded.rows, state.rows)
        XCTAssertEqual(loaded.rules, state.rules)
        XCTAssertEqual(loaded.profiles, state.profiles)
        XCTAssertEqual(loaded.settings, state.settings)
        XCTAssertEqual(loaded.recent, state.recent)
    }

    func testLegacyStateDecodesWithDefaults() {
        let browser = BrowserRecord(id: UUID(), path: "/Applications/Chrome.app", bundleIdentifier: "com.google.Chrome", displayName: "Chrome")
        let row = CatalogRow(id: UUID(), browserID: browser.id, kind: .app)
        let legacy: [String: Any] = [
            "browsers": [["id": browser.id.uuidString, "path": browser.path, "bundleIdentifier": browser.bundleIdentifier, "displayName": browser.displayName]],
            "rows": [["id": row.id.uuidString, "browserID": row.browserID.uuidString, "kind": "app", "enabled": true]],
            "rules": [["id": UUID().uuidString, "title": "Fallback", "enabled": true, "combinator": "all", "conditions": [], "behaviour": ["kind": "promptAll", "rowIDs": []], "isFallback": true]],
            "settings": ["forcePromptOnModifier": true, "openInBackground": false],
        ]
        let data = try! JSONSerialization.data(withJSONObject: legacy)
        try! data.write(to: Persistence.stateURL)
        guard case .loaded(let loaded) = Persistence.load() else {
            XCTFail("expected loaded")
            return
        }
        XCTAssertEqual(loaded.profiles.map(\.name), ["Personal", "Work", "Development"])
        XCTAssertEqual(loaded.settings.appearance, .system)
        XCTAssertTrue(loaded.settings.showMenuBar)
        XCTAssertEqual(loaded.browsers, [browser])
        XCTAssertEqual(loaded.rows, [row])
        XCTAssertEqual(loaded.recent, [])
    }

    func testCorruptStateIsCopiedAside() {
        try! Data("not json at all".utf8).write(to: Persistence.stateURL)
        guard case .corrupt = Persistence.load() else {
            XCTFail("expected corrupt")
            return
        }
        let backups = try! FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("state.corrupt-") && $0.hasSuffix(".json") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: Persistence.stateURL.path))
    }

    func testMissingState() {
        guard case .missing = Persistence.load() else {
            XCTFail("expected missing")
            return
        }
    }
}
