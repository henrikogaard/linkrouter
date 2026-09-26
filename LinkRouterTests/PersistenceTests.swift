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

    func testLegacyFileWithoutVersionDecodesAsOne() throws {
        let state = sampleState()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        json.removeValue(forKey: "schemaVersion")
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(PersistedState.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, 1)
        try data.write(to: Persistence.stateURL)
        guard case .loaded(let loaded) = Persistence.load() else {
            XCTFail("expected loaded")
            return
        }
        XCTAssertEqual(loaded.schemaVersion, PersistedState.currentSchemaVersion)
        Persistence.save(loaded)
        let written = try JSONSerialization.jsonObject(with: Data(contentsOf: Persistence.stateURL)) as! [String: Any]
        XCTAssertEqual(written["schemaVersion"] as? Int, PersistedState.currentSchemaVersion)
    }

    func testNewerFileIsRefused() throws {
        let state = sampleState()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        json["schemaVersion"] = PersistedState.currentSchemaVersion + 1
        try JSONSerialization.data(withJSONObject: json).write(to: Persistence.stateURL)
        guard case .newer(let version) = Persistence.load() else {
            XCTFail("expected newer")
            return
        }
        XCTAssertEqual(version, PersistedState.currentSchemaVersion + 1)
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix("state.newer-") && $0.hasSuffix(".json") }
        XCTAssertEqual(backups.count, 1)
    }

    func testExportImportRoundTrip() throws {
        let state = sampleState()
        let data = try Persistence.exportData(state)
        let imported = try Persistence.importState(from: data)
        XCTAssertEqual(imported.rules, state.rules)
        XCTAssertEqual(imported.profiles, state.profiles)
        XCTAssertEqual(imported.settings, state.settings)
        XCTAssertEqual(imported.browsers, state.browsers)
        XCTAssertEqual(imported.rows, state.rows)
        XCTAssertEqual(imported.recent, [])
    }

    func testImportRejectsNewerVersion() throws {
        var state = sampleState()
        state.schemaVersion = PersistedState.currentSchemaVersion + 1
        let data = try JSONEncoder().encode(state)
        XCTAssertThrowsError(try Persistence.importState(from: data))
    }

    func testLegacyConditionDecodesWithDefaults() throws {
        let json = """
            {"id":"A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D","kind":"url","urlMatcher":"contains","pattern":"github.com","countComparator":"greaterThan","count":0,"linkKind":"website"}
            """.data(using: .utf8)!
        let condition = try JSONDecoder().decode(Condition.self, from: json)
        XCTAssertEqual(condition.startMinute, 540)
        XCTAssertEqual(condition.endMinute, 1020)
        XCTAssertEqual(condition.weekdays, [2, 3, 4, 5, 6])
    }
}
