import XCTest
@testable import NeuralyzerKit

private struct FixedRule: CategoryRule {
    let id: CategoryID
    let items: [Item]
    func scan(_ env: ScanEnvironment) async -> [Item] { items }
}

final class ScannerTests: XCTestCase {
    let home = FakeHome()

    private func item(_ c: CategoryID) -> Item {
        Item(id: c.rawValue, category: c, name: c.rawValue, url: home.url, root: nil, bytes: 10, action: .delete, preselected: true)
    }

    private func collect(_ rules: [any CategoryRule]) async -> [CategoryResult] {
        var out: [CategoryResult] = []
        for await r in DiskScanner().scan(ScanEnvironment(home: home.url), rules: rules) { out.append(r) }
        return out
    }

    func testScannerSkipsEmptyCategories() async {
        let results = await collect([FixedRule(id: .xcode, items: []), FixedRule(id: .junk, items: [item(.junk)])])
        XCTAssertEqual(results.map(\.id), [.junk])
    }

    func testScannerYieldsEachRule() async {
        let results = await collect([FixedRule(id: .xcode, items: [item(.xcode)]), FixedRule(id: .junk, items: [item(.junk)])])
        XCTAssertEqual(Set(results.map(\.id)), [.xcode, .junk])
    }

    func testAllRulesCoverEveryCategory() {
        XCTAssertEqual(Set(DiskScanner.all().map(\.id)), Set(CategoryID.allCases))
    }

    func testBlockersOnlyForXcodeAndSimulatorItems() {
        let running: (String) -> Bool = { _ in true }
        XCTAssertEqual(runningBlockers(for: [item(.junk)], isRunning: running), [])
        XCTAssertEqual(runningBlockers(for: [item(.xcode)], isRunning: running), ["Xcode"])
        XCTAssertEqual(runningBlockers(for: [item(.simulators)], isRunning: running), ["Xcode", "Simulator"])
        XCTAssertEqual(runningBlockers(for: [item(.xcode)], isRunning: { _ in false }), [])
    }

    func testFullDiskAccessProbeFailsWithoutProtectedFolders() {
        XCTAssertFalse(Access.hasFullDiskAccess(home: home.url))
    }
}
