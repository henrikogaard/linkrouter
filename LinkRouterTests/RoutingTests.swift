import AppKit
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
}
