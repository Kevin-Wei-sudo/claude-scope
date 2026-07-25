import Foundation
@preconcurrency import UserNotifications

struct ThresholdAlert: Equatable {
    let window: String
    let pct: Int
}

/// Pure logic: returns which threshold alerts should fire given a state transition.
func crossedThresholds(
    threshold5h: Int,
    threshold7d: Int,
    thresholdExtra: Int,
    previous5h: Double,
    previous7d: Double,
    previousExtra: Double,
    current5h: Double,
    current7d: Double,
    currentExtra: Double
) -> [ThresholdAlert] {
    var alerts = [ThresholdAlert]()

    if threshold5h > 0 {
        let t = Double(threshold5h)
        if current5h >= t && previous5h < t {
            alerts.append(ThresholdAlert(window: "5-hour", pct: Int(round(current5h))))
        }
    }

    if threshold7d > 0 {
        let t = Double(threshold7d)
        if current7d >= t && previous7d < t {
            alerts.append(ThresholdAlert(window: "7-day", pct: Int(round(current7d))))
        }
    }

    if thresholdExtra > 0 {
        let t = Double(thresholdExtra)
        if currentExtra >= t && previousExtra < t {
            alerts.append(ThresholdAlert(window: "Extra usage", pct: Int(round(currentExtra))))
        }
    }

    return alerts
}

private class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@MainActor
class NotificationService: ObservableObject {
    /// 0 = off, 5–100 = alert when window reaches this %.
    @Published private(set) var threshold5h: Int
    @Published private(set) var threshold7d: Int
    @Published private(set) var thresholdExtra: Int
    @Published private(set) var resetRemindersEnabled: Bool

    private var previousPct5h: Double?
    private var previousPct7d: Double?
    private var previousPctExtra: Double?
    private var lastSoonReminderWindow: String?
    private var lastCompletionReminderWindow: String?
    private let delegate = NotificationDelegate()

