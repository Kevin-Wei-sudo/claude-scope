import Foundation

/// A curated news item about Claude usage-limit policy changes, served from the
/// app repository so it can be updated without shipping a release.
struct Announcement: Codable, Identifiable, Equatable {
    let id: String
    let date: String
    let url: String?
    let title: [String: String]
    let body: [String: String]

    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    func localizedTitle(for language: AppLanguage) -> String {
        localizedField(title, for: language)
    }

    func localizedBody(for language: AppLanguage) -> String {
        localizedField(body, for: language)
    }

    private func localizedField(_ field: [String: String], for language: AppLanguage) -> String {
        let wantsChinese: Bool
        switch language {
        case .simplifiedChinese:
            wantsChinese = true
        case .english:
            wantsChinese = false
        case .system:
            wantsChinese = Locale.preferredLanguages.contains { $0.hasPrefix("zh") }
        }
        if wantsChinese, let zh = field["zh-Hans"] { return zh }
        return field["en"] ?? field.values.first ?? ""
    }
}

struct AnnouncementFeed: Codable, Equatable {
    let announcements: [Announcement]
}

/// The announcement to show as a popover banner: the newest one that is not
/// dismissed and not older than `maxAge`.
func bannerAnnouncement(
    feed: AnnouncementFeed,
    dismissedIDs: Set<String>,
    now: Date,
    maxAge: TimeInterval = 90 * 24 * 60 * 60
) -> Announcement? {
    feed.announcements
        .filter { announcement in
            guard !dismissedIDs.contains(announcement.id) else { return false }
            guard let date = announcement.dateValue else { return false }
            let age = now.timeIntervalSince(date)
            return age >= 0 && age <= maxAge
        }
        .max { ($0.dateValue ?? .distantPast) < ($1.dateValue ?? .distantPast) }
}

/// Announcements that deserve a system notification this sync. The very first
/// sync only records what exists so a fresh install is not spammed with history;
/// afterwards, each unseen id notifies once (newest first, capped by caller).
func announcementsToNotify(
    feed: AnnouncementFeed,
    knownIDs: Set<String>,
    isFirstSync: Bool
) -> [Announcement] {
    guard !isFirstSync else { return [] }
    return feed.announcements
        .filter { !knownIDs.contains($0.id) }
        .sorted { ($0.dateValue ?? .distantPast) > ($1.dateValue ?? .distantPast) }
}
