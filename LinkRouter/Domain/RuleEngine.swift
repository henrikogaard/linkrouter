import Foundation

enum MatchSource: Equatable {
    case modifier
    case profile(UUID)
    case rule(UUID)
    case fallback(UUID)
    case none
}

struct Explanation: Equatable {
    var source: MatchSource
    var result: EngineResult
}

enum RuleEngine {
    static func evaluate(
        link: IncomingLink,
        profiles: [RouteProfile] = [],
        rules: [Rule],
        runningCount: Int,
        modifierForcePrompt: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> EngineResult {
        explain(
            link: link,
            profiles: profiles,
            rules: rules,
            runningCount: runningCount,
            modifierForcePrompt: modifierForcePrompt,
            now: now,
            calendar: calendar
        ).result
    }

    static func explain(
        link: IncomingLink,
        profiles: [RouteProfile] = [],
        rules: [Rule],
        runningCount: Int,
        modifierForcePrompt: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Explanation {
        if modifierForcePrompt {
            return Explanation(source: .modifier, result: .promptAll)
        }

        if let profile = matchProfile(profiles, link: link), let rowID = profile.browserRowID {
            return Explanation(source: .profile(profile.id), result: .open([rowID]))
        }

        let enabled = rules.filter(\.enabled)
        let fallback = enabled.last(where: \.isFallback) ?? enabled.last

        for rule in enabled where !rule.isFallback {
            if matches(rule, link: link, runningCount: runningCount, now: now, calendar: calendar) {
                return Explanation(
                    source: .rule(rule.id),
                    result: result(for: rule.behaviour, fallback: fallback)
                )
            }
        }

        if let fallback, matches(fallback, link: link, runningCount: runningCount, now: now, calendar: calendar) || fallback.conditions.isEmpty {
            return Explanation(
                source: .fallback(fallback.id),
                result: result(for: fallback.behaviour, fallback: nil)
            )
        }

        return Explanation(source: .none, result: .promptAll)
    }

    static func matches(
        _ rule: Rule,
        link: IncomingLink,
        runningCount: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        if rule.conditions.isEmpty {
            return rule.isFallback
        }
        let bits = rule.conditions.map {
            conditionMatches($0, link: link, runningCount: runningCount, now: now, calendar: calendar)
        }
        switch rule.combinator {
        case .any: return bits.contains(true)
        case .all: return bits.allSatisfy { $0 }
        case .none: return !bits.contains(true)
        }
    }

    static func conditionMatches(
        _ condition: Condition,
        link: IncomingLink,
        runningCount: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        switch condition.kind {
        case .url:
            return urlMatches(link.absoluteString, matcher: condition.urlMatcher, pattern: condition.pattern)
        case .runningCount:
            return countMatches(runningCount, comparator: condition.countComparator, n: condition.count)
        case .linkType:
            switch condition.linkKind {
            case .website:
                let scheme = link.url.scheme?.lowercased()
                return !link.isFileURL && (scheme == "http" || scheme == "https")
            case .localHTML:
                return link.isFileURL
            }
        case .sourceApp:
            return urlMatches(link.sourceBundleID ?? "", matcher: condition.urlMatcher, pattern: condition.pattern)
        case .schedule:
            guard condition.weekdays.contains(calendar.component(.weekday, from: now)) else { return false }
            let minute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
            if condition.startMinute <= condition.endMinute {
                return minute >= condition.startMinute && minute < condition.endMinute
            }
            return minute >= condition.startMinute || minute < condition.endMinute
        }
    }

    static func matchProfile(_ profiles: [RouteProfile], link: IncomingLink) -> RouteProfile? {
        for profile in profiles where profile.enabled {
            guard profile.browserRowID != nil else { continue }
            if profile.filledPatterns.contains(where: { hostPattern($0, matches: link) }) {
                return profile
            }
        }
        return nil
    }

    /// `github.com` matches that host and subdomains. A fuller string matches as a substring of the URL.
    static func hostPattern(_ pattern: String, matches link: IncomingLink) -> Bool {
        let needle = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty { return false }
        if needle.contains("://") || needle.contains("/") {
            return urlMatches(link.absoluteString, matcher: .contains, pattern: needle)
        }
        let host = link.host.lowercased()
        let key = needle.lowercased()
        if host == key || host.hasSuffix("." + key) { return true }
        return link.absoluteString.localizedCaseInsensitiveContains(needle)
    }

    static func urlMatches(_ value: String, matcher: URLMatcher, pattern: String) -> Bool {
        let needle = pattern.lowercased()
        switch matcher {
        case .is: return value.lowercased() == needle
        case .isNot: return value.lowercased() != needle
        case .contains:
            return !needle.isEmpty && value.lowercased().contains(needle)
        case .beginsWith:
            return !needle.isEmpty && value.lowercased().hasPrefix(needle)
        case .endsWith:
            return !needle.isEmpty && value.lowercased().hasSuffix(needle)
        case .like: return likeMatches(value, pattern: pattern)
        case .regex: return regexMatches(value, pattern: pattern)
        }
    }

    static func likeMatches(_ value: String, pattern: String) -> Bool {
        guard !pattern.isEmpty else { return false }
        var escaped = ""
        for character in pattern {
            switch character {
            case "*":
                escaped += ".*"
            case "?":
                escaped += "."
            default:
                escaped += NSRegularExpression.escapedPattern(for: String(character))
            }
        }
        return regexMatches(value, pattern: "^(?:\(escaped))$", options: [.caseInsensitive])
    }

    static func regexMatches(
        _ value: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> Bool {
        let wrapped: String
        if pattern.hasPrefix("^") || pattern.hasSuffix("$") {
            wrapped = pattern
        } else {
            wrapped = "^(?:\(pattern))$"
        }
        do {
            let regex = try NSRegularExpression(pattern: wrapped, options: options)
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            return regex.firstMatch(in: value, options: [], range: range) != nil
        } catch {
            return false
        }
    }

    static func countMatches(_ running: Int, comparator: CountComparator, n: Int) -> Bool {
        let clamped = min(max(n, 0), 10)
        switch comparator {
        case .is: return running == clamped
        case .isNot: return running != clamped
        case .lessThan: return running < clamped
        case .greaterThan: return running > clamped
        }
    }

    private static func result(for behaviour: Behaviour, fallback: Rule?) -> EngineResult {
        switch behaviour.kind {
        case .useFavourite:
            return .favourite
        case .useBestRunning:
            return .bestRunning
        case .promptAll:
            return .promptAll
        case .promptRunning:
            return .promptRunning
        case .promptBrowsers:
            return .prompt(ids: behaviour.rowIDs)
        case .openBrowser:
            if let id = behaviour.rowIDs.first {
                return .open([id])
            }
            return .promptAll
        case .openBrowsersInOrder:
            return .open(behaviour.rowIDs)
        case .useDefaultBehaviour:
            if let fallback {
                return result(for: fallback.behaviour, fallback: nil)
            }
            return .promptAll
        }
    }
}
