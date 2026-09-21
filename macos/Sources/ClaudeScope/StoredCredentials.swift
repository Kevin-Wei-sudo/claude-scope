import Foundation

struct StoredCredentials: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let scopes: [String]

    var hasRefreshToken: Bool {
        guard let refreshToken else { return false }
        return refreshToken.isEmpty == false
    }

    func needsRefresh(at now: Date = Date(), leeway: TimeInterval = 300) -> Bool {
        guard hasRefreshToken, let expiresAt else { return false }
        return expiresAt <= now.addingTimeInterval(leeway)
    }

    func isExpired(at now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= now
    }
}

struct StoredCredentialsStore {
    static let vaultAccount = "claude-oauth-credentials"

    private let fileManager: FileManager
    private let vault: TokenVault
    let directoryURL: URL
    let credentialsFileURL: URL
    let legacyTokenFileURL: URL
    let legacyDirectoryURL: URL
    let legacyCredentialsFileURL: URL
    let legacyLegacyTokenFileURL: URL

    init(
        directoryURL: URL = AppPaths.credentialsDirectoryURL,
        legacyDirectoryURL: URL = AppPaths.legacyCredentialsDirectoryURL,
        fileManager: FileManager = .default,
        vault: TokenVault = KeychainTokenVault()
    ) {
        self.fileManager = fileManager
        self.vault = vault
        self.directoryURL = directoryURL
        self.credentialsFileURL = directoryURL.appendingPathComponent("credentials.json")
        self.legacyTokenFileURL = directoryURL.appendingPathComponent("token")
        self.legacyDirectoryURL = legacyDirectoryURL
        self.legacyCredentialsFileURL = legacyDirectoryURL.appendingPathComponent("credentials.json")
        self.legacyLegacyTokenFileURL = legacyDirectoryURL.appendingPathComponent("token")
    }

    func save(_ credentials: StoredCredentials) throws {
        let data = try Self.encoder.encode(credentials)

        // Keychain is the primary store; the 0600 file remains only as a
        // fallback for a keychain that refuses to persist, so a save never
        // silently drops the user's session.
        if vault.writeData(data, account: Self.vaultAccount) {
            try? fileManager.removeItem(at: credentialsFileURL)
        } else {
            try ensureDirectoryExists()
            try data.write(to: credentialsFileURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: credentialsFileURL.path)
        }
        try? fileManager.removeItem(at: legacyTokenFileURL)
    }

    func load(defaultScopes: [String]) -> StoredCredentials? {
        if let data = vault.readData(account: Self.vaultAccount),
           let credentials = try? Self.decoder.decode(StoredCredentials.self, from: data) {
            return credentials
        }

        // Pre-keychain installs keep credentials.json — adopt it into the
        // keychain once and remove the plaintext copy.
        if let data = try? Data(contentsOf: credentialsFileURL),
           let credentials = try? Self.decoder.decode(StoredCredentials.self, from: data) {
            if vault.writeData(data, account: Self.vaultAccount) {
                try? fileManager.removeItem(at: credentialsFileURL)
            }
            return credentials
        }

        if let data = try? Data(contentsOf: legacyCredentialsFileURL),
           let credentials = try? Self.decoder.decode(StoredCredentials.self, from: data) {
            return credentials
        }

        guard let data = try? Data(contentsOf: legacyTokenFileURL),
              let token = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              token.isEmpty == false else {
            guard let data = try? Data(contentsOf: legacyLegacyTokenFileURL),
                  let token = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  token.isEmpty == false else {
                return nil
            }

            return StoredCredentials(
                accessToken: token,
                refreshToken: nil,
                expiresAt: nil,
                scopes: defaultScopes
            )
        }

        return StoredCredentials(
            accessToken: token,
            refreshToken: nil,
            expiresAt: nil,
            scopes: defaultScopes
        )
    }

    func delete() {
        vault.delete(account: Self.vaultAccount)
        try? fileManager.removeItem(at: credentialsFileURL)
        try? fileManager.removeItem(at: legacyTokenFileURL)
        try? fileManager.removeItem(at: legacyCredentialsFileURL)
        try? fileManager.removeItem(at: legacyLegacyTokenFileURL)
    }

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
