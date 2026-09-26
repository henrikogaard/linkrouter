import AppKit
import XCTest

final class DispatcherTests: XCTestCase {
    private let url = URL(string: "https://example.com/x")!
    private let browser = BrowserRecord(
        id: UUID(),
        path: "/Applications/Chrome.app",
        bundleIdentifier: "com.google.Chrome",
        displayName: "Chrome"
    )

    private func row(kind: RowKind, chromeDirectory: String? = nil, firefoxAbsPath: String? = nil) -> CatalogRow {
        CatalogRow(
            id: UUID(),
            browserID: browser.id,
            kind: kind,
            chromeDirectory: chromeDirectory,
            firefoxAbsPath: firefoxAbsPath
        )
    }

    func testChromeProfileArgv() {
        let args = Dispatcher.argv(url: url, browser: browser, row: row(kind: .chromeProfile, chromeDirectory: "Profile 1"), running: false)
        XCTAssertEqual(args, ["--profile-directory=Profile 1", "https://example.com/x"])
    }

    func testChromePrivateArgv() {
        let withDir = Dispatcher.argv(url: url, browser: browser, row: row(kind: .chromePrivate, chromeDirectory: "Profile 1"), running: false)
        XCTAssertEqual(withDir, ["--profile-directory=Profile 1", "--incognito", "https://example.com/x"])
        let withoutDir = Dispatcher.argv(url: url, browser: browser, row: row(kind: .chromePrivate), running: false)
        XCTAssertEqual(withoutDir, ["--incognito", "https://example.com/x"])
    }

    func testFirefoxProfileArgv() {
        let args = Dispatcher.argv(url: url, browser: browser, row: row(kind: .firefoxProfile, firefoxAbsPath: "/x/Profiles/abc"), running: false)
        XCTAssertEqual(args, ["--profile", "/x/Profiles/abc", "https://example.com/x"])
    }

    func testFirefoxPrivateArgv() {
        let withPath = Dispatcher.argv(url: url, browser: browser, row: row(kind: .firefoxPrivate, firefoxAbsPath: "/x/Profiles/abc"), running: false)
        XCTAssertEqual(withPath, ["--profile", "/x/Profiles/abc", "--private-window", "https://example.com/x"])
        let withoutPath = Dispatcher.argv(url: url, browser: browser, row: row(kind: .firefoxPrivate), running: false)
        XCTAssertEqual(withoutPath, ["--private-window", "https://example.com/x"])
    }

    func testPlainAppReturnsNil() {
        XCTAssertNil(Dispatcher.argv(url: url, browser: browser, row: row(kind: .app), running: false))
    }

    func testRunningChromeProfileStillYieldsArgs() {
        let args = Dispatcher.argv(url: url, browser: browser, row: row(kind: .chromeProfile, chromeDirectory: "Profile 1"), running: true)
        XCTAssertEqual(args, ["--profile-directory=Profile 1", "https://example.com/x"])
    }

    func testRunningFirefoxProfileGetsNewInstance() {
        let args = Dispatcher.argv(url: url, browser: browser, row: row(kind: .firefoxProfile, firefoxAbsPath: "/x/Profiles/abc"), running: true)
        XCTAssertEqual(args, ["--new-instance", "--profile", "/x/Profiles/abc", "https://example.com/x"])
    }

    func testExecutableURLResolvesBundle() {
        guard let safariURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") else { return }
        let safari = BrowserRecord(
            id: UUID(),
            path: safariURL.path,
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        XCTAssertEqual(
            Dispatcher.executableURL(for: safari)?.path,
            safariURL.appendingPathComponent("Contents/MacOS/Safari").path
        )
    }

    func testEdgePrivateUsesInPrivateFlag() {
        let edge = BrowserRecord(
            id: UUID(),
            path: "/Applications/Microsoft Edge.app",
            bundleIdentifier: "com.microsoft.edgemac",
            displayName: "Microsoft Edge"
        )
        let args = Dispatcher.argv(url: url, browser: edge, row: row(kind: .chromePrivate), running: false)
        XCTAssertEqual(args, ["--inprivate", "https://example.com/x"])
    }

    func testRunningAppReturnsNil() {
        XCTAssertNil(Dispatcher.argv(url: url, browser: browser, row: row(kind: .app), running: true))
    }
}
