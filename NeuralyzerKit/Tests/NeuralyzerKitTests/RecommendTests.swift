import XCTest
@testable import NeuralyzerKit

final class RecommendTests: XCTestCase {
    private func item(_ id: String, _ c: CategoryID, bytes: Int64 = 100, action: Action = .delete, preselected: Bool = true) -> Item {
        Item(id: id, category: c, name: id, url: URL(fileURLWithPath: "/\(id)"), root: URL(fileURLWithPath: "/"), bytes: bytes,
             action: action, preselected: preselected)
    }

    private func results(_ items: [Item]) -> [CategoryResult] {
        Dictionary(grouping: items, by: \.category).map { CategoryResult(id: $0.key, items: $0.value) }
    }

    func testRebuildableDataIsRecommended() {
        let recs = recommendations(results([item("dd", .xcode), item("npm", .packageCaches), item("cache", .appCaches)]))
        XCTAssertEqual(Set(recs.map(\.reason)), ["Xcode build data Xcode rebuilds", "Package downloads your tools fetch again", "App caches apps rebuild"])
    }

    func testPersonalFilesAreNeverRecommended() {
        let recs = recommendations(results([item("movie", .largeFiles, action: .trash, preselected: false),
                                            item("old", .oldFiles, action: .trash, preselected: false),
                                            item("vm", .vms, action: .trash, preselected: false),
                                            item("archive", .xcode, action: .trash, preselected: false),
                                            item("sys", .system, action: .adminDelete, preselected: false),
                                            item("t", .trash, preselected: false)]))
        XCTAssertTrue(recs.isEmpty)
    }

    func testOnlySimulatorsThatNoLongerRun() {
        let recs = recommendations(results([item("dead", .simulators, action: .simctlDeleteDevice(udid: "1"), preselected: true),
                                            item("live", .simulators, action: .simctlDeleteDevice(udid: "2"), preselected: false)]))
        XCTAssertEqual(recs.first?.reason, "Simulators that no longer run")
        XCTAssertEqual(recs.first?.items.map(\.id), ["dead"])
    }

    func testCrashReportsAndUsedInstallers() {
        let recs = recommendations(results([item("reports", .junk), item("Setup.dmg", .junk, action: .trash, preselected: false)]))
        XCTAssertEqual(Set(recs.map(\.reason)), ["Crash reports", "Installers you already used"])
    }

    func testClaudeSessionLogsNeedYourCall() {
        let recs = recommendations(results([item("logs", .claudeCode, action: .deleteContents(keep: ["memory"]), preselected: false),
                                            item("snapshots", .claudeCode)]))
        XCTAssertEqual(recs.map(\.reason), ["Claude Code caches"])
        XCTAssertEqual(recs[0].items.map(\.id), ["snapshots"])
    }

    func testSortedBySizeWithTotals() {
        let recs = recommendations(results([item("a", .appCaches, bytes: 10), item("b", .packageCaches, bytes: 500), item("c", .packageCaches, bytes: 500)]))
        XCTAssertEqual(recs.map(\.bytes), [1000, 10])
    }
}
