import XCTest
@testable import NeuralyzerKit

final class RecordingRunner: CommandRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [[String]] = []
    var calls: [[String]] { lock.withLock { _calls } }

    func run(_ launchPath: String, _ args: [String]) async throws -> Data {
        lock.withLock { _calls.append(args) }
        return Data()
    }
}

final class CleanerTests: XCTestCase {
    let home = FakeHome()
    let runner = RecordingRunner()
    lazy var env = ScanEnvironment(home: home.url, runner: runner)
    lazy var trashed = home.dir(".Trash")
    lazy var cleaner = Cleaner(env: env, trash: { [trashed] url in
        let dest = trashed.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: dest)
        return dest
    })

    private func item(_ path: String, root: String, action: Action = .delete) -> Item {
        Item(id: path, category: .appCaches, name: path, url: home.path(path), root: home.path(root),
             bytes: 4096, action: action, preselected: true)
    }

    private func logLines() -> [String] {
        let text = (try? String(contentsOf: home.path("Library/Logs/Neuralyzer/clean.log"), encoding: .utf8)) ?? ""
        return text.split(separator: "\n").map(String.init)
    }

    func testDeleteRemovesFile() async {
        home.file("Library/Caches/app/blob")
        let report = await cleaner.clean([item("Library/Caches/app", root: "Library/Caches")])
        XCTAssertFalse(home.exists("Library/Caches/app"))
        XCTAssertEqual(report.freed, 4096)
        XCTAssertTrue(report.failures.isEmpty)
    }

    func testTrashMovesToTrash() async {
        home.file("Downloads/movie.mov")
        let report = await cleaner.clean([item("Downloads/movie.mov", root: "Downloads", action: .trash)])
        XCTAssertFalse(home.exists("Downloads/movie.mov"))
        XCTAssertTrue(home.exists(".Trash/movie.mov"))
        XCTAssertEqual(report.trashed, 4096)
        XCTAssertEqual(report.freed, 0)
    }

    func testRefusesPathOutsideRoot() async {
        home.file("Documents/thesis.pdf")
        let report = await cleaner.clean([item("Documents/thesis.pdf", root: "Library/Caches")])
        XCTAssertTrue(home.exists("Documents/thesis.pdf"))
        XCTAssertEqual(report.failures.count, 1)
    }

    func testRefusesNilRootForFileAction() async {
        home.file("Documents/thesis.pdf")
        let bad = Item(id: "x", category: .junk, name: "x", url: home.path("Documents/thesis.pdf"), root: nil,
                       bytes: 1, action: .delete, preselected: true)
        _ = await cleaner.clean([bad])
        XCTAssertTrue(home.exists("Documents/thesis.pdf"))
    }

    func testDeleteContentsKeepsMemory() async {
        let old = Date().addingTimeInterval(-7200)
        home.file(".claude/projects/-p/memory/MEMORY.md", modified: old)
        home.touch(home.path(".claude/projects/-p/memory"), old)
        home.file(".claude/projects/-p/old.jsonl", modified: old)
        home.file(".claude/projects/-p/live.jsonl")
        let row = item(".claude/projects/-p", root: ".claude/projects", action: .deleteContents(keep: ["memory"]))
        _ = await cleaner.clean([row])
        XCTAssertTrue(home.exists(".claude/projects/-p/memory/MEMORY.md"))
        XCTAssertTrue(home.exists(".claude/projects/-p/live.jsonl"))
        XCTAssertFalse(home.exists(".claude/projects/-p/old.jsonl"))
    }

    func testMissingFileIsSkippedNotFailed() async {
        let report = await cleaner.clean([item("Library/Caches/gone", root: "Library/Caches")])
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertEqual(logLines().count, 1)
        XCTAssertTrue(logLines()[0].contains("skipped"))
    }

    func testWritesOneLogLinePerItem() async {
        home.file("Library/Caches/a/x")
        home.file("Library/Caches/b/y")
        _ = await cleaner.clean([item("Library/Caches/a", root: "Library/Caches"), item("Library/Caches/b", root: "Library/Caches")])
        XCTAssertEqual(logLines().count, 2)
        XCTAssertTrue(logLines()[0].contains("\tdelete\t4096\t"))
    }

    func testSimctlActionsCallRunner() async {
        home.dir("x")
        let device = Item(id: "d", category: .simulators, name: "d", url: home.path("x"), root: nil, bytes: 10,
                          action: .simctlDeleteDevice(udid: "U1"), preselected: true)
        let runtime = Item(id: "r", category: .simulators, name: "r", url: home.path("x"), root: nil, bytes: 20,
                           action: .simctlDeleteRuntime(id: "R1"), preselected: true)
        let report = await cleaner.clean([device, runtime])
        XCTAssertEqual(runner.calls, [["simctl", "delete", "U1"], ["simctl", "runtime", "delete", "R1"]])
        XCTAssertEqual(report.freed, 30)
    }

    func testMissingSimulatorIsSkippedNotFailed() async {
        let device = Item(id: "d", category: .simulators, name: "d", url: home.path("gone-device"), root: nil, bytes: 10,
                          action: .simctlDeleteDevice(udid: "U1"), preselected: true)
        let report = await cleaner.clean([device])
        XCTAssertTrue(runner.calls.isEmpty)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertTrue(logLines()[0].contains("skipped"))
    }

    func testOneBadSessionEntryDoesNotStopTheRest() async throws {
        let old = Date().addingTimeInterval(-7200)
        home.file(".claude/projects/-p/a.jsonl", modified: old)
        let locked = UUID().uuidString
        home.file(".claude/projects/-p/\(locked)/x", modified: old)
        home.touch(home.path(".claude/projects/-p/\(locked)"), old)
        home.file(".claude/projects/-p/z.jsonl", modified: old)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: home.path(".claude/projects/-p/\(locked)").path)
        let row = item(".claude/projects/-p", root: ".claude/projects", action: .deleteContents(keep: ["memory"]))
        _ = await cleaner.clean([row])
        XCTAssertFalse(home.exists(".claude/projects/-p/a.jsonl"))
        XCTAssertFalse(home.exists(".claude/projects/-p/z.jsonl"))
    }

    func testReadOnlyTreeIsStillDeleted() async throws {
        home.file("go/pkg/mod/github.com/x/y.go")
        for p in ["go/pkg/mod/github.com/x", "go/pkg/mod/github.com"] {
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: home.path(p).path)
        }
        let report = await cleaner.clean([item("go/pkg/mod", root: "go/pkg")])
        XCTAssertFalse(home.exists("go/pkg/mod"))
        XCTAssertTrue(report.failures.isEmpty)
    }

    func testFileGoneDuringRemoveIsSkipped() async {
        let seamCleaner = Cleaner(env: env, trash: { _ in throw CocoaError(.fileNoSuchFile) })
        home.file("Downloads/movie.mov")
        let report = await seamCleaner.clean([item("Downloads/movie.mov", root: "Downloads", action: .trash)])
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertTrue(logLines()[0].contains("skipped"))
    }

    func testDeleteTrashedRemovesOnlyWhatThisCleanTrashed() async {
        _ = trashed
        home.file(".Trash/kept-by-hand.zip", bytes: 8192)
        home.file("Downloads/movie.mov", bytes: 8192)
        let report = await cleaner.clean([item("Downloads/movie.mov", root: "Downloads", action: .trash)])
        XCTAssertEqual(report.trashedURLs.map(\.lastPathComponent), ["movie.mov"])
        let freed = await cleaner.deleteTrashed(report.trashedURLs)
        XCTAssertFalse(home.exists(".Trash/movie.mov"))
        XCTAssertTrue(home.exists(".Trash/kept-by-hand.zip"))
        XCTAssertGreaterThanOrEqual(freed, 8192)
    }

    func testDeleteTrashedRefusesPathsOutsideTrash() async {
        let outside = home.file("Documents/thesis.pdf")
        _ = await cleaner.deleteTrashed([outside])
        XCTAssertTrue(home.exists("Documents/thesis.pdf"))
    }
}
