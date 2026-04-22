import Foundation

/// Copies UserDefaults that were written under the old bundle identifier
/// (`com.local.ClaudeScope`) into the current app's standard defaults.
///
/// Runs at most once per install. Only copies keys that aren't already set in
/// the new domain, so user changes made post-upgrade are never overwritten.
///
/// Sandboxed App Store builds can't read another bundle's plist — in that case
/// `persistentDomain(forName:)` returns nil and migration no-ops.
enum UserDefaultsMigration {
    static let migrationFlagKey = "io.sandwichlab.claudescope.userDefaults.migratedFromComLocal"
    static let legacyDomain = "com.local.ClaudeScope"

    static func runIfNeeded(defaults: UserDefaults = .standard) {
        if defaults.bool(forKey: migrationFlagKey) { return }

        guard let legacy = defaults.persistentDomain(forName: legacyDomain), !legacy.isEmpty else {
            defaults.set(true, forKey: migrationFlagKey)
            return
        }

        for (key, value) in legacy {
            if isSystemKey(key) { continue }
            if defaults.object(forKey: key) != nil { continue }
            defaults.set(value, forKey: key)
        }

        defaults.set(true, forKey: migrationFlagKey)
    }

    private static func isSystemKey(_ key: String) -> Bool {
        key.hasPrefix("Apple") || key.hasPrefix("NSGlobal") || key.hasPrefix("com.apple.")
    }
}
