import XCTest

final class BrowserCatalogTests: XCTestCase {
    func testIsBrowserRequiresDeclaredWebSchemes() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }

        func makeApp(_ name: String, schemes: [String]) -> URL {
            let app = base.appendingPathComponent("\(name).app", isDirectory: true)
            let contents = app.appendingPathComponent("Contents", isDirectory: true)
            try! FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            let plist: [String: Any] = [
                "CFBundleIdentifier": "test.\(name)",
                "CFBundleURLTypes": [["CFBundleURLSchemes": schemes]],
            ]
            try! (plist as NSDictionary).write(to: contents.appendingPathComponent("Info.plist"))
            return app
        }

        XCTAssertTrue(BrowserCatalog.isBrowser(makeApp("Web", schemes: ["http", "https"])))
        XCTAssertFalse(BrowserCatalog.isBrowser(makeApp("Chat", schemes: ["chatgpt"])))
        XCTAssertFalse(BrowserCatalog.isBrowser(makeApp("Half", schemes: ["http"])))
        XCTAssertFalse(BrowserCatalog.isBrowser(base.appendingPathComponent("Missing.app")))
    }

    func testAppendDiscoveredSkipsMovedBrowserByBundleID() {
        let safariDiscovered = DefaultBrowser.httpHandlers().contains { $0.lastPathComponent == "Safari.app" }
        guard safariDiscovered else { return }
        var browsers = [
            BrowserRecord(
                id: UUID(),
                path: "/tmp/Moved-Safari.app",
                bundleIdentifier: "com.apple.Safari",
                displayName: "Safari"
            )
        ]
        var rows: [CatalogRow] = []
        BrowserCatalog.appendDiscovered(browsers: &browsers, rows: &rows)
        XCTAssertEqual(
            browsers.filter { $0.bundleIdentifier == "com.apple.Safari" }.count,
            1
        )
    }
}
