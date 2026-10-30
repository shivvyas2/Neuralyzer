import XCTest
@testable import NeuralyzerKit

final class RuleTests: XCTestCase {
    let home = FakeHome()
    lazy var env = ScanEnvironment(home: home.url)
    let old = Date().addingTimeInterval(-7200)

    private func scan(_ rule: some CategoryRule) async -> [Item] { await rule.scan(env) }

    // MARK: Xcode

    func testXcodeDerivedDataRowsPerProject() async {
        home.file("Library/Developer/Xcode/DerivedData/Neuralyzer-abcdefghijklmnopqrstuvwxyz/Build/x", bytes: 8192)
        home.file("Library/Developer/Xcode/DerivedData/Astra-zyxwvutsrqponmlkjihgfedcba/Build/y")
        let items = await scan(XcodeRule())
        XCTAssertEqual(Set(items.map(\.name)), ["Neuralyzer", "Astra"])
        XCTAssertTrue(items.allSatisfy { $0.action == .delete && $0.preselected })
    }

    func testXcodeArchivesAreTrashAndUnselected() async {
        home.file("Library/Developer/Xcode/Archives/2026-10-01/Astra 1.0.xcarchive/Info.plist")
        let items = await scan(XcodeRule())
        XCTAssertEqual(items.map(\.name), ["Astra 1.0"])
        XCTAssertEqual(items.first?.action, .trash)
        XCTAssertEqual(items.first?.preselected, false)
    }

    func testXcodeDeviceSupportRowsPerVersion() async {
        home.file("Library/Developer/Xcode/iOS DeviceSupport/iPhone17,1 26.0 (23A1)/Symbols/a")
        let items = await scan(XcodeRule())
        XCTAssertEqual(items.map(\.name), ["iOS iPhone17,1 26.0 (23A1)"])
    }

    // MARK: Claude Code

    func testClaudeProjectRowExcludesMemory() async {
        home.file(".claude/projects/-p/memory/MEMORY.md", bytes: 1_000_000)
        home.file(".claude/projects/-p/a.jsonl", bytes: 200_000, modified: old)
        let row = await scan(ClaudeRule()).first { $0.category == .claudeCode && $0.url.lastPathComponent == "-p" }
        XCTAssertNotNil(row)
        XCTAssertLessThan(row!.bytes, 1_000_000)
        XCTAssertGreaterThanOrEqual(row!.bytes, 200_000)
        XCTAssertEqual(row!.action, .deleteContents(keep: ["memory"]))
        XCTAssertFalse(row!.preselected)
    }

    func testClaudeSkipsSessionsFromLastHour() async {
        home.file(".claude/projects/-p/new.jsonl", bytes: 200_000)
        let rows = await scan(ClaudeRule()).filter { $0.url.lastPathComponent == "-p" }
        XCTAssertTrue(rows.isEmpty)
    }

    func testClaudeCountsOldSessionFolders() async {
        let id = UUID().uuidString
        home.file(".claude/projects/-p/\(id)/tool.txt", bytes: 300_000, modified: old)
        home.touch(home.path(".claude/projects/-p/\(id)"), old)
        let row = await scan(ClaudeRule()).first { $0.url.lastPathComponent == "-p" }
        XCTAssertGreaterThanOrEqual(row?.bytes ?? 0, 300_000)
    }

    func testClaudeNeverListsSettingsOrSkills() async {
        home.file(".claude/settings.json")
        home.file(".claude/skills/x/SKILL.md")
        home.file(".claude/shell-snapshots/s.sh")
        let names = await scan(ClaudeRule()).map(\.url.lastPathComponent)
        XCTAssertEqual(names, ["shell-snapshots"])
    }

    func testClaudeAppCaches() async {
        home.file("Library/Application Support/Claude/Cache/blob")
        home.file("Library/Application Support/Claude/Cookies")
        let names = await scan(ClaudeRule()).map(\.url.lastPathComponent)
        XCTAssertEqual(names, ["Cache"])
    }

    // MARK: Caches

    func testPackageCachesFindNpmAndHomebrew() async {
        home.file(".npm/_cacache/x")
        home.file("Library/Caches/Homebrew/y")
        let items = await scan(PackageCacheRule())
        XCTAssertEqual(Set(items.map(\.url.lastPathComponent)), ["_cacache", "Homebrew"])
        XCTAssertTrue(items.allSatisfy(\.preselected))
    }

    func testDotCacheChildrenAreNotPreselected() async {
        home.file(".cache/whisper/model.bin")
        let items = await scan(PackageCacheRule())
        XCTAssertEqual(items.map(\.name), ["whisper"])
        XCTAssertFalse(items[0].preselected)
    }

