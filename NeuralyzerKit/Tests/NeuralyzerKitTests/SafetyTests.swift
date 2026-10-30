import XCTest
@testable import NeuralyzerKit

final class SafetyTests: XCTestCase {
    let home = FakeHome()
    lazy var guardian = SafetyGuard(home: home.url)
    lazy var caches = home.path("Library/Caches")

    func testAllowsChildOfRoot() {
        let u = home.file("Library/Caches/app/blob")
        XCTAssertTrue(guardian.allows(u, root: caches))
    }

    func testRejectsRootItself() {
        home.dir("Library/Caches")
        XCTAssertFalse(guardian.allows(caches, root: caches))
    }

    func testRejectsHome() {
        XCTAssertFalse(guardian.allows(home.url, root: home.url))
    }

    func testRejectsSymlinkLeavingRoot() {
        home.file("Documents/thesis.pdf")
        home.link("Library/Caches/evil", to: "Documents")
        XCTAssertFalse(guardian.allows(home.path("Library/Caches/evil"), root: caches))
    }

    func testRejectsPrefixLookalike() {
        let u = home.file("Library/Caches-other/x")
        XCTAssertFalse(guardian.allows(u, root: caches))
    }

    func testRejectsClaudeMemory() {
        let u = home.dir(".claude/projects/p/memory")
        XCTAssertFalse(guardian.allows(u, root: home.path(".claude/projects")))
    }

    func testRejectsClaudeSettings() {
        let u = home.file(".claude/settings.json")
        XCTAssertFalse(guardian.allows(u, root: home.path(".claude")))
    }

    func testAllowsClaudePluginCache() {
        let u = home.dir(".claude/plugins/cache/some-plugin")
        XCTAssertTrue(guardian.allows(u, root: home.path(".claude/plugins/cache")))
    }
}
