import XCTest

final class BrowserCatalogTests: XCTestCase {
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
