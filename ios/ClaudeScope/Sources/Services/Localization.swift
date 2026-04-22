import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static let storageKey = "appLanguage"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .english: return Locale(identifier: "en")
        case .simplifiedChinese: return Locale(identifier: "zh-Hans")
        }
    }

    var isEnglish: Bool {
        switch self {
        case .english: return true
        case .simplifiedChinese: return false
        case .system:
            return !Locale.preferredLanguages.contains(where: { $0.hasPrefix("zh") })
        }
    }

    static var stored: AppLanguage {
        from(UserDefaults.standard.string(forKey: storageKey))
    }

    static func from(_ rawValue: String?) -> AppLanguage {
        guard let rawValue, let language = AppLanguage(rawValue: rawValue) else { return .system }
        return language
    }
}

// MARK: - Localization helpers

enum L10n {
    static func string(_ key: String, fallback: String, language: AppLanguage = .stored) -> String {
        guard let bundle = resourceBundle() else { return fallback }
        return localizationTable(for: language, bundle: bundle)[key]
            ?? localizationTable(for: .english, bundle: bundle)[key]
            ?? fallback
    }

    static func format(_ key: String, fallback: String, _ arguments: CVarArg...) -> String {
        let language = AppLanguage.stored
        let format = string(key, fallback: fallback, language: language)
        return String(format: format, locale: language.locale, arguments: arguments)
    }

    private static func resourceBundle() -> Bundle? {
        // Look for resource bundle in main bundle
        if let url = Bundle.main.url(forResource: "ClaudeScope_ClaudeScope", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return Bundle.main
    }

    private static var cache = [String: [String: String]]()

    private static func localizationTable(for language: AppLanguage, bundle: Bundle) -> [String: String] {
        let identifier = resolvedIdentifier(for: language)
        let cacheKey = bundle.bundleURL.path + "::" + identifier
        if let cached = cache[cacheKey] { return cached }

        let matchedLocalization = bundle.localizations.first {
            $0.replacingOccurrences(of: "_", with: "-").lowercased() == identifier.lowercased()
        } ?? identifier

        let table: [String: String]
        if let path = bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: matchedLocalization),
           let dictionary = NSDictionary(contentsOfFile: path) as? [String: String] {
            table = dictionary
        } else {
            table = [:]
        }
        cache[cacheKey] = table
        return table
    }

    private static func resolvedIdentifier(for language: AppLanguage) -> String {
        switch language {
        case .english: return "en"
        case .simplifiedChinese: return "zh-Hans"
        case .system:
            if Locale.preferredLanguages.contains(where: { $0.hasPrefix("zh") }) { return "zh-Hans" }
            return Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: Locale.preferredLanguages).first ?? "en"
        }
    }
}
