import AppKit
import Carbon.HIToolbox
import XCTest

@MainActor
final class RoutingTests: XCTestCase {
    final class RecordingDispatcher: Dispatching {
        struct Call {
            let url: URL
            let rowID: UUID
            let browserBundleID: String
        }
        var calls: [Call] = []

        func open(
            url: URL,
            browser: BrowserRecord,
            row: CatalogRow,
            activates: Bool,
            forceNewInstance: Bool,
            completion: @escaping (Error?) -> Void
        ) -> DispatchOutcome {
            calls.append(Call(url: url, rowID: row.id, browserBundleID: browser.bundleIdentifier))
            return .opened
        }
    }

    private var state: AppState!
    private var recorder: RecordingDispatcher!
    private var promptCount = 0
    private var safariBrowser: BrowserRecord!
    private var safariRow: CatalogRow!
    private var chromeBrowser: BrowserRecord!
    private var chromeRow: CatalogRow!

    override func setUp() async throws {
        recorder = RecordingDispatcher()
        state = AppState(dispatcher: recorder)
        state.skipsPersistence = true
        promptCount = 0
        state.onPromptShown = { [self] in self.promptCount += 1 }

        func host(_ bundleID: String, _ name: String, _ path: String) -> BrowserRecord {
            BrowserRecord(id: UUID(), path: path, bundleIdentifier: bundleID, displayName: name)
        }
        let safariPath = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: "com.apple.Safari")?.path ?? "/Applications/Safari.app"
        safariBrowser = host("com.apple.Safari", "Safari", safariPath)
        safariRow = CatalogRow(id: UUID(), browserID: safariBrowser.id, kind: .app)
        chromeBrowser = host("com.google.Chrome", "Chrome", "/Applications/Google Chrome.app")
        chromeRow = CatalogRow(id: UUID(), browserID: chromeBrowser.id, kind: .app)

        state.browsers = [safariBrowser, chromeBrowser]
        state.rows = [safariRow, chromeRow]
        state.rules = []
        state.profiles = []
        state.settings = AppSettings()
        state.recent = []
        state.resume()
    }

    func testImportSettingsKeepsSyncEnabledFromThisMac() throws {
        state.settings.syncEnabled = true
        var importedSettings = state.settings
        importedSettings.syncEnabled = false
        importedSettings.openInBackground = true
        let imported = PersistedState(
            browsers: state.browsers,
            rows: state.rows,
            rules: state.rules,
            profiles: state.profiles,
            settings: importedSettings,
            recent: state.recent
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LinkRouter-import-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Persistence.exportData(imported).write(to: url)

        try state.importSettings(from: url)

        XCTAssertTrue(state.settings.syncEnabled)
        XCTAssertTrue(state.settings.openInBackground)
    }

    private func link(_ string: String) -> URL { URL(string: string)! }

    func testProfileMatchDispatchesToProfileRow() {
        state.profiles = [
            RouteProfile(
                id: UUID(), name: "Work", enabled: true,
                browserRowID: chromeRow.id, patterns: ["github.com"]
            )
        ]
        state.handleIncoming(link("https://github.com/foo"))
        XCTAssertEqual(recorder.calls.map(\.rowID), [chromeRow.id])
    }

    func testOpenBrowsersInOrderPicksFirstAvailable() {
        let ghost = BrowserRecord(
            id: UUID(), path: "/Applications/NoSuchBrowser.app",
            bundleIdentifier: "com.example.missing", displayName: "Ghost"
        )
        let ghostRow = CatalogRow(id: UUID(), browserID: ghost.id, kind: .app)
        state.browsers.append(ghost)
        state.rows.insert(ghostRow, at: 0)
        state.rules = [
            Rule(
                id: UUID(), title: "Docs", enabled: true, combinator: .all,
                conditions: [Condition.url(matcher: .contains, pattern: "example.com")],
                behaviour: Behaviour(kind: .openBrowsersInOrder, rowIDs: [ghostRow.id, chromeRow.id]),
                isFallback: false
            )
        ]
        state.handleIncoming(link("https://example.com/doc"))
        XCTAssertEqual(recorder.calls.map(\.rowID), [chromeRow.id])
    }

    func testPausedRoutesToFavourite() {
        state.pause(for: nil)
        state.handleIncoming(link("https://anything.example"))
        XCTAssertEqual(recorder.calls.map(\.rowID), [safariRow.id])
    }

    func testPausedWithoutAvailableBrowserFallsThroughToPrompt() {
        state.browsers = []
        state.rows = []
        state.pause(for: nil)

        state.handleIncoming(link("https://anything.example"))

        XCTAssertTrue(recorder.calls.isEmpty)
        XCTAssertEqual(promptCount, 1)
    }

    func testCleanedURLIsDispatched() {
        state.rules = [
            Rule(
                id: UUID(), title: "Catch-all", enabled: true, combinator: .all,
                conditions: [], behaviour: .useFavourite, isFallback: true
            )
        ]
        state.handleIncoming(link("https://example.com/p?utm_source=x&keep=1"))
        XCTAssertEqual(recorder.calls.first?.url.absoluteString, "https://example.com/p?keep=1")
    }

    func testMissingBrowserShowsPrompt() {
        state.browsers = []
        state.rows = [safariRow]
        state.handleIncoming(link("https://example.com"))
        XCTAssertEqual(recorder.calls.count, 0)
        XCTAssertEqual(promptCount, 1)
    }

    func testHTMLFileURLReachesLocalHTMLRule() {
        let fileURL = URL(fileURLWithPath: "/tmp/document.html")
        state.rules = [
            Rule(
                id: UUID(),
                title: "HTML",
                enabled: true,
                combinator: .all,
                conditions: [
                    Condition(
                        id: UUID(),
                        kind: .linkType,
                        urlMatcher: .contains,
                        pattern: "",
                        countComparator: .greaterThan,
                        count: 0,
                        linkKind: .localHTML
                    )
                ],
                behaviour: Behaviour(kind: .openBrowser, rowIDs: [safariRow.id]),
                isFallback: false
            )
        ]

        state.handleIncoming(fileURL)

        XCTAssertEqual(recorder.calls.map(\.url), [fileURL])
        XCTAssertEqual(recorder.calls.map(\.rowID), [safariRow.id])
    }
}

