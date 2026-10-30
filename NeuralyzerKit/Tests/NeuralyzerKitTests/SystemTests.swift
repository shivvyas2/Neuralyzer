import XCTest
@testable import NeuralyzerKit

final class RecordingAdmin: AdminRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var _scripts: [String] = []
    var fail = false
    var scripts: [String] { lock.withLock { _scripts } }

    func run(shell script: String) async throws {
        lock.withLock { _scripts.append(script) }
        if fail { throw CommandFailed(status: 1) }
    }
}

final class SystemTests: XCTestCase {
    let home = FakeHome()
    let system = FakeHome()
    let old = Date().addingTimeInterval(-5 * 86400)

    private func env(runner: any CommandRunner = StubRunner(), admin: any AdminRunner = RecordingAdmin()) -> ScanEnvironment {
        ScanEnvironment(home: home.url, runner: runner, admin: admin, systemRoot: system.url, tempDirs: [system.path("var/T"), system.path("var/C")])
    }

    private func scan(_ e: ScanEnvironment? = nil) async -> [Item] { await SystemRule().scan(e ?? env()) }

    func testSystemCachesNeedAdminAndAreUnselected() async {
        system.file("Library/Caches/com.apple.example/blob")
        system.file("Library/Logs/Installer/log.txt")
        system.file("Library/Developer/CoreSimulator/Caches/dyld/cache")
        let items = await scan()
        XCTAssertEqual(Set(items.map(\.name)), ["com.apple.example", "Installer", "dyld"])
        XCTAssertTrue(items.allSatisfy { $0.action == .adminDelete && !$0.preselected && $0.category == .system })
    }

    func testTempOnlyOlderThanThreeDays() async {
        system.file("var/T/old-thing/x", modified: old)
        system.touch(system.path("var/T/old-thing"), old)
        system.file("var/T/fresh/x")
        system.file("var/C/clang/x", modified: old)
        system.touch(system.path("var/C/clang"), old)
        let items = await scan()
        XCTAssertEqual(Set(items.map(\.name)), ["old-thing", "clang"])
        XCTAssertTrue(items.allSatisfy { $0.action == .delete && !$0.preselected })
    }

    func testOldMacOSInstallersAreTrashed() async {
        system.file("Applications/Install macOS Sequoia.app/Contents/Info.plist")
        system.file("Applications/Safari.app/Contents/Info.plist")
        let items = await scan()
        XCTAssertEqual(items.map(\.name), ["Install macOS Sequoia"])
        XCTAssertEqual(items.first?.action, .trash)
    }

    func testIPhoneBackupsUseDeviceName() async throws {
        let backup = home.dir("Library/Application Support/MobileSync/Backup/00008110-ABC")
        let info = try PropertyListSerialization.data(fromPropertyList: ["Device Name": "Shiv's iPhone"], format: .xml, options: 0)
        try info.write(to: backup.appendingPathComponent("Info.plist"))
        home.file("Library/Application Support/MobileSync/Backup/00008110-ABC/Manifest.db", bytes: 50_000)
        let items = await scan()
        XCTAssertEqual(items.map(\.name), ["Shiv's iPhone backup"])
        XCTAssertEqual(items.first?.action, .trash)
    }

    func testSnapshotsComeFromTmutil() async {
        let out = "Snapshots for disk /:\ncom.apple.TimeMachine.2026-10-01-101112.local\ncom.apple.TimeMachine.2026-10-02-090000.local\n"
        let runner = StubRunner(outputs: ["listlocalsnapshots /": Data(out.utf8)])
        let items = await scan(env(runner: runner))
        XCTAssertEqual(items.map(\.name).sorted(), ["Time Machine snapshot 2026-10-01", "Time Machine snapshot 2026-10-02"])
        XCTAssertTrue(items.contains { $0.action == .tmutilDeleteSnapshot(date: "2026-10-01-101112") })
        XCTAssertTrue(items.allSatisfy { $0.root == nil && !$0.preselected })
    }

    // MARK: Cleaning

    func testAdminItemsRunInOnePrompt() async {
        let admin = RecordingAdmin()
        let a = system.file("Library/Caches/one/x")
        let b = system.file("Library/Caches/it's two/y")
        let root = system.path("Library/Caches")
        let items = [a, b].map {
            Item(id: $0.path, category: .system, name: "n", url: $0.deletingLastPathComponent(), root: root, bytes: 10, action: .adminDelete, preselected: false)
        }
        let snapshot = Item(id: "s", category: .system, name: "s", url: system.url, root: nil, bytes: 0,
                            action: .tmutilDeleteSnapshot(date: "2026-10-01-101112"), preselected: false)
        let report = await Cleaner(env: env(admin: admin)).clean(items + [snapshot])
        XCTAssertEqual(admin.scripts.count, 1)
        let script = admin.scripts[0]
        XCTAssertTrue(script.contains("/bin/rm -rf -- '\(root.path)/one'"))
        XCTAssertTrue(script.contains("'\(root.path)/it'\\''s two'"))
        XCTAssertTrue(script.contains("/usr/bin/tmutil deletelocalsnapshots '2026-10-01-101112'"))
        XCTAssertEqual(report.freed, 20)
    }

    func testAdminRefusesPathOutsideRoot() async {
        let admin = RecordingAdmin()
        let outside = home.file("Documents/thesis.pdf")
        let item = Item(id: "x", category: .system, name: "x", url: outside, root: system.path("Library/Caches"), bytes: 10, action: .adminDelete, preselected: false)
        let report = await Cleaner(env: env(admin: admin)).clean([item])
        XCTAssertTrue(admin.scripts.isEmpty)
        XCTAssertEqual(report.failures, ["x"])
    }

    func testCancelledPasswordPromptIsAFailure() async {
        let admin = RecordingAdmin()
        admin.fail = true
        let file = system.file("Library/Caches/one/x")
        let item = Item(id: "x", category: .system, name: "one", url: file.deletingLastPathComponent(), root: system.path("Library/Caches"), bytes: 10, action: .adminDelete, preselected: false)
        let report = await Cleaner(env: env(admin: admin)).clean([item])
        XCTAssertEqual(report.failures, ["one"])
        XCTAssertEqual(report.freed, 0)
    }

    func testShellQuote() {
        XCTAssertEqual(shellQuote("a b"), "'a b'")
        XCTAssertEqual(shellQuote("it's"), "'it'\\''s'")
    }
}
