import Foundation

enum Migrations {
    static func migrate(_ state: PersistedState) -> PersistedState {
        var state = state
        if state.schemaVersion < PersistedState.currentSchemaVersion {
            state.schemaVersion = PersistedState.currentSchemaVersion
        }
        return state
    }
}

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
        case newer(Int)
    }

    private struct VersionProbe: Decodable {
        var schemaVersion: Int?
    }

    static func load() -> LoadResult {
        guard let data = try? Data(contentsOf: stateURL) else { return .missing }
        if let probe = try? JSONDecoder().decode(VersionProbe.self, from: data),
           let version = probe.schemaVersion,
           version > PersistedState.currentSchemaVersion {
            let backup = stampededBackup(prefix: "state.newer-")
            try? data.write(to: backup)
            Log.app.error("State file schema \(version) is newer than supported \(PersistedState.currentSchemaVersion). Kept copy at \(backup.path)")
            return .newer(version)
        }
        do {
            return .loaded(Migrations.migrate(try JSONDecoder().decode(PersistedState.self, from: data)))
        } catch {
            let backup = stampededBackup(prefix: "state.corrupt-")
            try? data.write(to: backup)
            Log.app.error("Failed to decode state: \(error.localizedDescription). Kept copy at \(backup.path)")
            return .corrupt
        }
    }

    private static func stampededBackup(prefix: String) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return directory.appendingPathComponent("\(prefix)\(formatter.string(from: Date())).json")
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
