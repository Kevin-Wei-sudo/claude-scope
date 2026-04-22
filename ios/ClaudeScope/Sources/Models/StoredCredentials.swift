import Foundation

struct StoredCredentials: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let scopes: [String]

    var hasRefreshToken: Bool {
        guard let refreshToken else { return false }
        return !refreshToken.isEmpty
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
    private let fileManager: FileManager
    let directoryURL: URL
    let credentialsFileURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.directoryURL = appSupport.appendingPathComponent("ClaudeScope", isDirectory: true)
        self.credentialsFileURL = directoryURL.appendingPathComponent("credentials.json")
    }

    func save(_ credentials: StoredCredentials) throws {
        try ensureDirectoryExists()
        let data = try Self.encoder.encode(credentials)
        try data.write(to: credentialsFileURL, options: .atomic)
    }

    func load(defaultScopes: [String]) -> StoredCredentials? {
        guard let data = try? Data(contentsOf: credentialsFileURL),
              let credentials = try? Self.decoder.decode(StoredCredentials.self, from: data) else {
            return nil
        }
        return credentials
    }

    func delete() {
        try? fileManager.removeItem(at: credentialsFileURL)
    }

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
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
