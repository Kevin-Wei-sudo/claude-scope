import Foundation

/// Claude Code session scratchpads live at
/// `/private/tmp/claude-<uid>/<munged-project-path>/<session-uuid>/scratchpad/…`
/// and often contain git worktrees (`wt-trend`, …). Work done there — e.g.
/// Codex invoked by a Claude session — belongs to the host project, not to an
/// ephemeral directory name.
enum ProjectNameResolver {
    /// The munged host-project segment when `path` points inside a session
    /// scratchpad; nil for ordinary paths.
    static func scratchpadHostSegment(inPath path: String) -> String? {
        let components = path.split(separator: "/").map(String.init)
        guard components.contains("scratchpad"),
              let claudeIndex = components.firstIndex(where: { component in
                  component.hasPrefix("claude-") && component.dropFirst("claude-".count).allSatisfy(\.isNumber)
              }),
              claudeIndex + 1 < components.count else {
            return nil
        }
        return components[claudeIndex + 1]
    }

    /// Munging replaces both `/` and `_` with `-`, so exact recovery is
    /// impossible — but the segment always *ends* with the project directory
    /// name, which suffix-matching against projects seen elsewhere recovers.
    /// Longest match wins so nested checkouts resolve to the deepest name.
    static func hostProject(forMungedSegment segment: String, knownProjects: some Collection<String>) -> String? {
        let normalizedSegment = normalized(segment)
        return knownProjects
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
            .first { normalizedSegment.hasSuffix("-" + normalized($0)) }
    }

    private static func normalized(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: "-").lowercased()
    }
}
