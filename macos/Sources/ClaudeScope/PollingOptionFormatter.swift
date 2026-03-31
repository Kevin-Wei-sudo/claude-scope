import Foundation

func isDiscouragedPollingOption(_ minutes: Int) -> Bool {
    minutes == 5 || minutes == 15
}

func pollingOptionLabel(
    for minutes: Int,
    locale: Locale = AppLanguage.stored.locale,
    resourceBundle: Bundle? = claudeScopeResourceBundle()
) -> String {
    let interval = localizedPollingInterval(for: minutes, locale: locale)
    guard isDiscouragedPollingOption(minutes) else {
        return interval
    }

    let fallbackFormat = "%@ (not recommended)"
    let format = localizedString(
        "polling.option.not_recommended",
        fallback: fallbackFormat,
        language: .stored,
        resourceBundle: resourceBundle
    )
    return String(format: format, locale: locale, interval)
}

func localizedPollingInterval(for minutes: Int, locale: Locale) -> String {
    if locale.identifier.hasPrefix("zh") {
        if minutes < 60 {
            return "\(minutes)分钟"
        }
        let hours = minutes / 60
        return "\(hours)小时"
    }

    let measurement: Measurement<UnitDuration>
    if minutes < 60 {
        measurement = Measurement(value: Double(minutes), unit: .minutes)
    } else {
        measurement = Measurement(value: Double(minutes) / 60.0, unit: .hours)
    }

    return measurement.formatted(
        .measurement(
            width: .narrow,
            usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0)).locale(locale)
        )
    )
}