final class PRBFeatureTests: XCTestCase {
    func testKeyComboDisplayAndCodable() throws {
        let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_A),
                             carbonModifiers: UInt32(controlKey | optionKey | shiftKey | cmdKey))
        XCTAssertEqual(combo.displayString, "⌃⌥⇧⌘A")
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_F12), carbonModifiers: 0).displayString, "F12")
        XCTAssertNotNil(KeyCombo(keyCode: UInt32(kVK_F12), carbonModifiers: UInt32(cmdKey)).keyboardShortcut)
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_LeftArrow), carbonModifiers: 0).displayString, "←")
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_RightArrow), carbonModifiers: 0).displayString, "→")
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_UpArrow), carbonModifiers: 0).displayString, "↑")
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_DownArrow), carbonModifiers: 0).displayString, "↓")
        let data = try JSONEncoder().encode(combo)
        XCTAssertEqual(try JSONDecoder().decode(KeyCombo.self, from: data), combo)
    }

    func testOldSettingsUseShortcutAndMailDefaults() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertTrue(settings.shortcuts.isEmpty)
        XCTAssertEqual(settings.mail, MailSettings())
    }

    func testFrontmostPageScriptsAndParsing() {
        XCTAssertTrue(FrontmostPage.script(forBundleID: "com.apple.Safari")?.contains("front document") == true)
        XCTAssertTrue(FrontmostPage.script(forBundleID: "com.apple.SafariTechnologyPreview")?.contains("front document") == true)
        XCTAssertTrue(FrontmostPage.script(forBundleID: "com.google.Chrome")?.contains("active tab") == true)
        XCTAssertTrue(FrontmostPage.script(forBundleID: "com.brave.Browser")?.contains("active tab") == true)
        XCTAssertNil(FrontmostPage.script(forBundleID: "org.mozilla.firefox"))
        XCTAssertEqual(FrontmostPage.parseResult("https://example.com"), URL(string: "https://example.com"))
        XCTAssertNil(FrontmostPage.parseResult(""))
        XCTAssertNil(FrontmostPage.parseResult("file:///tmp/page.html"))
        XCTAssertNil(FrontmostPage.parseResult("https://"))
    }

    func testCurrentPagePickerPreservesVariantsAndFallsBack() {
        let browserID = UUID()
        let plain = CatalogRow(id: UUID(), browserID: browserID, kind: .app)
        let profile = CatalogRow(id: UUID(), browserID: browserID, kind: .chromeProfile)
        let privateRow = CatalogRow(id: UUID(), browserID: browserID, kind: .chromePrivate)
        let rows = [plain, profile, privateRow]
        let filtered = FrontmostPage.pickerRows(rows, sourceBundleID: "com.google.Chrome") { _ in "com.google.Chrome" }
        XCTAssertEqual(filtered.map(\.id), [profile.id, privateRow.id])
        XCTAssertEqual(FrontmostPage.pickerRows([plain], sourceBundleID: "com.google.Chrome") { _ in "com.google.Chrome" }, [plain])
    }

    func testMailRoutingDecisions() {
        let ids: Set<String> = ["mail.a", "mail.b"]
        XCTAssertEqual(MailRouting.decide(mode: .ask, favourite: nil, installed: ids,
                                          enabled: ["mail.a", "mail.b"], forcePrompt: false), .prompt(["mail.a", "mail.b"]))
        XCTAssertEqual(MailRouting.decide(mode: .always, favourite: "mail.a", installed: ids,
                                          enabled: ["mail.a", "mail.b"], forcePrompt: false), .open("mail.a"))
        XCTAssertEqual(MailRouting.decide(mode: .always, favourite: "mail.a", installed: ids,
                                          enabled: ["mail.a", "mail.b"], forcePrompt: true), .prompt(["mail.a", "mail.b"]))
        XCTAssertEqual(MailRouting.decide(mode: .always, favourite: "missing", installed: ids,
                                          enabled: ["mail.a"], forcePrompt: false), .prompt(["mail.a"]))
        XCTAssertEqual(MailRouting.decide(mode: .ask, favourite: nil, installed: [], enabled: [], forcePrompt: false), .none)
    }
}

