import XCTest

@MainActor
final class ContextSyncTests: XCTestCase {
    func testVPNInterfaceRecognition() {
        for prefix in ["utun", "ipsec", "ppp", "tun", "tap", "wg"] {
            XCTAssertTrue(NetworkContext.isVPN(primaryInterface: "\(prefix)4", activeIPv4Interfaces: []))
        }
        XCTAssertTrue(NetworkContext.isVPN(primaryInterface: "en0", activeIPv4Interfaces: ["utun7"]))
        XCTAssertTrue(NetworkContext.isVPN(primaryInterface: "en0", activeIPv4Interfaces: ["ipsec0"]))
        XCTAssertTrue(NetworkContext.isVPN(primaryInterface: "en0", activeIPv4Interfaces: ["ppp0"]))
        XCTAssertFalse(NetworkContext.isVPN(primaryInterface: "en0", activeIPv4Interfaces: ["en0", "awdl0"]))
        XCTAssertFalse(NetworkContext.isVPN(primaryInterface: nil, activeIPv4Interfaces: []))
    }

    func testFocusModePersistsInUserDefaults() {
        let suiteName = "LinkRouter.FocusModeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        FocusModeStore.set(" Work ", defaults: defaults)

        XCTAssertEqual(defaults.string(forKey: "LinkRouterFocusMode"), "Work")
        XCTAssertEqual(FocusModeStore.current(defaults: defaults), "Work")
        FocusModeStore.set("", defaults: defaults)
        XCTAssertNil(FocusModeStore.current(defaults: defaults))
    }

    func testDeviceIdentifierIsStoredAsUUID() {
        let suiteName = "LinkRouter.DeviceIDTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = SyncStore.deviceIdentifier(defaults: defaults)
        let second = SyncStore.deviceIdentifier(defaults: defaults)

        XCTAssertEqual(first, second)
        XCTAssertNotNil(UUID(uuidString: first))
        XCTAssertEqual(defaults.string(forKey: "LinkRouterDeviceID"), first)
    }

    func testOldSettingsDefaultSyncToOff() throws {
        let oldSettings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertFalse(oldSettings.syncEnabled)
    }

    func testSyncWriteReadRoundTripExcludesPerMacFields() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let defaults = testDefaults()
        defer { removeDefaults(defaults) }
        let deviceID = UUID().uuidString
        let store = SyncStore(folderURL: folder, deviceID: deviceID, defaults: defaults, initialLastApplied: .distantPast)
        var state = sampleState()
        state.settings.showMenuBar = false
        state.settings.onboardingDone = true
        state.settings.syncEnabled = true
        state.recent = [
            RoutedEntry(
                id: UUID(),
                url: URL(string: "https://history.example")!,
                rowID: state.rows[0].id,
                title: "History",
                date: Date(timeIntervalSince1970: 10)
            )
        ]

