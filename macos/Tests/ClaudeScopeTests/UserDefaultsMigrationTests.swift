import XCTest
@testable import ClaudeScope

final class UserDefaultsMigrationTests: XCTestCase {

    private var suiteName: String = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "io.sandwichlab.claudescope.migrationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults.removePersistentDomain(forName: UserDefaultsMigration.legacyDomain)
        defaults = nil
        super.tearDown()
    }

    func testCopiesLegacyValuesIntoNewDomain() {
        defaults.setPersistentDomain([
            "pollingMinutes": 15,
            "notificationThreshold5h": 70,
            "appLanguage": "zh-Hans",
            "setupComplete": true,
        ], forName: UserDefaultsMigration.legacyDomain)

        UserDefaultsMigration.runIfNeeded(defaults: defaults)

        XCTAssertEqual(defaults.integer(forKey: "pollingMinutes"), 15)
        XCTAssertEqual(defaults.integer(forKey: "notificationThreshold5h"), 70)
        XCTAssertEqual(defaults.string(forKey: "appLanguage"), "zh-Hans")
        XCTAssertTrue(defaults.bool(forKey: "setupComplete"))
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsMigration.migrationFlagKey))
    }

    func testDoesNotOverwriteExistingNewDomainValues() {
        defaults.set(30, forKey: "pollingMinutes")
        defaults.setPersistentDomain([
            "pollingMinutes": 15,
            "notificationThreshold5h": 70,
        ], forName: UserDefaultsMigration.legacyDomain)

        UserDefaultsMigration.runIfNeeded(defaults: defaults)

        XCTAssertEqual(defaults.integer(forKey: "pollingMinutes"), 30, "existing value should win")
        XCTAssertEqual(defaults.integer(forKey: "notificationThreshold5h"), 70, "new keys should still copy")
    }

    func testSkipsAppleSystemKeys() {
        defaults.setPersistentDomain([
            "pollingMinutes": 15,
            "AppleLanguages": ["zh-Hans"],
            "NSGlobalSomething": "ignored",
            "com.apple.something": "ignored",
        ], forName: UserDefaultsMigration.legacyDomain)

        UserDefaultsMigration.runIfNeeded(defaults: defaults)

        // Check what's actually written into our suite, not what
        // `object(forKey:)` returns — AppleLanguages etc. fall back to
        // NSGlobalDomain and would otherwise look "present" everywhere.
        let newDomain = defaults.persistentDomain(forName: suiteName) ?? [:]
        XCTAssertEqual(newDomain["pollingMinutes"] as? Int, 15)
        XCTAssertNil(newDomain["AppleLanguages"])
        XCTAssertNil(newDomain["NSGlobalSomething"])
        XCTAssertNil(newDomain["com.apple.something"])
    }

    func testRunsOnlyOnce() {
        defaults.setPersistentDomain([
            "pollingMinutes": 15,
        ], forName: UserDefaultsMigration.legacyDomain)
        UserDefaultsMigration.runIfNeeded(defaults: defaults)

        defaults.set(60, forKey: "pollingMinutes")
        UserDefaultsMigration.runIfNeeded(defaults: defaults)

        XCTAssertEqual(defaults.integer(forKey: "pollingMinutes"), 60,
                       "second run must not re-copy legacy value over the user's later change")
    }

    func testNoLegacyDomainIsHarmless() {
        UserDefaultsMigration.runIfNeeded(defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: UserDefaultsMigration.migrationFlagKey))
    }
}