final class AppLinksTests: XCTestCase {
    private let installed = Set(AppLinks.all.flatMap(\.bundleIDs))

    private func match(_ input: String) -> (AppLinkHandler, URL)? {
        AppLinks.match(URL(string: input)!, installed: installed, disabled: [])
    }

    func testBuiltInHandlersMatchAndTransformRepresentativeURLs() {
        let cases: [(String, String, String)] = [
            ("zoom", "https://zoom.us/j/123456?pwd=secret", "zoommtg://zoom.us/join?action=join&confno=123456&pwd=secret"),
            ("zoom", "https://us02web.zoom.us/j/123456", "zoommtg://zoom.us/join?action=join&confno=123456"),
            ("teams", "https://teams.microsoft.com/l/meetup-join/123?tenant=abc", "msteams:/l/meetup-join/123?tenant=abc"),
            ("slack", "https://acme.slack.com/archives/C123/p456", "https://acme.slack.com/archives/C123/p456"),
            ("figma", "https://www.figma.com/design/abc/File", "https://www.figma.com/design/abc/File"),
            ("spotify", "https://open.spotify.com/track/abc?si=123", "spotify:track:abc"),
            ("spotify", "https://open.spotify.com/intl-de/track/abc", "spotify:track:abc"),
            ("notion", "https://www.notion.so/workspace/page?v=123", "notion://www.notion.so/workspace/page?v=123"),
            ("linear", "https://linear.app/acme/issue/ABC-1?view=detail", "linear://acme/issue/ABC-1?view=detail"),
            ("discord", "https://discord.com/channels/123/456", "discord://-/channels/123/456"),
            ("music", "https://music.apple.com/us/album/x/1?i=2", "music://music.apple.com/us/album/x/1?i=2")
        ]

        for (id, input, expected) in cases {
            let result = match(input)
            XCTAssertEqual(result?.0.id, id, input)
            XCTAssertEqual(result?.1.absoluteString, expected, input)
        }
    }

    func testNonMatchingURLsDoNotSelectHandlers() {
        let cases: [(String, String)] = [
            ("zoom", "https://example.com/j/123"),
            ("teams", "https://teams.microsoft.com/meeting/123"),
            ("slack", "https://slack.com/archives/C123"),
            ("figma", "https://figma.com/community/file/123"),
            ("spotify", "https://open.spotify.com/podcast/123"),
            ("notion", "https://example.com/page"),
            ("linear", "https://linear.app/issue/ABC-1"),
            ("discord", "https://discord.com/guilds/123"),
            ("music", "https://music.apple.com.evil.example/us/album/x/1")
        ]

        for (id, input) in cases {
            let result = AppLinks.match(URL(string: input)!, installed: installed, disabled: [])
            XCTAssertNotEqual(result?.0.id, id, input)
        }
    }

