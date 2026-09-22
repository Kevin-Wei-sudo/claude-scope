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

/// Generic-password items in the login keychain.
///
/// Items are created with a decrypt ACL open to any application. With an
/// ad-hoc signed app the default ACL pins the creating build's cdhash, which
/// re-prompts after every Sparkle update (observed in production on v0.5.0);
/// the open ACL matches the protection of the previous 0600 file — any
/// process of the same user — while keeping at-rest encryption, backup
/// exclusion and Keychain Access visibility. Tighten to an app-bound ACL
/// once the app ships with a stable Developer ID identity.
final class KeychainTokenVault: TokenVault {
    let service: String
    private var convergedAccounts = Set<String>()

    init(service: String = "io.sandwichlab.claudescope") {
        self.service = service
    }

    private func makeOpenAccess() -> SecAccess? {
        var access: SecAccess?
        guard SecAccessCreate("ClaudeScope" as CFString, nil, &access) == errSecSuccess,
              let access else {
            return nil
        }
        if let acls = SecAccessCopyMatchingACLList(access, kSecACLAuthorizationDecrypt) as? [SecACL] {
            for acl in acls {
                var applications: CFArray?
                var description: CFString?
                var promptSelector = SecKeychainPromptSelector()
                guard SecACLCopyContents(acl, &applications, &description, &promptSelector) == errSecSuccess else {
                    continue
                }
                // nil application list = any application may use this key.
                SecACLSetContents(acl, nil, description ?? "ClaudeScope" as CFString, promptSelector)
            }
        }
        return access
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
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        // Items written before the open ACL existed are pinned to an old
        // build's cdhash; rewrite once per launch so they stop prompting.
        if !convergedAccounts.contains(account) {
            convergedAccounts.insert(account)
            _ = writeData(data, account: account)
        }
        return data
    }

    func writeData(_ data: Data, account: String) -> Bool {
        // Delete + add (rather than update) so the item always carries the
        // current ACL policy.
        SecItemDelete(baseQuery(account: account) as CFDictionary)

        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrLabel as String] = "ClaudeScope"
        if let access = makeOpenAccess() {
            query[kSecAttrAccess as String] = access
        }
        let added = SecItemAdd(query as CFDictionary, nil) == errSecSuccess
        if added { convergedAccounts.insert(account) }
        return added
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
