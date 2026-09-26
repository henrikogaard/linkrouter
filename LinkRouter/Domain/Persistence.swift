import Foundation

enum Persistence {
    static var directoryOverride: URL?

    static var directory: URL {
        if let directoryOverride {
            try? FileManager.default.createDirectory(at: directoryOverride, withIntermediateDirectories: true)
            return directoryOverride
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("LinkRouter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var stateURL: URL {
        directory.appendingPathComponent("state.json")
    }

    enum LoadResult {
        case loaded(PersistedState)
        case missing
        case corrupt
    }

    static func load() -> LoadResult {
        guard let data = try? Data(contentsOf: stateURL) else { return .missing }
        do {
            return .loaded(try JSONDecoder().decode(PersistedState.self, from: data))
        } catch {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let backup = directory.appendingPathComponent("state.corrupt-\(formatter.string(from: Date())).json")
            try? data.write(to: backup)
            Log.app.error("Failed to decode state: \(error.localizedDescription). Kept copy at \(backup.path)")
            return .corrupt
        }
    }

    static func save(_ state: PersistedState) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            Log.app.error("Failed to save state: \(error.localizedDescription)")
        }
    }
}
