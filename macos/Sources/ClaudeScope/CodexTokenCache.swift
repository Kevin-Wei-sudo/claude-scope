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
    let directoryURL: URL

    init(directoryURL: URL = AppPaths.credentialsDirectoryURL) {
        self.directoryURL = directoryURL
    }

    private var fileURL: URL {
        directoryURL.appendingPathComponent("codex-chatgpt-tokens.json")
    }

    func load() -> CachedCodexTokens? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CachedCodexTokens.self, from: data)
    }

    func save(_ tokens: CachedCodexTokens) {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(tokens) else { return }
        try? data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
