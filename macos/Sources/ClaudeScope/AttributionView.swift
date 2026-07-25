import SwiftUI

struct AttributionView: View {
    @ObservedObject var service: AttributionService

    var body: some View {
        ScrollView {
            AttributionContentView(service: service)
        }
        .frame(width: 460, height: 560)
        .onAppear { service.refreshIfStale() }
    }
}

/// Split out of the scroll view so it can be laid out — and snapshot-checked —
/// on its own.
struct AttributionContentView: View {
    @ObservedObject var service: AttributionService
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var language: AppLanguage { AppLanguage.from(appLanguageRaw) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
                header

                if let reason = service.unavailableReason, service.snapshot?.isEmpty ?? true {
                    unavailableView(reason)
                } else if let snapshot = service.snapshot, !snapshot.isEmpty {
                    contextInsight(snapshot)
                    compositionSection(snapshot)
                    section(
                        title: localizedString("attribution.by_project", fallback: "By project", language: language),
                        entries: snapshot.projects,
                        showContext: true
                    )
                    section(
                        title: localizedString("attribution.by_session", fallback: "By session (single task)", language: language),
                        entries: snapshot.sessions,
                        showContext: true
                    )
                    section(
                        title: localizedString("attribution.by_model", fallback: "By model", language: language),
                        entries: snapshot.models,
                        showContext: false
                    )
                    footnote(snapshot)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
        .padding(16)
        .frame(width: 460)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedString("attribution.title", fallback: "Usage Attribution", language: language))
                    .font(.headline)
                Text(localizedString(
                    "attribution.subtitle",
                    fallback: "Where your Claude Code usage went in the last 7 days",
                    language: language
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if service.isScanning {
                ProgressView().controlSize(.small)
            } else {
                Button(localizedString("button.refresh", fallback: "Refresh", language: language)) {
                    service.refresh()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
    }

    private func unavailableText(_ reason: AttributionService.UnavailableReason) -> String {
        switch reason {
        case .sandboxed:
            return localizedString(
                "attribution.unavailable.sandboxed",
                fallback: "The App Store build cannot read Claude Code's local transcripts. Use the direct download or Homebrew build for attribution.",
                language: language
            )
        case .noTranscripts:
            return localizedString(
                "attribution.unavailable.no_data",
                fallback: "No Claude Code sessions found on this Mac in the last 7 days.",
                language: language
            )
        }
    }

    private func unavailableView(_ reason: AttributionService.UnavailableReason) -> some View {
        Label(unavailableText(reason), systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)
    }

    private func contextInsight(_ snapshot: AttributionSnapshot) -> some View {
        let outputShare = snapshot.composition.first { $0.key == "output" }?.share ?? 0
        let cacheShare = snapshot.composition
            .filter { $0.key == "cache_read" || $0.key == "cache_write" }
            .reduce(0) { $0 + $1.share }

        return VStack(alignment: .leading, spacing: 4) {
            Text(localizedString(
                "attribution.insight.title",
                fallback: "Context is what costs you",
                language: language
            ))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.purple)

            Text(localizedFormat(
                "attribution.insight.body",
                fallback: "%d%% of your usage is context carried into each request (average %@ tokens per turn); only %d%% is the text Claude actually wrote. Clearing long sessions is the fastest way to slow this down.",
                language: language,
                Int(round(cacheShare * 100)),
                formatTokenCount(snapshot.averageContextTokens),
                Int(round(outputShare * 100))
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func compositionSection(_ snapshot: AttributionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizedString("attribution.composition", fallback: "Cost composition", language: language))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(snapshot.composition, id: \.key) { part in
                        Rectangle()
                            .fill(color(forComposition: part.key))
                            .frame(width: max(2, geo.size.width * part.share))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 12)

            HStack(spacing: 10) {
                ForEach(snapshot.composition, id: \.key) { part in
                    HStack(spacing: 3) {
                        Circle().fill(color(forComposition: part.key)).frame(width: 6, height: 6)
                        Text("\(compositionLabel(part.key)) \(Int(round(part.share * 100)))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func section(title: String, entries: [AttributionEntry], showContext: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(entry.label)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(Int(round(entry.share * 100)))%")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    ProgressView(value: entry.share, total: 1.0)
                        .tint(.blue)
                    if showContext {
                        Text(localizedFormat(
                            "attribution.entry.detail",
                            fallback: "%d turns · avg context %@",
                            language: language,
                            entry.turns,
                            formatTokenCount(entry.averageContextTokens)
                        ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func footnote(_ snapshot: AttributionSnapshot) -> some View {
        Text(localizedFormat(
            "attribution.footnote",
            fallback: "Based on %d local Claude Code turns. Subagents account for %d%%. Web and mobile usage is not included, and shares are relative weights, not billed amounts.",
            language: language,
            snapshot.turns,
            Int(round(snapshot.subagentShare * 100))
        ))
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func color(forComposition key: String) -> Color {
        switch key {
        case "cache_read": return .orange
        case "cache_write": return .yellow
        case "output": return .blue
        default: return .gray
        }
    }

    private func compositionLabel(_ key: String) -> String {
        switch key {
        case "cache_read":
            return localizedString("attribution.part.cache_read", fallback: "Context re-read", language: language)
        case "cache_write":
            return localizedString("attribution.part.cache_write", fallback: "Context cached", language: language)
        case "output":
            return localizedString("attribution.part.output", fallback: "Output", language: language)
        default:
            return localizedString("attribution.part.input", fallback: "Input", language: language)
        }
    }
}
