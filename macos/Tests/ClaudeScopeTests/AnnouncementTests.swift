import XCTest
@testable import ClaudeScope

final class AnnouncementTests: XCTestCase {
    private func makeAnnouncement(id: String, date: String) -> Announcement {
        Announcement(
            id: id,
            date: date,
            url: "https://example.com",
            title: ["en": "Title EN", "zh-Hans": "标题"],
            body: ["en": "Body EN", "zh-Hans": "正文"]
        )
    }

    func testFeedDecodesFromRepoFormat() throws {
        let json = """
        {
          "announcements": [
            {
              "id": "2026-05-06-5h-limits-doubled",
              "date": "2026-05-06",
              "url": "https://www.anthropic.com/news/higher-limits-spacex",
              "title": {"en": "Limits doubled", "zh-Hans": "额度翻倍"},
              "body": {"en": "Details here.", "zh-Hans": "详情。"}
            }
          ]
        }
        """
        let feed = try JSONDecoder().decode(AnnouncementFeed.self, from: Data(json.utf8))

        XCTAssertEqual(feed.announcements.count, 1)
        XCTAssertEqual(feed.announcements.first?.id, "2026-05-06-5h-limits-doubled")
        XCTAssertEqual(feed.announcements.first?.localizedTitle(for: .simplifiedChinese), "额度翻倍")
        XCTAssertEqual(feed.announcements.first?.localizedTitle(for: .english), "Limits doubled")
        XCTAssertNotNil(feed.announcements.first?.dateValue)
    }

    func testBannerPicksNewestUndismissedWithinMaxAge() {
        let now = ISO8601DateFormatter().date(from: "2026-07-17T00:00:00Z")!
        let feed = AnnouncementFeed(announcements: [
            makeAnnouncement(id: "old", date: "2026-01-01"),      // beyond 90 days
            makeAnnouncement(id: "may", date: "2026-05-06"),
            makeAnnouncement(id: "june", date: "2026-06-20"),
            makeAnnouncement(id: "future", date: "2026-12-01"),   // not yet effective
        ])

        XCTAssertEqual(bannerAnnouncement(feed: feed, dismissedIDs: [], now: now)?.id, "june")
        XCTAssertEqual(bannerAnnouncement(feed: feed, dismissedIDs: ["june"], now: now)?.id, "may")
        XCTAssertNil(bannerAnnouncement(feed: feed, dismissedIDs: ["june", "may"], now: now))
    }

    func testFirstSyncRecordsWithoutNotifying() {
        let feed = AnnouncementFeed(announcements: [makeAnnouncement(id: "a", date: "2026-07-01")])

        XCTAssertTrue(announcementsToNotify(feed: feed, knownIDs: [], isFirstSync: true).isEmpty)
        XCTAssertEqual(
            announcementsToNotify(feed: feed, knownIDs: [], isFirstSync: false).map(\.id),
            ["a"]
        )
        XCTAssertTrue(announcementsToNotify(feed: feed, knownIDs: ["a"], isFirstSync: false).isEmpty)
    }

    func testNotifyOrderIsNewestFirst() {
        let feed = AnnouncementFeed(announcements: [
            makeAnnouncement(id: "older", date: "2026-06-01"),
            makeAnnouncement(id: "newer", date: "2026-07-01"),
        ])

        XCTAssertEqual(
            announcementsToNotify(feed: feed, knownIDs: [], isFirstSync: false).map(\.id),
            ["newer", "older"]
        )
    }
}
