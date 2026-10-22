import Foundation

enum MailRouting {
    enum Decision: Equatable {
        case open(String)
        case prompt([String])
        case none
    }

    static func decide(
        mode: MailMode,
        favourite: String?,
        installed: Set<String>,
        enabled: [String],
        forcePrompt: Bool
    ) -> Decision {
        let candidates = enabled.filter(installed.contains)
        if !forcePrompt, mode == .always, let favourite,
           installed.contains(favourite), candidates.contains(favourite) {
            return .open(favourite)
        }
        return candidates.isEmpty ? .none : .prompt(candidates)
    }
}
