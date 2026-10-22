import Foundation
import XCTest

final class URLCleanerTests: XCTestCase {
    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    func testStripTrackingKeepsOtherParamsAndFragment() {
        let cleaned = URLCleaner.stripTracking(url("https://a.com/p?utm_source=x&b=1#frag"))
        XCTAssertEqual(cleaned.absoluteString, "https://a.com/p?b=1#frag")
    }

    func testStripTrackingDropsQuestionMarkWhenEmpty() {
        let cleaned = URLCleaner.stripTracking(url("https://a.com/p?utm_source=x"))
        XCTAssertEqual(cleaned.absoluteString, "https://a.com/p")
    }

    func testNoQueryUntouched() {
        let input = url("https://a.com/p#frag")
        XCTAssertEqual(URLCleaner.stripTracking(input), input)
    }

    func testOutlookSafelinksUnwrap() {
        let cleaned = URLCleaner.unwrapRedirect(
            url("https://nam12.safelinks.protection.outlook.com/?url=https%3A%2F%2Fexample.com%2Fx%3Fa%3D1&data=02")
        )
        XCTAssertEqual(cleaned.absoluteString, "https://example.com/x?a=1")
    }

    func testGoogleUrlUnwrap() {
        let cleaned = URLCleaner.unwrapRedirect(url("https://www.google.com/url?q=https://example.com/y&sa=D"))
        XCTAssertEqual(cleaned.absoluteString, "https://example.com/y")
    }

    func testUnknownHostNotUnwrapped() {
        let input = url("https://example.com/?url=https://evil.com")
        XCTAssertEqual(URLCleaner.unwrapRedirect(input), input)
    }

    func testUnwrapThenStrip() {
        let cleaned = URLCleaner.clean(
            url("https://www.google.com/url?q=https%3A%2F%2Fex.com%2Fp%3Futm_source%3Dx%26k%3D1"),
            unwrap: true,
            strip: true
        )
        XCTAssertEqual(cleaned.absoluteString, "https://ex.com/p?k=1")
    }

    func testFacebookLphpUnwrap() {
        let cleaned = URLCleaner.unwrapRedirect(
            url("https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com%2Fz&h=abc")
        )
        XCTAssertEqual(cleaned.absoluteString, "https://example.com/z")
    }
}

final class ShortLinkExpanderTests: XCTestCase {
    private func url(_ string: String) -> URL { URL(string: string)! }

    override func tearDown() {
        RedirectStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testSupportedShortLinkHosts() {
        for host in ShortLinkExpander.hosts {
            XCTAssertTrue(ShortLinkExpander.isShortLink(url("https://\(host)/x")), host)
        }
        XCTAssertFalse(ShortLinkExpander.isShortLink(url("https://example.com/x")))
        XCTAssertFalse(ShortLinkExpander.isShortLink(url("https://notbit.ly.example/x")))
    }

    func testExpansionFollowsTwoRedirects() async {
        var requests: [String] = []
        RedirectStubURLProtocol.handler = { request in
            requests.append("\(request.httpMethod ?? "") \(request.url!.absoluteString)")
            if request.url?.host == "t.co" {
                return Self.response(request, status: 302, headers: ["Location": "https://bit.ly/second"])
            }
            return Self.response(request, status: 302, headers: ["Location": "https://example.com/final"])
        }
        let expander = ShortLinkExpander(session: Self.stubSession())

        let result = await expander.expand(url("https://t.co/start"))

        XCTAssertEqual(result.absoluteString, "https://example.com/final")
        XCTAssertEqual(requests, [
            "HEAD https://t.co/start",
            "HEAD https://bit.ly/second"
        ])
    }

    func testNonHTTPRedirectTargetReturnsOriginal() async {
        RedirectStubURLProtocol.handler = { request in
            Self.response(request, status: 302, headers: ["Location": "mailto:someone@example.com"])
        }
        let original = url("https://t.co/start")
        let result = await ShortLinkExpander(session: Self.stubSession()).expand(original)
        XCTAssertEqual(result, original)
    }

    func testTimeoutFailureReturnsOriginal() async {
        RedirectStubURLProtocol.handler = { _ in throw URLError(.timedOut) }
        let original = url("https://t.co/start")
        let result = await ShortLinkExpander(session: Self.stubSession()).expand(original)
        XCTAssertEqual(result, original)
    }

    private static func stubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RedirectStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func response(
        _ request: URLRequest,
        status: Int,
        headers: [String: String]
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!,
            Data()
        )
    }
}

final class LinkFileParserTests: XCTestCase {
    func testWeblocAndInternetShortcutURLs() throws {
        let webData = try PropertyListSerialization.data(
            fromPropertyList: ["URL": "https://example.com/web"],
            format: .xml,
            options: 0
        )
        XCTAssertEqual(
            LinkFileParser.webLocationURL(from: webData)?.absoluteString,
            "https://example.com/web"
        )

        let shortcut = Data("[InternetShortcut]\r\nURL=https://example.com/windows\r\n".utf8)
        XCTAssertEqual(
            LinkFileParser.internetShortcutURL(from: shortcut)?.absoluteString,
            "https://example.com/windows"
        )
    }

    func testMalformedShortcutFilesReturnNil() throws {
        XCTAssertNil(LinkFileParser.webLocationURL(from: Data("not a plist".utf8)))
        XCTAssertNil(LinkFileParser.webLocationURL(from: try PropertyListSerialization.data(
            fromPropertyList: ["URL": "file:///tmp/secret"],
            format: .xml,
            options: 0
        )))
        XCTAssertNil(LinkFileParser.internetShortcutURL(from: Data("[InternetShortcut]\nURL=not a URL".utf8)))
        XCTAssertNil(LinkFileParser.internetShortcutURL(from: Data("[InternetShortcut]\n".utf8)))
    }
}

private final class RedirectStubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !data.isEmpty {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