        let modifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try store.writeNow(state, modifiedAt: modifiedAt)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: store.syncURL)) as? [String: Any])
        let settings = try XCTUnwrap(object["settings"] as? [String: Any])
        XCTAssertNil(object["recent"])
        XCTAssertEqual(object["deviceID"] as? String, deviceID)
        XCTAssertNotNil(object["modifiedAt"])
        XCTAssertNil(settings["showMenuBar"])
        XCTAssertNil(settings["onboardingDone"])
        XCTAssertNil(settings["syncEnabled"])
        XCTAssertNil(settings["shortcuts"])
        XCTAssertNotNil(settings["appearance"])

        let roundTrip = try XCTUnwrap(store.readRemoteState())
        XCTAssertEqual(roundTrip.browsers, state.browsers)
        XCTAssertEqual(roundTrip.rows, state.rows)
        XCTAssertTrue(roundTrip.recent.isEmpty)
        XCTAssertTrue(roundTrip.settings.showMenuBar)
        XCTAssertFalse(roundTrip.settings.onboardingDone)
        XCTAssertFalse(roundTrip.settings.syncEnabled)
        XCTAssertEqual(roundTrip.modifiedAt, modifiedAt)
    }

    func testWriteNowDoesNotCreateFolderWhenCloudDocsIsUnavailable() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = SyncStore(
            folderURL: folder,
            deviceID: UUID().uuidString,
            cloudDocsAvailable: { false }
        )

        XCTAssertThrowsError(try store.writeNow(sampleState()))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testNewerRemoteFromAnotherDeviceIsApplied() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let defaults = testDefaults()
        defer { removeDefaults(defaults) }
        let baseline = Date(timeIntervalSince1970: 1_700_000_000)
        let remote = SyncStore(
            folderURL: folder,
            deviceID: UUID().uuidString,
            defaults: testDefaults(),
            initialLastApplied: .distantPast
        )
        var remoteState = sampleState()
        remoteState.browsers[0].displayName = "Remote Browser"
        try remote.writeNow(remoteState, modifiedAt: baseline.addingTimeInterval(60))

        let local = SyncStore(
            folderURL: folder,
            deviceID: UUID().uuidString,
            defaults: defaults,
            initialLastApplied: baseline
        )
        var applied: PersistedState?
        XCTAssertTrue(local.startWatching(onApply: { applied = $0 }, watchChanges: false, checkImmediately: false))

        XCTAssertTrue(local.receiveRemoteIfNewer())
        XCTAssertEqual(applied?.browsers.first?.displayName, "Remote Browser")
        XCTAssertEqual(local.lastSyncedAt, baseline.addingTimeInterval(60))
        local.stopWatching()
    }

    func testNewerRemoteWinsOverPendingLocalEdit() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let remoteDefaults = testDefaults()
        let localDefaults = testDefaults()
        defer {
            removeDefaults(remoteDefaults)
            removeDefaults(localDefaults)
        }
        let remoteID = UUID().uuidString
        let remote = SyncStore(folderURL: folder, deviceID: remoteID, defaults: remoteDefaults)
        var remoteState = sampleState()
        remoteState.browsers[0].displayName = "Remote Browser"
        let remoteModifiedAt = Date().addingTimeInterval(60)
        try remote.writeNow(remoteState, modifiedAt: remoteModifiedAt)

        let localID = UUID().uuidString
        let local = SyncStore(
            folderURL: folder,
            deviceID: localID,
            defaults: localDefaults,
            initialLastApplied: .distantPast
        )
        var applied: PersistedState?
        XCTAssertTrue(local.startWatching(
            onApply: { applied = $0 },
            watchChanges: false,
            checkImmediately: false
        ))
        var localState = sampleState()
        localState.browsers[0].displayName = "Local Edit"
        XCTAssertTrue(local.scheduleWrite(localState))

        XCTAssertTrue(local.receiveRemoteIfNewer())
        XCTAssertEqual(applied?.browsers.first?.displayName, "Remote Browser")
        XCTAssertEqual(local.readRemoteState()?.deviceID, remoteID)
        local.stopWatching()
    }

    func testPendingLocalEditWinsOverOlderRemoteAndFlushesImmediately() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let remoteDefaults = testDefaults()
        let localDefaults = testDefaults()
        defer {
            removeDefaults(remoteDefaults)
            removeDefaults(localDefaults)
        }
        let remoteID = UUID().uuidString
        let remote = SyncStore(folderURL: folder, deviceID: remoteID, defaults: remoteDefaults)
        var remoteState = sampleState()
        remoteState.browsers[0].displayName = "Older Remote"
        let remoteModifiedAt = Date().addingTimeInterval(-60)
        try remote.writeNow(remoteState, modifiedAt: remoteModifiedAt)

        let localID = UUID().uuidString
        let local = SyncStore(
            folderURL: folder,
            deviceID: localID,
            defaults: localDefaults,
            initialLastApplied: .distantPast
        )
        var applied: PersistedState?
        XCTAssertTrue(local.startWatching(
            onApply: { applied = $0 },
            watchChanges: false,
            checkImmediately: false
        ))
        var localState = sampleState()
        localState.browsers[0].displayName = "Local Edit"
        XCTAssertTrue(local.scheduleWrite(localState))

        XCTAssertFalse(local.receiveRemoteIfNewer())
        XCTAssertNil(applied)
        XCTAssertEqual(local.readRemoteState()?.deviceID, localID)
        XCTAssertEqual(local.readRemoteState()?.browsers.first?.displayName, "Local Edit")
        XCTAssertGreaterThanOrEqual(
            localDefaults.object(forKey: SyncStore.lastAppliedKey) as? Date ?? .distantPast,
            remoteModifiedAt
        )
        local.stopWatching()
    }

    func testFailedOlderRemoteFlushRetriesPendingLocalSnapshot() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let remoteDefaults = testDefaults()
        let localDefaults = testDefaults()
        defer {
            removeDefaults(remoteDefaults)
            removeDefaults(localDefaults)
        }
        let remoteID = UUID().uuidString
        let remote = SyncStore(folderURL: folder, deviceID: remoteID, defaults: remoteDefaults)
        let remoteModifiedAt = Date().addingTimeInterval(-60)
        try remote.writeNow(sampleState(), modifiedAt: remoteModifiedAt)

        let localID = UUID().uuidString
        var writeAttempts = 0
        let local = SyncStore(
            folderURL: folder,
            deviceID: localID,
            defaults: localDefaults,
            initialLastApplied: .distantPast,
            writeFile: { data, url in
                writeAttempts += 1
                guard writeAttempts > 1 else {
                    throw CocoaError(.fileWriteUnknown)
                }
                try data.write(to: url, options: .atomic)
            }
        )
        XCTAssertTrue(local.startWatching(onApply: { _ in }, watchChanges: false, checkImmediately: false))
        var localState = sampleState()
        localState.browsers[0].displayName = "Local Edit"
        XCTAssertTrue(local.scheduleWrite(localState))

        XCTAssertFalse(local.receiveRemoteIfNewer())
        XCTAssertGreaterThanOrEqual(
            localDefaults.object(forKey: SyncStore.lastAppliedKey) as? Date ?? .distantPast,
            remoteModifiedAt
        )

        try await Task.sleep(nanoseconds: 2_500_000_000)

        XCTAssertEqual(writeAttempts, 2)
        XCTAssertEqual(local.readRemoteState()?.deviceID, localID)
        XCTAssertEqual(local.readRemoteState()?.browsers.first?.displayName, "Local Edit")
        local.stopWatching()
    }

    func testOwnDeviceAndOlderRemoteFilesAreIgnored() throws {
        let ownFolder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: ownFolder) }
        let defaults = testDefaults()
        defer { removeDefaults(defaults) }
        let baseline = Date(timeIntervalSince1970: 1_700_000_000)
        let ownDeviceID = UUID().uuidString
        let ownWriter = SyncStore(
            folderURL: ownFolder,
            deviceID: ownDeviceID,
            defaults: testDefaults(),
            initialLastApplied: .distantPast
        )
        try ownWriter.writeNow(sampleState(), modifiedAt: baseline.addingTimeInterval(60))
        let ownReader = SyncStore(
            folderURL: ownFolder,
            deviceID: ownDeviceID,
            defaults: defaults,
            initialLastApplied: .distantPast
        )
        XCTAssertTrue(ownReader.startWatching(onApply: { _ in XCTFail("own-device file must be ignored") }, watchChanges: false, checkImmediately: false))
        XCTAssertFalse(ownReader.receiveRemoteIfNewer())
        ownReader.stopWatching()

        let olderFolder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: olderFolder) }
        let olderWriter = SyncStore(
            folderURL: olderFolder,
            deviceID: UUID().uuidString,
            defaults: testDefaults(),
            initialLastApplied: .distantPast
        )
        try olderWriter.writeNow(sampleState(), modifiedAt: baseline.addingTimeInterval(-60))
        let olderReader = SyncStore(
            folderURL: olderFolder,
            deviceID: UUID().uuidString,
            defaults: defaults,
            initialLastApplied: baseline
        )
        XCTAssertTrue(olderReader.startWatching(onApply: { _ in XCTFail("older file must be ignored") }, watchChanges: false, checkImmediately: false))
        XCTAssertFalse(olderReader.receiveRemoteIfNewer())
        olderReader.stopWatching()
    }

    func testApplyingRemoteDoesNotTriggerWriteBack() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let remoteDefaults = testDefaults()
        defer { removeDefaults(remoteDefaults) }
        let localDefaults = testDefaults()
        defer { removeDefaults(localDefaults) }
        let baseline = Date(timeIntervalSince1970: 1_700_000_000)
        let remoteID = UUID().uuidString
        let remote = SyncStore(folderURL: folder, deviceID: remoteID, defaults: remoteDefaults, initialLastApplied: .distantPast)
        try remote.writeNow(sampleState(), modifiedAt: baseline.addingTimeInterval(60))

        let local = SyncStore(
            folderURL: folder,
            deviceID: UUID().uuidString,
            defaults: localDefaults,
            initialLastApplied: baseline
        )
        var scheduledWrite = true
        XCTAssertTrue(local.startWatching(
            onApply: { state in scheduledWrite = local.scheduleWrite(state) },
            watchChanges: false,
            checkImmediately: false
        ))

        XCTAssertTrue(local.receiveRemoteIfNewer())
        XCTAssertFalse(scheduledWrite)
        XCTAssertEqual(local.readRemoteState()?.deviceID, remoteID)
        local.stopWatching()
    }

    func testCloudPlaceholderRequestsDownloadAndReturnsNil() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let defaults = testDefaults()
        defer { removeDefaults(defaults) }
        var downloadedURL: URL?
        let store = SyncStore(
            folderURL: folder,
            deviceID: UUID().uuidString,
            defaults: defaults,
            initialLastApplied: .distantPast,
            downloadPlaceholder: { downloadedURL = $0 }
        )
        let placeholder = store.syncURL.appendingPathExtension("icloud")
        try Data().write(to: placeholder)

        XCTAssertNil(store.readRemoteState())
        XCTAssertEqual(downloadedURL, placeholder)
    }

    private var defaultSuiteNames = [ObjectIdentifier: String]()

    private func sampleState() -> PersistedState {
        let browser = BrowserRecord(
            id: UUID(),
            path: "/Applications/Safari.app",
            bundleIdentifier: "com.apple.Safari",
            displayName: "Safari"
        )
        let row = CatalogRow(id: UUID(), browserID: browser.id, kind: .app)
        return PersistedState(
            browsers: [browser],
            rows: [row],
            rules: Rule.shipped(),
            profiles: [],
            settings: AppSettings()
        )
    }

    private func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("LinkRouter-SyncTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func testDefaults() -> UserDefaults {
        let suiteName = "LinkRouter.SyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaultSuiteNames[ObjectIdentifier(defaults)] = suiteName
        return defaults
    }

    private func removeDefaults(_ defaults: UserDefaults) {
        guard let suiteName = defaultSuiteNames.removeValue(forKey: ObjectIdentifier(defaults)) else { return }
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        for suiteName in defaultSuiteNames.values {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        defaultSuiteNames.removeAll()
        super.tearDown()
    }
}
