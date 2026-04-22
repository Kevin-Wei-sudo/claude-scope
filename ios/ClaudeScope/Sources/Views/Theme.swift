import SwiftUI

enum Theme {
    // Primary colors from design
    static let teal = Color(red: 0.18, green: 0.55, blue: 0.50)        // #2D8C7F
    static let tealLight = Color(red: 0.85, green: 0.93, blue: 0.91)   // Light teal for backgrounds
    static let tealDark = Color(red: 0.12, green: 0.40, blue: 0.36)    // Darker teal

    static let terracotta = Color(red: 0.80, green: 0.42, blue: 0.29)  // #CC6B49
    static let terracottaLight = Color(red: 0.93, green: 0.82, blue: 0.75)
    static let terracottaDark = Color(red: 0.60, green: 0.30, blue: 0.18)

    // Neutral colors
    static let background = Color(red: 0.98, green: 0.97, blue: 0.95)  // Warm off-white
    static let cardBackground = Color.white
    static let sectionHeader = Color(red: 0.45, green: 0.42, blue: 0.40)
    static let bodyText = Color(red: 0.20, green: 0.20, blue: 0.20)
    static let subtitleText = Color(red: 0.55, green: 0.52, blue: 0.50)

    // Bar chart colors
    static let barDefault = Theme.terracotta
    static let barLatest = Theme.teal

    // Card styling
    static let cardCornerRadius: CGFloat = 16
    static let cardShadow: CGFloat = 2

    static func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .tracking(2)
            .textCase(.uppercase)
            .foregroundStyle(Theme.teal)
    }
}

// MARK: - Reusable Components

struct LanguageToggle: View {
    @Binding var language: AppLanguage

    var body: some View {
        HStack(spacing: 4) {
            toggleButton("EN", isSelected: language.isEnglish) {
                language = .english
                UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
                AnalyticsService.shared.trackLanguageChanged("en")
            }
            toggleButton("中文", isSelected: !language.isEnglish) {
                language = .simplifiedChinese
                UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
                AnalyticsService.shared.trackLanguageChanged("zh-Hans")
            }
        }
    }

    private func toggleButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.teal : Color.clear)
                .foregroundStyle(isSelected ? .white : Theme.bodyText)
                .clipShape(Capsule())
        }
    }
}

struct UsageProgressBar: View {
    let value: Double // 0-1
    var tint: Color = Theme.teal
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.15))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
    }
}

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .shadow(color: .black.opacity(0.04), radius: Theme.cardShadow, y: 1)
    }
}

struct PillSelector<T: Hashable & CustomStringConvertible>: View {
    let options: [T]
    @Binding var selected: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    selected = option
                } label: {
                    Text(option.description)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selected == option ? Theme.teal : Color.clear)
                        .foregroundStyle(selected == option ? .white : Theme.bodyText)
                }
            }
        }
        .background(Color.gray.opacity(0.1))
        .clipShape(Capsule())
    }
}
