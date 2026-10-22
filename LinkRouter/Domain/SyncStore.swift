import Combine
import CryptoKit
import Darwin
import Foundation

private enum SyncStoreError: Error {
    case cloudDocsUnavailable
    case remotePendingDownload
}

private struct SyncPayloadFingerprint: Encodable {
    var state: PersistedState

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, browsers, rows, rules, profiles, settings
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state.schemaVersion, forKey: .schemaVersion)
        try container.encode(state.browsers, forKey: .browsers)
        try container.encode(state.rows, forKey: .rows)
        try container.encode(state.rules, forKey: .rules)
        try container.encode(state.profiles, forKey: .profiles)
        try container.encode(state.settings, forKey: .settings)
    }
}

@MainActor
final class SyncStore: ObservableObject {
    static let deviceIDKey = "LinkRouterDeviceID"
    static let lastSyncedKey = "LinkRouterLastSyncedAt"
    static let lastAppliedKey = "LinkRouterLastAppliedSyncAt"
    static let lastSyncedFingerprintKey = "LinkRouterLastSyncedFingerprint"

    static var cloudDocsURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    static var defaultFolderURL: URL {
        cloudDocsURL.appendingPathComponent("LinkRouter", isDirectory: true)
    }

    @Published private(set) var lastSyncedAt: Date?

    let folderURL: URL
    let deviceID: String

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let downloadPlaceholder: (URL) throws -> Void
    private let cloudDocsAvailability: () -> Bool
    private let writeFile: (Data, URL) throws -> Void
    private let writeDebounceInterval: TimeInterval
    private let writeRetryInterval: TimeInterval
    private var lastApplied: Date
    private var isEnabled = false
    private var suppressNextWrite = false
    private var onApply: ((PersistedState) -> Void)?
    private var pendingWrite: DispatchWorkItem?
    private var latestSnapshot: PersistedState?
    private var localDirtyAt: Date?
    private var retainsEditsWhileStopped = false
    private var pollTimer: Timer?
    private var directoryWatcher: DispatchSourceFileSystemObject?

    init(
        folderURL: URL? = nil,
        deviceID: String? = nil,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        initialLastApplied: Date? = nil,
        downloadPlaceholder: @escaping (URL) throws -> Void = {
            try FileManager.default.startDownloadingUbiquitousItem(at: $0)
        },
        cloudDocsAvailable: (() -> Bool)? = nil,
        writeFile: ((Data, URL) throws -> Void)? = nil,
        writeDebounceInterval: TimeInterval = 2,
        writeRetryInterval: TimeInterval = 5
    ) {
        self.folderURL = folderURL ?? Self.defaultFolderURL
        self.defaults = defaults
        self.fileManager = fileManager
        self.deviceID = deviceID ?? Self.deviceIdentifier(defaults: defaults)
        self.downloadPlaceholder = downloadPlaceholder
        if let cloudDocsAvailable {
            cloudDocsAvailability = cloudDocsAvailable
        } else if folderURL != nil {
            cloudDocsAvailability = { true }
        } else {
            cloudDocsAvailability = {
                fileManager.fileExists(atPath: Self.cloudDocsURL.path)
            }
        }
        self.writeFile = writeFile ?? { data, url in
            try data.write(to: url, options: .atomic)
        }
        self.writeDebounceInterval = writeDebounceInterval
        self.writeRetryInterval = writeRetryInterval
        lastSyncedAt = defaults.object(forKey: Self.lastSyncedKey) as? Date
        lastApplied = initialLastApplied
            ?? defaults.object(forKey: Self.lastAppliedKey) as? Date
            ?? Self.localStateModificationDate(fileManager: fileManager)
            ?? .distantPast
    }

    var syncURL: URL {
        folderURL.appendingPathComponent("sync.json")
    }

    var isRemotePendingDownload: Bool {
        guard !fileManager.fileExists(atPath: syncURL.path) else { return false }
        return [
            folderURL.appendingPathComponent(".sync.json.icloud"),
            syncURL.appendingPathExtension("icloud")
        ].contains { fileManager.fileExists(atPath: $0.path) }
    }

    var isRunning: Bool { isEnabled }

    var isICloudDriveAvailable: Bool {
        cloudDocsAvailability()
    }

