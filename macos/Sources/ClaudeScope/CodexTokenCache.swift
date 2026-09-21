import Foundation

/// Copy of the last ChatGPT tokens seen in ~/.codex/auth.json, kept so the
/// subscription windows survive Codex CLI switching to API-key billing
/// (which overwrites auth.json and discards the tokens).
struct CachedCodexTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String?
    var accountID: String?
    var cachedAt: Date
}

struct CodexTokenCache {
    static let vaultAccount = "codex-chatgpt-tokens"

    let directoryURL: URL
    private let vault: TokenVault

    init(
        directoryURL: URL = AppPaths.credentialsDirectoryURL,
        vault: TokenVault = KeychainTokenVault()
    ) {
        self.directoryURL = directoryURL
        self.vault = vault
    }

    private var fileURL: URL {
        directoryURL.appendingPathComponent("codex-chatgpt-tokens.json")
    }

    func load() -> CachedCodexTokens? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let data = vault.readData(account: Self.vaultAccount),
           let tokens = try? decoder.decode(CachedCodexTokens.self, from: data) {
            return tokens
        }

        // Adopt a pre-keychain file copy once, then remove the plaintext.
        guard let data = try? Data(contentsOf: fileURL),
              let tokens = try? decoder.decode(CachedCodexTokens.self, from: data) else {
            return nil
        }
        if vault.writeData(data, account: Self.vaultAccount) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        return tokens
    }

    func save(_ tokens: CachedCodexTokens) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(tokens) else { return }

        if vault.writeData(data, account: Self.vaultAccount) {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    func clear() {
        vault.delete(account: Self.vaultAccount)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
