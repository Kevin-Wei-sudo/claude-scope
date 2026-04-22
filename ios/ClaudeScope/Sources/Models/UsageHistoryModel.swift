import Foundation

struct UsageDataPoint: Codable, Identifiable {
    var id: UUID
    let timestamp: Date
    let pct5h: Double
    let pct7d: Double

    init(timestamp: Date = Date(), pct5h: Double, pct7d: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.pct5h = pct5h
        self.pct7d = pct7d
    }
}

struct UsageHistory: Codable {
    var dataPoints: [UsageDataPoint] = []
}

enum TimeRange: String, CaseIterable, Identifiable {
    case day7 = "7D"
    case day30 = "30D"
    case day90 = "90D"

    var id: String { rawValue }

    var interval: TimeInterval {
        switch self {
        case .day7: return 7 * 86400
        case .day30: return 30 * 86400
        case .day90: return 90 * 86400
        }
    }

    var targetPointCount: Int {
        switch self {
        case .day7: return 7
        case .day30: return 30
        case .day90: return 90
        }
    }
}
