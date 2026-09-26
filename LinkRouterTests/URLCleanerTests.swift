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
