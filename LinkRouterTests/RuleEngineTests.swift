import XCTest

final class RuleEngineTests: XCTestCase {
    private func link(_ string: String) -> IncomingLink {
        IncomingLink(url: URL(string: string)!)
    }

    func testContainsMatch() {
        XCTAssertTrue(RuleEngine.urlMatches("https://github.com/org", matcher: .contains, pattern: "github.com"))
        XCTAssertFalse(RuleEngine.urlMatches("https://example.com", matcher: .contains, pattern: "github.com"))
    }

    func testLikeGlobEscapesMetacharacters() {
        XCTAssertTrue(RuleEngine.likeMatches("https://a.b/x", pattern: "https://*.b/*"))
        XCTAssertFalse(RuleEngine.likeMatches("https://a.b/x", pattern: "https://*.c/*"))
        XCTAssertTrue(RuleEngine.likeMatches("https://x.com/a+b", pattern: "https://x.com/a+b"))
    }

    func testRegexAnchorsWhenMissing() {
        XCTAssertTrue(RuleEngine.regexMatches("https://ok.test/x", pattern: "https://ok\\.test/.*"))
        XCTAssertFalse(RuleEngine.regexMatches("https://ok.test/x", pattern: "ok\\.test"))
    }

    func testFirstMatchWins() {
        var github = Rule.shipped()[0]
        github.title = "GitHub"
        github.conditions = [.url(matcher: .contains, pattern: "github.com")]
        github.behaviour = Behaviour(kind: .openBrowser, rowIDs: [UUID()])
        github.isFallback = false

        let fallback = Rule.shipped()[1]
        let rules = [github, fallback]
        let result = RuleEngine.evaluate(
            link: link("https://github.com/x"),
            rules: rules,
            runningCount: 0,
            modifierForcePrompt: false
        )
        if case .open(let ids) = result {
            XCTAssertEqual(ids, github.behaviour.rowIDs)
        } else {
            XCTFail("expected open, got \(result)")
        }
    }

    func testFallbackWhenNothingMatches() {
        let rules = Rule.shipped()
        let result = RuleEngine.evaluate(
            link: link("https://example.com"),
            rules: rules,
            runningCount: 0,
            modifierForcePrompt: false
        )
        XCTAssertEqual(result, .promptAll)
    }

    func testRunningCountPrompt() {
        let rules = Rule.shipped()
        let result = RuleEngine.evaluate(
            link: link("https://example.com"),
            rules: rules,
            runningCount: 2,
            modifierForcePrompt: false
        )
        XCTAssertEqual(result, .promptRunning)
    }

    func testModifierForcePrompt() {
        let rules = Rule.shipped()
        let result = RuleEngine.evaluate(
            link: link("https://github.com"),
            rules: rules,
            runningCount: 2,
            modifierForcePrompt: true
        )
        XCTAssertEqual(result, .promptAll)
    }

    func testInvalidRegexDoesNotMatch() {
        XCTAssertFalse(RuleEngine.regexMatches("https://x.com", pattern: "("))
    }

    func testHostPatternMatchesSubdomains() {
        let github = link("https://gist.github.com/x")
        XCTAssertTrue(RuleEngine.hostPattern("github.com", matches: github))
        XCTAssertTrue(RuleEngine.hostPattern("gist.github.com", matches: github))
        XCTAssertFalse(RuleEngine.hostPattern("gitlab.com", matches: github))
        XCTAssertTrue(RuleEngine.hostPattern("https://gist.github.com", matches: github))
    }

    func testProfileBeatsRules() {
        let rowID = UUID()
        let profile = RouteProfile(
            id: UUID(),
            name: "Work",
            enabled: true,
            browserRowID: rowID,
            patterns: ["github.com"]
        )
        var github = Rule.shipped()[0]
        github.conditions = [.url(matcher: .contains, pattern: "github.com")]
        github.behaviour = Behaviour(kind: .promptAll, rowIDs: [])
        github.isFallback = false
        let result = RuleEngine.evaluate(
            link: link("https://github.com/org/repo"),
            profiles: [profile],
            rules: [github, Rule.shipped()[1]],
            runningCount: 0,
            modifierForcePrompt: false
        )
        XCTAssertEqual(result, .open([rowID]))
    }

    func testDisabledProfileIsSkipped() {
        let profile = RouteProfile(
            id: UUID(),
            name: "Work",
            enabled: false,
            browserRowID: UUID(),
            patterns: ["github.com"]
        )
        let result = RuleEngine.evaluate(
            link: link("https://github.com/x"),
            profiles: [profile],
            rules: Rule.shipped(),
            runningCount: 0,
            modifierForcePrompt: false
        )
        XCTAssertEqual(result, .promptAll)
    }
}
