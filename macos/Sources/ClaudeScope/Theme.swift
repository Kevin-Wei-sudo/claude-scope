import SwiftUI

/// One place for the app's visual language, so every surface (bars, chart,
/// badges, menu bar icon) speaks the same palette.
enum Theme {
    /// Claude brand accent — warm clay. Used for the 5h series and hero number.
    static let claude = Color(red: 0.85, green: 0.47, blue: 0.34)
    /// Codex accent.
    static let codex = Color.teal
    /// 7-day series companion color, distinguishable from the accent.
    static let sevenDay = Color.indigo

    /// Utilization semantics, consistent across bars, badges and the icon.
    static func utilization(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.60: return .green
        case 0.60..<0.80: return .orange
        default: return .red
        }
    }

    static let cardRadius: CGFloat = 10
}

/// Subtle rounded card that groups a section — the popover reads as stacked
/// widgets instead of a divider-separated list.
struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

/// Small icon + title line used at the top of a card.
struct SectionHeader: View {
    let symbol: String
    let title: String
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

/// The app's progress bar: capsule track, gradient fill, and an optional
/// time-elapsed caret drawn as part of the bar rather than floating over it.
struct UsageBarView: View {
    /// 0...1 fill.
    let fraction: Double
    var tint: Color? = nil
    /// 0...1 position of the time-elapsed caret; nil hides it.
    var markerFraction: Double? = nil
    var height: CGFloat = 8

    private var fillColor: Color {
        tint ?? Theme.utilization(fraction)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary.opacity(0.6))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [fillColor.opacity(0.75), fillColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, geo.size.width * min(max(fraction, 0), 1)))
                    .animation(.snappy(duration: 0.3), value: fraction)

                if let markerFraction {
                    let x = min(max(geo.size.width * markerFraction, 4), geo.size.width - 4)
                    VStack(spacing: 0) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 6, weight: .bold))
                        RoundedRectangle(cornerRadius: 1)
                            .frame(width: 2, height: height + 2)
                    }
                    .foregroundStyle(Color.primary.opacity(0.75))
                    .position(x: x, y: height / 2 - 3)
                }
            }
        }
        .frame(height: height)
        // Give the caret room to poke above the track without clipping.
        .padding(.top, markerFraction == nil ? 0 : 7)
    }
}
