import XCTest

final class ProfileReaderTests: XCTestCase {
    func testFirefoxProfilesParsesRelativeAndAbsolute() {
        let ini = """
        [General]
        StartWithLastProfile=1

        [Install4F96D1932A9F858E]
        Default=Profiles/abc.default
        Locked=1

        [Profile0]
        Name=default
        IsRelative=1
        Path=Profiles/abc.default

        [Profile1]
        Name=work
        IsRelative=0
        Path=/Users/x/ff

        [Profile2]
        IsRelative=1
        Path=Profiles/noname
        """
        let support = URL(fileURLWithPath: "/Users/x/Library/Application Support/Firefox")
        let profiles = ProfileReader.parseFirefoxProfiles(ini: ini, support: support)
        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles[0].name, "default")
        XCTAssertEqual(profiles[0].absPath, "/Users/x/Library/Application Support/Firefox/Profiles/abc.default")
        XCTAssertEqual(profiles[1].name, "work")
        XCTAssertEqual(profiles[1].absPath, "/Users/x/ff")
    }

    func testChromeProfilesFallsBackToDirectoryKey() {
        let json: [String: Any] = [
            "profile": [
                "info_cache": [
                    "Profile 2": ["name": ""],
                    "Default": ["name": "Person 1"],
                ]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let profiles = ProfileReader.parseChromeProfiles(localState: data)
        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles[0], ChromeProfile(directory: "Default", name: "Person 1"))
        XCTAssertEqual(profiles[1], ChromeProfile(directory: "Profile 2", name: "Profile 2"))
    }
}