    func testAppCachesExcludePackageCaches() async {
        home.file("Library/Caches/Homebrew/y")
        home.file("Library/Caches/com.example.app/z")
        let names = await scan(AppCacheRule()).map(\.name)
        XCTAssertEqual(names, ["com.example.app"])
    }

    // MARK: Junk, Trash, VMs, build folders

    func testJunkInstallersAreTrashed() async {
        home.file("Downloads/Setup.dmg")
        home.file("Downloads/notes.txt")
        home.file("Library/Logs/DiagnosticReports/crash.ips")
        let items = await scan(JunkRule())
        XCTAssertEqual(Set(items.map(\.name)), ["Setup.dmg", "Crash Reports"])
        XCTAssertEqual(items.first { $0.name == "Setup.dmg" }?.action, .trash)
    }

    func testTrashNeverPreselected() async {
        home.file(".Trash/old.zip")
        let items = await scan(TrashRule())
        XCTAssertEqual(items.map(\.name), ["old.zip"])
        XCTAssertFalse(items[0].preselected)
        XCTAssertEqual(items[0].action, .delete)
    }

    func testVMsAreTrashedAndUnselected() async {
        home.file("Library/Containers/com.utmapp.UTM/Data/vm.utm")
        let items = await scan(VMRule())
        XCTAssertEqual(items.map(\.name), ["UTM"])
        XCTAssertEqual(items[0].action, .trash)
        XCTAssertFalse(items[0].preselected)
    }

    func testBuildFoldersDoNotDescendIntoMatch() async {
        home.file("Projects/web/app/node_modules/pkg/node_modules/dep/x.js")
        home.file("Projects/ios/Kit/.build/debug/y")
        let names = await scan(ProjectBuildRule()).map(\.name).sorted()
        XCTAssertEqual(names, ["ios/Kit/.build", "web/app/node_modules"])
    }

    func testBuildFolderNeedsBuildSystemBesideIt() async {
        home.file("Projects/electron/build/icon.icns")
        home.file("Projects/gradle/build/out.jar")
        home.file("Projects/gradle/build.gradle")
        let items = await scan(ProjectBuildRule())
        XCTAssertEqual(items.map(\.name), ["gradle/build"])
    }

    func testBuildFolderGoesToTrash() async {
        home.file("Projects/web/build/app.js")
        home.file("Projects/web/package.json")
        home.file("Projects/web/node_modules/x/y.js")
        let items = await scan(ProjectBuildRule())
        XCTAssertEqual(items.first { $0.name == "web/build" }?.action, .trash)
        XCTAssertEqual(items.first { $0.name == "web/node_modules" }?.action, .delete)
    }

    func testEveryRowPassesSafetyGuard() async {
        home.file("Library/Caches/com.example.app/z")
        home.link("Library/Caches/evil", to: "Documents")
        home.file("Documents/keep.pdf")
        let guardian = SafetyGuard(home: home.url)
        let items = await scan(AppCacheRule())
        XCTAssertEqual(items.map(\.name), ["com.example.app"])
        XCTAssertTrue(items.allSatisfy { guardian.allows($0.url, root: $0.root!) })
    }

    // MARK: Large and old

    func testLargeFileThreshold() async {
        home.file("Downloads/big.mov", bytes: 600_000)
        home.file("Downloads/small.mov", bytes: 400_000)
        let items = await scan(LargeFileRule(largeBytes: 500_000))
        XCTAssertEqual(items.map(\.name), ["big.mov"])
        XCTAssertEqual(items[0].action, .trash)
        XCTAssertFalse(items[0].preselected)
    }

    func testLargeFilesSkipInstallers() async {
        home.file("Downloads/Xcode.dmg", bytes: 600_000)
        let items = await scan(LargeFileRule(largeBytes: 500_000))
        XCTAssertTrue(items.isEmpty)
    }

    func testOldFilesExcludeLargeAndRecent() async {
        let ancient = Date().addingTimeInterval(-200 * 86400)
        home.file("Documents/old.zip", bytes: 100_000, modified: ancient)
        home.file("Documents/recent.zip", bytes: 100_000)
        home.file("Documents/huge-old.zip", bytes: 600_000, modified: ancient)
        let items = await scan(OldFileRule(largeBytes: 500_000, oldBytes: 50_000))
        XCTAssertEqual(items.map(\.name), ["old.zip"])
    }

    func testOldFolderUsesNewestDescendant() async {
        let ancient = Date().addingTimeInterval(-200 * 86400)
        home.file("Documents/proj/a", bytes: 60_000, modified: ancient)
        home.file("Documents/proj/b", bytes: 10)
        let items = await scan(OldFileRule(largeBytes: 500_000, oldBytes: 50_000))
        XCTAssertTrue(items.isEmpty)
    }
}