    init() {
        threshold5h = Self.load("notificationThreshold5h")
        threshold7d = Self.load("notificationThreshold7d")
        thresholdExtra = Self.load("notificationThresholdExtra")
        resetRemindersEnabled = UserDefaults.standard.object(forKey: "notificationResetRemindersEnabled") as? Bool ?? true
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = delegate
        }
    }

    func setThreshold5h(_ value: Int) {
        threshold5h = clamp(value)
        UserDefaults.standard.set(threshold5h, forKey: "notificationThreshold5h")
        previousPct5h = nil
        if threshold5h > 0 { requestPermission() }
    }

    func setThreshold7d(_ value: Int) {
        threshold7d = clamp(value)
        UserDefaults.standard.set(threshold7d, forKey: "notificationThreshold7d")
        previousPct7d = nil
        if threshold7d > 0 { requestPermission() }
    }

    func setThresholdExtra(_ value: Int) {
        thresholdExtra = clamp(value)
        UserDefaults.standard.set(thresholdExtra, forKey: "notificationThresholdExtra")
        previousPctExtra = nil
        if thresholdExtra > 0 { requestPermission() }
    }

    func setResetRemindersEnabled(_ enabled: Bool) {
        resetRemindersEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "notificationResetRemindersEnabled")
        if enabled { requestPermission() }
    }

    /// Forget the previous account's levels so a new sign-in does not fire
    /// threshold or reset alerts derived from someone else's usage.
    func resetAccountState() {
        previousPct5h = nil
        previousPct7d = nil
        previousPctExtra = nil
        lastSoonReminderWindow = nil
        lastCompletionReminderWindow = nil
    }

    func requestPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func checkAndNotify(pct5h: Double, pct7d: Double, pctExtra: Double) {
        let current5h = pct5h * 100
        let current7d = pct7d * 100
        let currentExtra = pctExtra * 100

        let prev5h = previousPct5h ?? 0
        let prev7d = previousPct7d ?? 0
        let prevExtra = previousPctExtra ?? 0

        defer {
            previousPct5h = current5h
            previousPct7d = current7d
            previousPctExtra = currentExtra
        }

        let alerts = crossedThresholds(
            threshold5h: threshold5h,
            threshold7d: threshold7d,
            thresholdExtra: thresholdExtra,
            previous5h: prev5h,
            previous7d: prev7d,
            previousExtra: prevExtra,
            current5h: current5h,
            current7d: current7d,
            currentExtra: currentExtra
        )

        for alert in alerts {
            sendNotification(window: alert.window, pct: alert.pct)
        }
    }

    func checkResetReminders(reset5h: Date?, reset7d: Date?, now: Date = Date()) {
        guard resetRemindersEnabled else { return }

        checkResetReminder(window: "5-hour", resetDate: reset5h, now: now)
        checkResetReminder(window: "7-day", resetDate: reset7d, now: now)
    }

    private func sendNotification(window: String, pct: Int) {
        guard Bundle.main.bundleIdentifier != nil else {
            print("[Notification] \(window) usage has reached \(pct)% (no bundle – skipped)")
            return
        }

        let localizedWindow = localizedNotificationWindow(window)
        let content = UNMutableNotificationContent()
        content.title = localizedString("notification.title", fallback: "ClaudeScope")
        content.body = localizedFormat(
            "notification.body",
            fallback: "%@ usage has reached %d%%",
            localizedWindow,
            pct
        )
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "usage-\(window)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notification] Failed to deliver: \(error)")
            } else {
                print("[Notification] Delivered: \(window) at \(pct)%")
            }
        }
    }

    private func checkResetReminder(window: String, resetDate: Date?, now: Date) {
        guard let resetDate else { return }

        let secondsUntilReset = resetDate.timeIntervalSince(now)
        if secondsUntilReset <= 0 {
            if lastCompletionReminderWindow != window {
                sendSimpleNotification(
                    identifier: "reset-now-\(window)",
                    titleKey: "notification.reset_now.title",
                    titleFallback: "Budget reset",
                    bodyKey: "notification.reset_now.body",
                    bodyFallback: "%@ has reset.",
                    bodyArguments: [localizedNotificationWindow(window)]
                )
                lastCompletionReminderWindow = window
                lastSoonReminderWindow = nil
            }
            return
        }

        if secondsUntilReset <= 30 * 60 && lastSoonReminderWindow != window {
            sendSimpleNotification(
                identifier: "reset-soon-\(window)",
                titleKey: "notification.reset_soon.title",
                titleFallback: "Reset soon",
                bodyKey: "notification.reset_soon.body",
                bodyFallback: "%@ resets in about 30 minutes.",
                bodyArguments: [localizedNotificationWindow(window)]
            )
            lastSoonReminderWindow = window
            lastCompletionReminderWindow = nil
        }
    }

    private func sendSimpleNotification(
        identifier: String,
        titleKey: String,
        titleFallback: String,
        bodyKey: String,
        bodyFallback: String,
        bodyArguments: [CVarArg]
    ) {
        guard Bundle.main.bundleIdentifier != nil else { return }

        let content = UNMutableNotificationContent()
        content.title = localizedString(titleKey, fallback: titleFallback)
        let format = localizedString(bodyKey, fallback: bodyFallback)
        content.body = String(format: format, locale: AppLanguage.stored.locale, arguments: bodyArguments)
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func clamp(_ value: Int) -> Int {
        max(0, min(100, value))
    }

    private static func load(_ key: String) -> Int {
        let value = UserDefaults.standard.integer(forKey: key)
        return max(0, min(100, value))
    }

    private func localizedNotificationWindow(_ window: String) -> String {
        switch window {
        case "5-hour":
            return localizedString("window.5hour", fallback: "5-hour window")
        case "7-day":
            return localizedString("window.7day", fallback: "7-day window")
        case "Extra usage":
            return localizedString("window.extra", fallback: "Extra usage")
        default:
            return window
        }
    }
}
