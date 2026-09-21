import Foundation
import Security

/// Where secrets live. The app uses the Keychain; tests use the in-memory
/// implementation so they never touch the user's real keychain.
protocol TokenVault {
    func readData(account: String) -> Data?
    /// Returns false when the vault cannot persist (e.g. keychain locked or
    /// denied) so callers can fall back rather than lose the secret.
    func writeData(_ data: Data, account: String) -> Bool
    func delete(account: String)
}

/// Generic-password items in the login keychain. Verified on macOS 15 that
/// items written by one ad-hoc-signed build remain silently readable by the
/// next build (no ACL prompt), so Sparkle updates do not re-prompt.
struct KeychainTokenVault: TokenVault {
    let service: String

    init(service: String = "io.sandwichlab.claudescope") {
        self.service = service
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func readData(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    func writeData(_ data: Data, account: String) -> Bool {
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrLabel as String] = "ClaudeScope"
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}

/// Test double; also documents the vault contract.
final class InMemoryTokenVault: TokenVault {
    private var storage = [String: Data]()
    /// Set to simulate a keychain that refuses writes.
    var failsWrites = false

    func readData(account: String) -> Data? {
        storage[account]
    }

    func writeData(_ data: Data, account: String) -> Bool {
        guard !failsWrites else { return false }
        storage[account] = data
        return true
    }

    func delete(account: String) {
        storage.removeValue(forKey: account)
    }
}
