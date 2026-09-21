import XCTest
@testable import ClaudeScope

final class StoredCredentialsTests: XCTestCase {
    private let vault = InMemoryTokenVault()
    func testStoreSavesAndLoadsCredentialBundle() throws {
        let store = try makeStore()
        let credentials = StoredCredentials(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            expiresAt: Date(timeIntervalSince1970: 1_741_194_400),
            scopes: ["user:profile", "user:inference"]
        )

        try store.save(credentials)

        let loaded = try XCTUnwrap(store.load(defaultScopes: []))
        XCTAssertEqual(loaded, credentials)

        // The keychain is now the primary store: no plaintext file remains.
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.credentialsFileURL.path))
    }

    func testStoreLoadsLegacyRawTokenFile() throws {
        let store = try makeStore()
        try "legacy-access-token".write(
            to: store.legacyTokenFileURL,
            atomically: true,
            encoding: .utf8
        )

        let loaded = try XCTUnwrap(
            store.load(defaultScopes: UsageService.defaultOAuthScopes)
        )

        XCTAssertEqual(loaded.accessToken, "legacy-access-token")
        XCTAssertNil(loaded.refreshToken)
        XCTAssertNil(loaded.expiresAt)
        XCTAssertEqual(loaded.scopes, UsageService.defaultOAuthScopes)
    }

    // MARK: - isExpired

    func testIsExpiredReturnsFalseWhenExpiresAtIsNil() {
        let credentials = StoredCredentials(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: nil,
            scopes: ["user:profile"]
        )
        XCTAssertFalse(credentials.isExpired())
    }

    func testIsExpiredReturnsTrueWhenPastExpiry() {
        let credentials = StoredCredentials(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(-60),
            scopes: ["user:profile"]
        )
        XCTAssertTrue(credentials.isExpired())
    }

    func testIsExpiredReturnsFalseWhenBeforeExpiry() {
        let credentials = StoredCredentials(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(3600),
            scopes: ["user:profile"]
        )
        XCTAssertFalse(credentials.isExpired())
    }

    // MARK: - needsRefresh leeway

    func testNeedsRefreshUses300SecondLeewayByDefault() {
        let now = Date()
        let credentials = StoredCredentials(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: now.addingTimeInterval(200),
            scopes: ["user:profile"]
        )
        // 200s until expiry < 300s leeway → needs refresh
        XCTAssertTrue(credentials.needsRefresh(at: now))

        let safeCredentials = StoredCredentials(
            accessToken: "token",
            refreshToken: "refresh",
            expiresAt: now.addingTimeInterval(400),
            scopes: ["user:profile"]
        )
        // 400s until expiry > 300s leeway → does not need refresh
        XCTAssertFalse(safeCredentials.needsRefresh(at: now))
    }

    private func makeStore() throws -> StoredCredentialsStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let legacyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        return StoredCredentialsStore(directoryURL: directory, legacyDirectoryURL: legacyDirectory, vault: vault)
    }

    private func permissions(for url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.posixPermissions] as? Int ?? -1
    }

    // MARK: - Keychain vault behaviour

    func testSaveWritesToVaultAndRemovesPlaintextFile() throws {
        let store = try makeStore()
        let credentials = StoredCredentials(
            accessToken: "tok", refreshToken: "ref",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000),
            scopes: ["user:profile"]
        )

        try store.save(credentials)

        XCTAssertNotNil(vault.readData(account: StoredCredentialsStore.vaultAccount))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.credentialsFileURL.path),
                       "no plaintext copy once the keychain holds the secret")
        XCTAssertEqual(store.load(defaultScopes: []), credentials)
    }

    func testLoadAdoptsPreKeychainFileIntoVault() throws {
        let store = try makeStore()
        let credentials = StoredCredentials(accessToken: "old", refreshToken: nil, expiresAt: nil, scopes: ["s"])
        try FileManager.default.createDirectory(at: store.directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(credentials).write(to: store.credentialsFileURL)

        let loaded = store.load(defaultScopes: [])

        XCTAssertEqual(loaded, credentials)
        XCTAssertNotNil(vault.readData(account: StoredCredentialsStore.vaultAccount), "file adopted into keychain")
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.credentialsFileURL.path), "plaintext removed after adoption")
    }

    func testVaultWriteFailureFallsBackToProtectedFile() throws {
        vault.failsWrites = true
        let store = try makeStore()
        let credentials = StoredCredentials(accessToken: "tok", refreshToken: nil, expiresAt: nil, scopes: [])

        try store.save(credentials)

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.credentialsFileURL.path),
                      "session must survive a keychain that refuses writes")
        let permissions = try FileManager.default.attributesOfItem(
            atPath: store.credentialsFileURL.path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o600)
        XCTAssertEqual(store.load(defaultScopes: []), credentials)
    }

    func testDeleteClearsVault() throws {
        let store = try makeStore()
        try store.save(StoredCredentials(accessToken: "tok", refreshToken: nil, expiresAt: nil, scopes: []))

        store.delete()

        XCTAssertNil(vault.readData(account: StoredCredentialsStore.vaultAccount))
        XCTAssertNil(store.load(defaultScopes: []))
    }
}
