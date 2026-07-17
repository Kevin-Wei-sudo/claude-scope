import Foundation
import Combine
@preconcurrency import UserNotifications

@MainActor
final class AnnouncementService: ObservableObject {
    @Published private(set) var banner: Announcement?

    static let feedURL = URL(string: "https://raw.githubusercontent.com/Kevin-Wei-sudo/claude-scope/main/announcements/announcements.json")!
    private static let refreshInterval: TimeInterval = 6 * 60 * 60
    private static let knownIDsKey = "announcementKnownIDs"
    private static let dismissedIDsKey = "announcementDismissedIDs"
    private static let didFirstSyncKey = "announcementDidFirstSync"

    private var refreshTimer: AnyCancellable?
    private var latestFeed: AnnouncementFeed?

    func start() {
        refreshTimer = Timer.publish(every: Self.refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.sync() }
            }
        Task { await sync() }
    }

    func dismiss(_ announcement: Announcement) {
        var dismissed = Self.loadIDs(Self.dismissedIDsKey)
        dismissed.insert(announcement.id)
        Self.saveIDs(dismissed, key: Self.dismissedIDsKey)
        refreshBanner()
    }

    func sync() async {
        var request = URLRequest(url: Self.feedURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let feed = try? JSONDecoder().decode(AnnouncementFeed.self, from: data) else {
            return
        }

        latestFeed = feed

        let isFirstSync = !UserDefaults.standard.bool(forKey: Self.didFirstSyncKey)
        var known = Self.loadIDs(Self.knownIDsKey)

        let toNotify = announcementsToNotify(feed: feed, knownIDs: known, isFirstSync: isFirstSync)
        if let newest = toNotify.first {
            sendNotification(for: newest)
        }

        known.formUnion(feed.announcements.map(\.id))
        Self.saveIDs(known, key: Self.knownIDsKey)
        UserDefaults.standard.set(true, forKey: Self.didFirstSyncKey)

        refreshBanner()
    }

    private func refreshBanner() {
        guard let feed = latestFeed else { return }
        banner = bannerAnnouncement(
            feed: feed,
            dismissedIDs: Self.loadIDs(Self.dismissedIDsKey),
            now: Date()
        )
    }

    private func sendNotification(for announcement: Announcement) {
        guard Bundle.main.bundleIdentifier != nil else { return }

        let language = AppLanguage.stored
        let content = UNMutableNotificationContent()
        content.title = announcement.localizedTitle(for: language)
        content.body = announcement.localizedBody(for: language)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "announcement-\(announcement.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func loadIDs(_ key: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    private static func saveIDs(_ ids: Set<String>, key: String) {
        UserDefaults.standard.set(Array(ids).sorted(), forKey: key)
    }
}
