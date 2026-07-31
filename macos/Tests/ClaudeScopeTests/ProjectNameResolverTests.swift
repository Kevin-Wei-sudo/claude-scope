import XCTest
@testable import ClaudeScope

final class ProjectNameResolverTests: XCTestCase {
    private let scratchpadPath =
        "/private/tmp/claude-501/-Users-dabuniu-lexi-project-lanbow-admin-lanbow-admin/afb56d03-ea1c/scratchpad/wt-trend"

    func testDetectsScratchpadPathsAndExtractsMungedSegment() {
        XCTAssertEqual(
            ProjectNameResolver.scratchpadHostSegment(inPath: scratchpadPath),
            "-Users-dabuniu-lexi-project-lanbow-admin-lanbow-admin"
        )
    }

    func testOrdinaryPathsAreNotScratchpads() {
        XCTAssertNil(ProjectNameResolver.scratchpadHostSegment(inPath: "/Users/me/lanbow-admin"))
        // "claude-code" is not a claude-<uid> runtime directory.
        XCTAssertNil(ProjectNameResolver.scratchpadHostSegment(inPath: "/private/tmp/claude-code/x/scratchpad/y"))
        // A scratchpad-less session path is not enough.
        XCTAssertNil(ProjectNameResolver.scratchpadHostSegment(inPath: "/private/tmp/claude-501/-Users-x/abc/tasks/t.out"))
    }

    func testSuffixMatchRecoversHostProject() {
        let segment = "-Users-dabuniu-lexi-project-lanbow-admin-lanbow-admin"

        XCTAssertEqual(
            ProjectNameResolver.hostProject(forMungedSegment: segment, knownProjects: ["monitor", "lanbow-admin"]),
            "lanbow-admin"
        )
        XCTAssertNil(
            ProjectNameResolver.hostProject(forMungedSegment: segment, knownProjects: ["monitor"])
        )
    }

    func testSuffixMatchNormalizesUnderscores() {
        // Munging turns underscores into dashes; the real directory keeps them.
        let segment = "-Users-dabuniu-lexi-project-sandwich-core-sandwichlab-core"

        XCTAssertEqual(
            ProjectNameResolver.hostProject(forMungedSegment: segment, knownProjects: ["sandwichlab_core"]),
            "sandwichlab_core"
        )
    }

    func testLongestKnownProjectWins() {
        let segment = "-Users-x-claude-usage-bar-claude-usage-bar"

        XCTAssertEqual(
            ProjectNameResolver.hostProject(forMungedSegment: segment, knownProjects: ["bar", "claude-usage-bar"]),
            "claude-usage-bar"
        )
    }
}