    static func deviceIdentifier(defaults: UserDefaults = .standard) -> String {
        if let existing = defaults.string(forKey: deviceIDKey),
           UUID(uuidString: existing) != nil {
            return existing
        }
        let identifier = UUID().uuidString
        defaults.set(identifier, forKey: deviceIDKey)
        return identifier
    }

    @discardableResult
    func startWatching(
        onApply: @escaping (PersistedState) -> Void,
        watchChanges: Bool = true,
        checkImmediately: Bool = true
    ) -> Bool {
        guard !isEnabled else {
            self.onApply = onApply
            return true
        }

        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            Log.app.error("Could not create sync folder: \(error.localizedDescription)")
            return false
        }

        self.onApply = onApply
        isEnabled = true
        retainsEditsWhileStopped = false
        if watchChanges {
            startDirectoryWatcher()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.checkForRemoteUpdate() }
            }
        }
        if checkImmediately {
            checkForRemoteUpdate()
        }
        if let latestSnapshot, pendingWrite == nil {
            schedulePendingWrite(latestSnapshot)
        }
        return true
    }

    func stopWatching(preservingPendingEdits: Bool = false) {
        isEnabled = false
        pendingWrite?.cancel()
        pendingWrite = nil
        if preservingPendingEdits {
            retainsEditsWhileStopped = true
        } else {
            latestSnapshot = nil
            localDirtyAt = nil
            retainsEditsWhileStopped = false
        }
        pollTimer?.invalidate()
        pollTimer = nil
        directoryWatcher?.cancel()
        directoryWatcher = nil
        onApply = nil
        suppressNextWrite = false
    }

    @discardableResult
    func scheduleWrite(_ state: PersistedState) -> Bool {
        if suppressNextWrite {
            suppressNextWrite = false
            return false
        }
        guard isEnabled || retainsEditsWhileStopped else { return false }

        let snapshot = state
        let fingerprint = Self.payloadFingerprint(snapshot)
        if let fingerprint, fingerprint == defaults.string(forKey: Self.lastSyncedFingerprintKey) {
            if latestSnapshot != nil || localDirtyAt != nil {
                pendingWrite?.cancel()
                pendingWrite = nil
                latestSnapshot = nil
                localDirtyAt = nil
            }
            return false
        }
        if let latestSnapshot,
           let fingerprint,
           Self.payloadFingerprint(latestSnapshot) == fingerprint {
            self.latestSnapshot = snapshot
            return isEnabled
        }
        latestSnapshot = snapshot
        localDirtyAt = Date()
        guard isEnabled else { return false }
        schedulePendingWrite(snapshot)
        return true
    }

    private func schedulePendingWrite(_ snapshot: PersistedState, after delay: TimeInterval? = nil) {
        pendingWrite?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isEnabled else { return }
            do {
                try self.writeNow(snapshot)
            } catch {
                Log.app.error("Could not sync settings: \(error.localizedDescription)")
                guard self.isEnabled else { return }
                self.schedulePendingWrite(snapshot, after: self.writeRetryInterval)
            }
        }
        pendingWrite = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (delay ?? writeDebounceInterval), execute: work)
    }

    func writeNow(_ state: PersistedState, modifiedAt: Date = Date()) throws {
        guard isICloudDriveAvailable else {
            throw SyncStoreError.cloudDocsUnavailable
        }
        if isRemotePendingDownload {
            try? downloadPlaceholder(syncURL)
            throw SyncStoreError.remotePendingDownload
        }
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        var payload = state
        payload.modifiedAt = modifiedAt
        payload.deviceID = deviceID
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.userInfo[.linkRouterSyncPayload] = true
        try writeFile(encoder.encode(payload), syncURL)
        updateLastSynced(modifiedAt)
        if let fingerprint = Self.payloadFingerprint(payload) {
            defaults.set(fingerprint, forKey: Self.lastSyncedFingerprintKey)
        }
        pendingWrite = nil
        latestSnapshot = nil
        localDirtyAt = nil
    }

    func readRemoteState() -> PersistedState? {
        guard fileManager.fileExists(atPath: syncURL.path) else {
            if isRemotePendingDownload {
                try? downloadPlaceholder(syncURL)
            }
            return nil
        }

        guard let data = try? Data(contentsOf: syncURL),
              let state = try? Persistence.importState(from: data),
              state.modifiedAt != nil,
              state.deviceID != nil else {
            return nil
        }
        return state
    }

    func remoteStateFromAnotherDevice() -> PersistedState? {
        guard let remote = readRemoteState(), remote.deviceID != deviceID else { return nil }
        return remote
    }

    @discardableResult
    func receiveRemoteIfNewer(onApply: ((PersistedState) -> Void)? = nil) -> Bool {
        guard isEnabled,
              let remote = readRemoteState(),
              let remoteDeviceID = remote.deviceID,
              remoteDeviceID != deviceID,
              let modifiedAt = remote.modifiedAt,
              modifiedAt > lastApplied else {
            return false
        }

        if let localDirtyAt {
            if modifiedAt > localDirtyAt {
                pendingWrite?.cancel()
                pendingWrite = nil
                latestSnapshot = nil
                self.localDirtyAt = nil
                applyRemote(remote, modifiedAt: modifiedAt, onApply: onApply)
                return true
            }

            pendingWrite?.cancel()
            pendingWrite = nil
            if let fingerprint = Self.payloadFingerprint(remote) {
                defaults.set(fingerprint, forKey: Self.lastSyncedFingerprintKey)
            }
            if let latestSnapshot {
                do {
                    try writeNow(latestSnapshot)
                } catch {
                    Log.app.error("Could not sync settings: \(error.localizedDescription)")
                    schedulePendingWrite(latestSnapshot)
                }
            }
            lastApplied = max(lastApplied, modifiedAt)
            defaults.set(lastApplied, forKey: Self.lastAppliedKey)
            return false
        }

        applyRemote(remote, modifiedAt: modifiedAt, onApply: onApply)
        return true
    }

    func applyRemote(
        _ remote: PersistedState,
        modifiedAt: Date? = nil,
        onApply: ((PersistedState) -> Void)? = nil
    ) {
        guard remote.deviceID != deviceID else { return }
        let timestamp = modifiedAt ?? remote.modifiedAt ?? Date()
        lastApplied = timestamp
        defaults.set(timestamp, forKey: Self.lastAppliedKey)
        updateLastSynced(timestamp)
        if let fingerprint = Self.payloadFingerprint(remote) {
            defaults.set(fingerprint, forKey: Self.lastSyncedFingerprintKey)
        }
        suppressNextWrite = true
        (onApply ?? self.onApply)?(remote)
    }

    func ignoreRemote(_ remote: PersistedState) {
        guard remote.deviceID != deviceID, let modifiedAt = remote.modifiedAt else { return }
        lastApplied = max(lastApplied, modifiedAt)
        defaults.set(lastApplied, forKey: Self.lastAppliedKey)
        if let fingerprint = Self.payloadFingerprint(remote) {
            defaults.set(fingerprint, forKey: Self.lastSyncedFingerprintKey)
        }
    }

    private static func payloadFingerprint(_ state: PersistedState) -> String? {
        var payload = state
        payload.modifiedAt = nil
        payload.deviceID = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.userInfo[.linkRouterSyncPayload] = true
        guard let data = try? encoder.encode(SyncPayloadFingerprint(state: payload)) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", Int($0)) }.joined()
    }

    private func checkForRemoteUpdate() {
        _ = receiveRemoteIfNewer()
    }

    private func startDirectoryWatcher() {
        let descriptor = open(folderURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let watcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )
        watcher.setEventHandler { [weak self] in
            Task { @MainActor in self?.checkForRemoteUpdate() }
        }
        watcher.setCancelHandler {
            close(descriptor)
        }
        directoryWatcher = watcher
        watcher.resume()
    }

    private func updateLastSynced(_ date: Date) {
        lastSyncedAt = date
        defaults.set(date, forKey: Self.lastSyncedKey)
        lastApplied = max(lastApplied, date)
        defaults.set(lastApplied, forKey: Self.lastAppliedKey)
    }

    private static func localStateModificationDate(fileManager: FileManager) -> Date? {
        let attributes = try? fileManager.attributesOfItem(atPath: Persistence.stateURL.path)
        return attributes?[.modificationDate] as? Date
    }
}
