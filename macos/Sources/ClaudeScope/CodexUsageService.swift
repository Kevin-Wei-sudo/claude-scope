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
    @Published private(set) var localStats: CodexLocalStats?
    /// Codex CLI is on API-key billing — no subscription windows exist.
    @Published private(set) var billsByAPIKey = false
    /// Provider named in config.toml when billing via API key ("deepseek").
    @Published private(set) var apiKeyProvider: String?

    /// nil while Codex CLI is not installed (or unreadable in sandbox) —
    /// the UI hides the whole section then.
    var isAvailable: Bool {
        !AppEnvironment.isAppStoreBuild
            && FileManager.default.fileExists(atPath: codexDirectory.appendingPathComponent("auth.json").path)
    }

    /// The tab shows whenever anything is presentable: live windows, an
    /// offline snapshot, local stats, or an API-key-mode explanation.
    var hasDisplayableContent: Bool {
        usage != nil || localStats != nil || billsByAPIKey
    }

    private static let usageEndpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    private let codexDirectory: URL
    private let session: URLSession
    private let tokenCache: CodexTokenCache
    private var timer: AnyCancellable?

    /// Codex CLI's public OAuth client — used only to refresh cached tokens.
    private static let oauthClientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private static let oauthTokenEndpoint = URL(string: "https://auth.openai.com/oauth/token")!

    init(
        codexDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true),
        session: URLSession = .shared,
        tokenCache: CodexTokenCache = CodexTokenCache()
    ) {
        self.codexDirectory = codexDirectory
        self.session = session
        self.tokenCache = tokenCache
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

        refreshLocalStatsIfStale()

        let authData = try? Data(contentsOf: codexDirectory.appendingPathComponent("auth.json"))

        // API-key billing (e.g. a DeepSeek key): the ChatGPT tokens are gone
        // from auth.json, but the subscription still exists — poll it with the
        // tokens we cached while ChatGPT mode was active.
        if let authData, CodexUsageParser.isAPIKeyMode(authJSON: authData) {
            billsByAPIKey = true
            apiKeyProvider = loadProviderName()

            if let fresh = await fetchUsingCachedTokens() {
                usage = fresh
                isStale = false
                lastUpdated = Date()
            } else {
                // No usable cached tokens: nothing subscription-shaped to show.
                usage = nil
                isStale = false
            }
            return
        }
        billsByAPIKey = false
        apiKeyProvider = nil

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

    private func loadAuthTokens() -> CodexUsageParser.AuthTokens? {
        let url = codexDirectory.appendingPathComponent("auth.json")
        guard let data = try? Data(contentsOf: url),
              let tokens = CodexUsageParser.authTokens(fromAuthJSON: data) else {
            return nil
        }
        // Keep a copy: Codex CLI discards these when switching to API-key mode.
        cacheIfChanged(tokens, refreshToken: refreshTokenFromAuthJSON(data))
        return tokens
    }

    private func refreshTokenFromAuthJSON(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = object["tokens"] as? [String: Any] else { return nil }
        return tokens["refresh_token"] as? String
    }

    private func cacheIfChanged(_ tokens: CodexUsageParser.AuthTokens, refreshToken: String?) {
        let existing = tokenCache.load()
        guard existing?.accessToken != tokens.accessToken
            || existing?.refreshToken != refreshToken else { return }
        tokenCache.save(CachedCodexTokens(
            accessToken: tokens.accessToken,
            refreshToken: refreshToken ?? existing?.refreshToken,
            accountID: tokens.accountID,
            cachedAt: Date()
        ))
    }

    private func loadProviderName() -> String? {
        let url = codexDirectory.appendingPathComponent("config.toml")
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return CodexUsageParser.providerName(fromConfigTOML: content)
    }

    /// Subscription windows via cached ChatGPT tokens, refreshing them through
    /// Codex CLI's own OAuth client when expired. Best effort: any permanent
    /// failure just means the windows stay hidden until the next `codex login`.
    private func fetchUsingCachedTokens() async -> CodexUsage? {
        guard let cached = tokenCache.load() else { return nil }

        if let usage = await fetchUsage(accessToken: cached.accessToken, accountID: cached.accountID) {
            return usage
        }
        guard let refreshed = await refreshTokens(cached) else { return nil }
        tokenCache.save(refreshed)
        return await fetchUsage(accessToken: refreshed.accessToken, accountID: refreshed.accountID)
    }

    private func refreshTokens(_ cached: CachedCodexTokens) async -> CachedCodexTokens? {
        guard let refreshToken = cached.refreshToken, !refreshToken.isEmpty else { return nil }

        var request = URLRequest(url: Self.oauthTokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "client_id": Self.oauthClientID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "scope": "openid profile email",
        ])

        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = object["access_token"] as? String, !accessToken.isEmpty else {
            return nil
        }
        return CachedCodexTokens(
            accessToken: accessToken,
            refreshToken: object["refresh_token"] as? String ?? refreshToken,
            accountID: cached.accountID,
            cachedAt: Date()
        )
    }

    private func fetchFromAPI() async -> CodexUsage? {
        guard let auth = loadAuthTokens() else { return nil }
        return await fetchUsage(accessToken: auth.accessToken, accountID: auth.accountID)
    }

    private func fetchUsage(accessToken: String, accountID: String?) async -> CodexUsage? {
        var request = URLRequest(url: Self.usageEndpoint)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID {
            request.setValue(accountID, forHTTPHeaderField: "chatgpt-account-id")
        }

        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            return nil
        }
        return CodexUsageParser.usage(fromAPIResponse: data)
    }

    // MARK: - Local per-model / per-project stats

    private static let statsRescanInterval: TimeInterval = 10 * 60
    private var lastStatsScan: Date?

    private func refreshLocalStatsIfStale(windowDays: Int = 7) {
        if let lastStatsScan, Date().timeIntervalSince(lastStatsScan) < Self.statsRescanInterval, localStats != nil {
            return
        }
        lastStatsScan = Date()

        let directory = codexDirectory.appendingPathComponent("sessions")
        let cutoff = Date().addingTimeInterval(-Double(windowDays) * 86400)

        Task {
            let stats = await Task.detached(priority: .utility) { () -> CodexLocalStats in
                var turns = [CodexTurn]()
                if let walker = FileManager.default.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
                ) {
                    for case let url as URL in walker where url.pathExtension == "jsonl" {
                        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                        guard values?.isRegularFile == true,
                              let modified = values?.contentModificationDate,
                              modified >= cutoff,
                              let content = try? String(contentsOf: url, encoding: .utf8) else {
                            continue
                        }
                        turns.append(contentsOf: CodexSessionScanner.turnTokens(inTranscript: content, cutoff: cutoff))
                    }
                }
                return CodexSessionScanner.stats(fromTurns: turns, windowDays: windowDays, now: Date())
            }.value

            self.localStats = stats.isEmpty ? nil : stats
        }
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

        var candidates = [(URL, Date)]()
        for case let url as URL in walker where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true, let modified = values?.contentModificationDate else { continue }
            candidates.append((url, modified))
        }

        // A session may end without any usable snapshot (e.g. all-null
        // rate_limits), so look through the few most recent ones.
        for (url, _) in candidates.sorted(by: { $0.1 > $1.1 }).prefix(5) {
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
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
        }
        return nil
    }
}
