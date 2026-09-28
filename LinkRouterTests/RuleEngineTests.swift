import XCTest

final class RuleEngineTests: XCTestCase {
    private func link(_ string: String) -> IncomingLink {
        IncomingLink(url: URL(string: string)!)
    }

    func testContainsMatch() {
        XCTAssertTrue(RuleEngine.urlMatches("https://github.com/org", matcher: .contains, pattern: "github.com"))
        XCTAssertFalse(RuleEngine.urlMatches("https://example.com", matcher: .contains, pattern: "github.com"))
    }

    func testCaseInsensitiveMatching() {
        XCTAssertTrue(RuleEngine.urlMatches("https://GitHub.com/x", matcher: .is, pattern: "https://github.com/x"))
        XCTAssertTrue(RuleEngine.urlMatches("https://GITHUB.com/x", matcher: .contains, pattern: "github.com"))
        XCTAssertFalse(RuleEngine.urlMatches("https://github.com", matcher: .isNot, pattern: "https://GITHUB.com"))
        XCTAssertTrue(RuleEngine.likeMatches("https://A.B/x", pattern: "https://*.b/*"))
        XCTAssertFalse(RuleEngine.regexMatches("https://OK.test", pattern: "ok\\.test"))
    }

    func testEmptyPatternDoesNotMatch() {
        XCTAssertFalse(RuleEngine.urlMatches("https://github.com", matcher: .contains, pattern: ""))
        XCTAssertFalse(RuleEngine.urlMatches("https://github.com", matcher: .beginsWith, pattern: ""))
        XCTAssertFalse(RuleEngine.urlMatches("https://github.com", matcher: .endsWith, pattern: ""))
        XCTAssertFalse(RuleEngine.likeMatches("https://github.com", pattern: ""))
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
        XCTAssertEqual(result, .favourite)
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

    func testExplainReportsSources() {
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
        let fallback = Rule.shipped()[1]
        let rules = [github, fallback]

        let profileHit = RuleEngine.explain(
            link: link("https://github.com/x"),
            profiles: [profile],
            rules: rules,
            runningCount: 0,
            modifierForcePrompt: false
        )
        XCTAssertEqual(profileHit.source, .profile(profile.id))
        XCTAssertEqual(profileHit.result, .open([rowID]))

        let ruleHit = RuleEngine.explain(
            link: link("https://github.com/x"),
            profiles: [],
            rules: rules,
            runningCount: 0,
            modifierForcePrompt: false
        )
        XCTAssertEqual(ruleHit.source, .rule(github.id))

        let fallbackHit = RuleEngine.explain(
            link: link("https://example.com"),
            profiles: [],
            rules: rules,
            runningCount: 0,
            modifierForcePrompt: false
        )
        XCTAssertEqual(fallbackHit.source, .fallback(fallback.id))

        let modifierHit = RuleEngine.explain(
            link: link("https://github.com/x"),
            profiles: [profile],
            rules: rules,
            runningCount: 0,
            modifierForcePrompt: true
        )
        XCTAssertEqual(modifierHit.source, .modifier)
        XCTAssertEqual(modifierHit.result, .promptAll)
    }

    func testProfileAddingHostDedupes() {
        var profile = RouteProfile(id: UUID(), name: "Work", enabled: true, browserRowID: UUID(), patterns: [""])
        profile = profile.adding(host: "github.com")
        XCTAssertEqual(profile.patterns, ["github.com"])
        profile = profile.adding(host: "github.com")
        XCTAssertEqual(profile.patterns, ["github.com"])
        profile = profile.adding(host: "example.com")
        XCTAssertEqual(profile.patterns, ["github.com", "example.com"])
    }

    func testSourceAppCondition() {
        let condition = Condition(
            id: UUID(),
            kind: .sourceApp,
            urlMatcher: .is,
            pattern: "com.tinyspeck.slackmacgap",
            countComparator: .greaterThan,
            count: 0,
            linkKind: .website
        )
        let fromSlack = IncomingLink(
            url: URL(string: "https://example.com")!,
            sourceBundleID: "com.tinyspeck.slackmacgap",
            sourceName: "Slack"
        )
        let noSource = link("https://example.com")
        XCTAssertTrue(RuleEngine.conditionMatches(condition, link: fromSlack, runningCount: 0))
        XCTAssertFalse(RuleEngine.conditionMatches(condition, link: noSource, runningCount: 0))
    }

    func testScheduleCondition() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        func at(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(year: 2024, month: 1, day: day, hour: hour, minute: minute))!
        }
        func schedule(_ start: Int, _ end: Int, _ days: Set<Int>) -> Condition {
            Condition(
                id: UUID(),
                kind: .schedule,
                urlMatcher: .contains,
                pattern: "",
                countComparator: .greaterThan,
                count: 0,
                linkKind: .website,
                startMinute: start,
                endMinute: end,
                weekdays: days
            )
        }
        let link = link("https://example.com")
        let workHours = schedule(540, 1020, [2, 3, 4, 5, 6])

        // 2024-01-01 is a Monday
        XCTAssertTrue(RuleEngine.conditionMatches(workHours, link: link, runningCount: 0, now: at(1, 10, 0), calendar: calendar))
        XCTAssertFalse(RuleEngine.conditionMatches(workHours, link: link, runningCount: 0, now: at(1, 22, 0), calendar: calendar))
        XCTAssertFalse(RuleEngine.conditionMatches(workHours, link: link, runningCount: 0, now: at(1, 17, 0), calendar: calendar))

        let overnight = schedule(1320, 360, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertTrue(RuleEngine.conditionMatches(overnight, link: link, runningCount: 0, now: at(1, 23, 0), calendar: calendar))
        XCTAssertTrue(RuleEngine.conditionMatches(overnight, link: link, runningCount: 0, now: at(1, 2, 0), calendar: calendar))
        XCTAssertFalse(RuleEngine.conditionMatches(overnight, link: link, runningCount: 0, now: at(1, 12, 0), calendar: calendar))

        let mondayOnly = schedule(540, 1020, [2])
        XCTAssertTrue(RuleEngine.conditionMatches(mondayOnly, link: link, runningCount: 0, now: at(1, 10, 0), calendar: calendar))
        XCTAssertFalse(RuleEngine.conditionMatches(mondayOnly, link: link, runningCount: 0, now: at(2, 10, 0), calendar: calendar))
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
        XCTAssertEqual(result, .favourite)
    }
}
