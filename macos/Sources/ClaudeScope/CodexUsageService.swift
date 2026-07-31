import Foundation
import Combine

/// Tracks OpenAI Codex usage alongside Claude's.
///
/// No OAuth flow of our own: Codex CLI already keeps a ChatGPT token in
/// ~/.codex/auth.json, which we read on each poll and use only against
/// OpenAI's own usage endpoint — never stored or sent anywhere else. When the
/// API is unreachable (expired token, offline) the latest rate-limit snapshot
/// recorded in ~/.codex/sessions is shown instead, marked as stale.
@MainActor
final class CodexUsageService: ObservableObject {
    @Published private(set) var usage: CodexUsage?
    @Published private(set) var isStale = false
    @Published private(set) var lastUpdated: Date?

    /// nil while Codex CLI is not installed (or unreadable in sandbox) —
    /// the UI hides the whole section then.
    var isAvailable: Bool {
        !AppEnvironment.isAppStoreBuild
            && FileManager.default.fileExists(atPath: codexDirectory.appendingPathComponent("auth.json").path)
    }

    private static let usageEndpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    private let codexDirectory: URL
    private let session: URLSession
    private var timer: AnyCancellable?

    init(
        codexDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true),
        session: URLSession = .shared
    ) {
        self.codexDirectory = codexDirectory
        self.session = session
    }

    func startPolling() {
        guard isAvailable else { return }
        let minutes = UserDefaults.standard.integer(forKey: "pollingMinutes")
        let interval = TimeInterval(max(minutes, 5) * 60)
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
        Task { await refresh() }
    }

    func refresh() async {
        guard isAvailable else { return }

        if let fresh = await fetchFromAPI() {
            usage = fresh
            isStale = false
            lastUpdated = Date()
            return
        }

        // API failed — fall back to the newest local snapshot, but never
        // replace fresher API data we already have.
        if usage == nil || isStale, let local = latestSessionSnapshot() {
            usage = local
            isStale = true
        }
    }

    // MARK: - API

    private struct AuthTokens {
        let accessToken: String
        let accountID: String?
    }

    private func loadAuthTokens() -> AuthTokens? {
        let url = codexDirectory.appendingPathComponent("auth.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = object["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty else {
            return nil
        }
        return AuthTokens(accessToken: accessToken, accountID: tokens["account_id"] as? String)
    }

    private func fetchFromAPI() async -> CodexUsage? {
        guard let auth = loadAuthTokens() else { return nil }

        var request = URLRequest(url: Self.usageEndpoint)
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID = auth.accountID {
            request.setValue(accountID, forHTTPHeaderField: "chatgpt-account-id")
        }

        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            return nil
        }
        return CodexUsageParser.usage(fromAPIResponse: data)
    }

    // MARK: - Local fallback

    /// Newest `token_count` event's rate_limits from the most recent session
    /// file. Reads the file tail-first conceptually: last matching line wins.
    private func latestSessionSnapshot() -> CodexUsage? {
        let sessionsDirectory = codexDirectory.appendingPathComponent("sessions")
        guard let walker = FileManager.default.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
        ) else {
            return nil
        }

        var newest: (URL, Date)?
        for case let url as URL in walker where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true, let modified = values?.contentModificationDate else { continue }
            if newest == nil || modified > newest!.1 {
                newest = (url, modified)
            }
        }
        guard let (url, _) = newest,
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        for line in contents.split(separator: "\n").reversed() {
            guard line.contains("rate_limits"),
                  let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let payload = object["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count",
                  let rateLimits = payload["rate_limits"] as? [String: Any],
                  let parsed = CodexUsageParser.usage(fromSessionRateLimits: rateLimits) else {
                continue
            }
            return parsed
        }
        return nil
    }
}