    func testUnavailableAndDisabledHandlersAreSkipped() {
        let zoom = URL(string: "https://zoom.us/j/123")!
        XCTAssertNil(AppLinks.match(zoom, installed: [], disabled: []))
        XCTAssertNil(AppLinks.match(zoom, installed: ["us.zoom.xos"], disabled: ["zoom"]))
        XCTAssertEqual(
            AppLinks.match(zoom, installed: ["us.zoom.xos"], disabled: [])?.0.id,
            "zoom"
        )
    }
}

final class RuleOptionsTests: XCTestCase {
    func testOlderRuleDecodesWithDefaultOptions() throws {
        let rule = Rule(
            id: UUID(),
            title: "Legacy",
            enabled: true,
            combinator: .all,
            conditions: [],
            behaviour: .useFavourite,
            isFallback: true,
            options: RuleOptions(background: .always, privateWindow: true)
        )
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(rule)) as? [String: Any]
        )
        object.removeValue(forKey: "options")
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(Rule.self, from: data)

        XCTAssertEqual(decoded.options, RuleOptions())
    }

    func testBackgroundOverridesResolveAgainstGlobalSetting() {
        let cases: [(BackgroundOverride, Bool, Bool)] = [
            (.inherit, false, true),
            (.inherit, true, false),
            (.always, false, false),
            (.always, true, false),
            (.never, false, true),
            (.never, true, true)
        ]

        for (override, global, expectedActivates) in cases {
            XCTAssertEqual(override.activates(openInBackground: global), expectedActivates)
        }
    }

    @MainActor
    func testPrivateVariantReusesSameBrowserAndProfileRow() async throws {
        let state = AppState(dispatcher: RoutingTests.RecordingDispatcher())
        state.skipsPersistence = true
        let chrome = BrowserRecord(
            id: UUID(),
            path: "/Applications/Google Chrome.app",
            bundleIdentifier: "com.google.Chrome",
            displayName: "Chrome"
        )
        let safari = BrowserRecord(
            id: UUID(),
            path: "/Applications/Safari.app",
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        let profile = CatalogRow(
            id: UUID(),
            browserID: chrome.id,
            kind: .chromeProfile,
            chromeDirectory: "Profile 1",
            chromeName: "Work"
        )
        let matchingPrivate = CatalogRow(
            id: UUID(),
            browserID: chrome.id,
            kind: .chromePrivate,
            chromeDirectory: "Profile 1",
            chromeName: "Work"
        )
        let otherProfile = CatalogRow(
            id: UUID(),
            browserID: chrome.id,
            kind: .chromePrivate,
            chromeDirectory: "Profile 2"
        )
        let otherBrowser = CatalogRow(
            id: UUID(),
            browserID: safari.id,
            kind: .chromePrivate,
            chromeDirectory: "Profile 1"
        )
        state.browsers = [chrome, safari]
        state.rows = [profile, otherProfile, otherBrowser, matchingPrivate]

        let mapped = state.privateVariant(for: profile)

        XCTAssertEqual(mapped, matchingPrivate)
    }

    @MainActor
    func testPrivateVariantSynthesizesTransientRows() async throws {
        let state = AppState(dispatcher: RoutingTests.RecordingDispatcher())
        state.skipsPersistence = true
        let chrome = BrowserRecord(
            id: UUID(),
            path: "/Applications/Google Chrome.app",
            bundleIdentifier: "com.google.Chrome",
            displayName: "Chrome"
        )
        let row = CatalogRow(id: UUID(), browserID: chrome.id, kind: .app)
        state.browsers = [chrome]
        state.rows = [row]

        let mapped = state.privateVariant(for: row)

        XCTAssertEqual(mapped.kind, .chromePrivate)
        XCTAssertEqual(mapped.browserID, chrome.id)
        XCTAssertNil(mapped.chromeDirectory)
        XCTAssertNotEqual(mapped.id, row.id)
        XCTAssertEqual(state.rows, [row])
    }
}
