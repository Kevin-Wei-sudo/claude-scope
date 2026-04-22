import Foundation
@preconcurrency import UserNotifications

struct ThresholdAlert: Equatable {
    let window: String
    let pct: Int
}

func crossedThresholds(
    threshold5h: Int, threshold7d: Int, thresholdExtra: Int,
    previous5h: Double, previous7d: Double, previousExtra: Double,
    current5h: Double, current7d: Double, currentExtra: Double
) -> [ThresholdAlert] {
    var alerts = [ThresholdAlert]()
    if threshold5h > 0 { let t = Double(threshold5h); if current5h >= t && previous5h < t { alerts.append(ThresholdAlert(window: "5-hour", pct: Int(round(current5h)))) } }
    if threshold7d > 0 { let t = Double(threshold7d); if current7d >= t && previous7d < t { alerts.append(ThresholdAlert(window: "7-day", pct: Int(round(current7d)))) } }
    if thresholdExtra > 0 { let t = Double(thresholdExtra); if currentExtra >= t && previousExtra < t { alerts.append(ThresholdAlert(window: "Extra usage", pct: Int(round(currentExtra)))) } }
    return alerts
}

@MainActor
class NotificationService: ObservableObject {
    @Published private(set) var threshold5h: Int
    @Published private(set) var threshold7d: Int
    @Published private(set) var thresholdExtra: Int
    @Published private(set) var resetRemindersEnabled: Bool
    @Published var alertsEnabled: Bool {
        didSet { UserDefaults.standard.set(alertsEnabled, forKey: "notificationAlertsEnabled") }
    }
    @Published var warnThreshold: Int {
        didSet {
            UserDefaults.standard.set(warnThreshold, forKey: "notificationWarnThreshold")
            setThreshold5h(warnThreshold)
            setThreshold7d(warnThreshold)
        }
    }

    private var previousPct5h: Double?
    private var previousPct7d: Double?
    private var previousPctExtra: Double?
    private var lastSoonReminderWindow: String?
    private var lastCompletionReminderWindow: String?

    init() {
        threshold5h = Self.load("notificationThreshold5h")
        threshold7d = Self.load("notificationThreshold7d")
        thresholdExtra = Self.load("notificationThresholdExtra")
        resetRemindersEnabled = UserDefaults.standard.object(forKey: "notificationResetRemindersEnabled") as? Bool ?? true
        alertsEnabled = UserDefaults.standard.object(forKey: "notificationAlertsEnabled") as? Bool ?? true
        warnThreshold = UserDefaults.standard.object(forKey: "notificationWarnThreshold") as? Int ?? 80
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

    func setResetRemindersEnabled(_ enabled: Bool) {
        resetRemindersEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "notificationResetRemindersEnabled")
        if enabled { requestPermission() }
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func checkAndNotify(pct5h: Double, pct7d: Double, pctExtra: Double) {
        guard alertsEnabled else { return }
        let current5h = pct5h * 100, current7d = pct7d * 100, currentExtra = pctExtra * 100
        let prev5h = previousPct5h ?? 0, prev7d = previousPct7d ?? 0, prevExtra = previousPctExtra ?? 0
        defer { previousPct5h = current5h; previousPct7d = current7d; previousPctExtra = currentExtra }
        let alerts = crossedThresholds(threshold5h: threshold5h, threshold7d: threshold7d, thresholdExtra: thresholdExtra,
                                        previous5h: prev5h, previous7d: prev7d, previousExtra: prevExtra,
                                        current5h: current5h, current7d: current7d, currentExtra: currentExtra)
        for alert in alerts { sendNotification(window: alert.window, pct: alert.pct) }
    }

    func checkResetReminders(reset5h: Date?, reset7d: Date?, now: Date = Date()) {
        guard resetRemindersEnabled else { return }
        checkResetReminder(window: "5-hour", resetDate: reset5h, now: now)
        checkResetReminder(window: "7-day", resetDate: reset7d, now: now)
    }

    private func sendNotification(window: String, pct: Int) {
        let content = UNMutableNotificationContent()
        content.title = "ClaudeScope"
        content.body = L10n.format("notification.body", fallback: "%@ usage has reached %d%%", window, pct)
        content.sound = .default
        let request = UNNotificationRequest(identifier: "usage-\(window)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func checkResetReminder(window: String, resetDate: Date?, now: Date) {
        guard let resetDate else { return }
        let secondsUntilReset = resetDate.timeIntervalSince(now)
        if secondsUntilReset <= 0 {
            if lastCompletionReminderWindow != window {
                sendSimpleNotification(identifier: "reset-now-\(window)", title: "Budget reset", body: "\(window) has reset.")
                lastCompletionReminderWindow = window; lastSoonReminderWindow = nil
            }
            return
        }
        if secondsUntilReset <= 30 * 60 && lastSoonReminderWindow != window {
            sendSimpleNotification(identifier: "reset-soon-\(window)", title: "Reset soon", body: "\(window) resets in about 30 minutes.")
            lastSoonReminderWindow = window; lastCompletionReminderWindow = nil
        }
    }

    private func sendSimpleNotification(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    private func clamp(_ value: Int) -> Int { max(0, min(100, value)) }
    private static func load(_ key: String) -> Int { max(0, min(100, UserDefaults.standard.integer(forKey: key))) }
}
