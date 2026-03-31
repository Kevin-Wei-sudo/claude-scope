import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .english:
            return Locale(identifier: "en")
        case .simplifiedChinese:
            return Locale(identifier: "zh-Hans")
        }
    }

    static var stored: AppLanguage {
        from(UserDefaults.standard.string(forKey: storageKey))
    }

    static func from(_ rawValue: String?) -> AppLanguage {
        guard let rawValue, let language = AppLanguage(rawValue: rawValue) else {
            return .system
        }
        return language
    }
}

func localizedString(
    _ key: String,
    fallback: String,
    language: AppLanguage = .stored,
    resourceBundle: Bundle? = claudeScopeResourceBundle()
) -> String {
    guard let resourceBundle else { return fallback }
    return localizationTable(for: language, resourceBundle: resourceBundle)[key]
        ?? localizationTable(for: .english, resourceBundle: resourceBundle)[key]
        ?? fallback
}

func localizedFormat(
    _ key: String,
    fallback: String,
    language: AppLanguage = .stored,
    resourceBundle: Bundle? = claudeScopeResourceBundle(),
    _ arguments: CVarArg...
) -> String {
    let format = localizedString(
        key,
        fallback: fallback,
        language: language,
        resourceBundle: resourceBundle
    )
    return String(format: format, locale: language.locale, arguments: arguments)
}

private func localizedResourceBundle(
    for language: AppLanguage,
    resourceBundle: Bundle?
) -> Bundle? {
    guard let resourceBundle else { return nil }

    let localization = resolvedLocalizationIdentifier(for: language)
    let availableLocalizations = resourceBundle.localizations
    let matchedLocalization = availableLocalizations.first {
        normalizedLocalizationIdentifier($0) == normalizedLocalizationIdentifier(localization)
    } ?? localization

    guard let path = resourceBundle.path(forResource: matchedLocalization, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return resourceBundle
    }

    return bundle
}

private func resolvedLocalizationIdentifier(for language: AppLanguage) -> String {
    switch language {
    case .english:
        return "en"
    case .simplifiedChinese:
        return "zh-Hans"
    case .system:
        let preferredLanguages = Locale.preferredLanguages

        if preferredLanguages.contains(where: { $0.hasPrefix("zh") }) {
            return "zh-Hans"
        }

        let supported = ["en", "zh-Hans"]
        return Bundle.preferredLocalizations(from: supported, forPreferences: preferredLanguages).first ?? "en"
    }
}

private func normalizedLocalizationIdentifier(_ value: String) -> String {
    value
        .replacingOccurrences(of: "_", with: "-")
        .lowercased()
}

private var localizationTableCache = [String: [String: String]]()

private func localizationTable(
    for language: AppLanguage,
    resourceBundle: Bundle
) -> [String: String] {
    let identifier = resolvedLocalizationIdentifier(for: language)
    let cacheKey = resourceBundle.bundleURL.path + "::" + normalizedLocalizationIdentifier(identifier)
    if let cached = localizationTableCache[cacheKey] {
        return cached
    }

    let matchedLocalization = resourceBundle.localizations.first {
        normalizedLocalizationIdentifier($0) == normalizedLocalizationIdentifier(identifier)
    } ?? identifier

    let table: [String: String]
    if let path = resourceBundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: matchedLocalization),
       let dictionary = NSDictionary(contentsOfFile: path) as? [String: String] {
        table = dictionary
    } else {
        table = [:]
    }

    localizationTableCache[cacheKey] = table
    return table
}
