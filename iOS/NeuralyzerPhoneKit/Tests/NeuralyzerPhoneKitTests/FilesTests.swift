import XCTest
@testable import NeuralyzerPhoneKit

final class TempFolder {
    let url: URL
    init() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("nphone-\(UUID().uuidString)").resolvingSymlinksInPath()
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: url) }

    @discardableResult
    func file(_ path: String, _ contents: String, modified: Date? = nil) -> URL {
        let u = url.appendingPathComponent(path)
        try! FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! Data(contents.utf8).write(to: u)
        if let modified { try! FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: u.path) }
        return u
    }
}

final class FilesTests: XCTestCase {
    let folder = TempFolder()
    let old = Date(timeIntervalSince1970: 1_600_000_000)

    func testHashMatchesGroup() {
        folder.file("a/report.pdf", "same bytes", modified: old)
        folder.file("b/report copy.pdf", "same bytes")
        let groups = duplicateFileGroups(listFiles(in: folder.url), hash: sha256)
        XCTAssertEqual(groups.count, 1)
        XCTAssertTrue(groups[0].verified)
        XCTAssertEqual(groups[0].keep.name, "report.pdf")
        XCTAssertEqual(groups[0].others.map(\.name), ["report copy.pdf"])
    }

    func testSameSizeDifferentContentNotGrouped() {
        folder.file("x", "aaaa")
        folder.file("y", "bbbb")
        XCTAssertTrue(duplicateFileGroups(listFiles(in: folder.url), hash: sha256).isEmpty)
    }

    func testPlaceholderMatchIsUnverified() {
        let local = FileInfo(url: folder.url.appendingPathComponent("movie.mov"), name: "movie.mov", bytes: 500, modified: old, isLocal: true)
        let cloud = FileInfo(url: folder.url.appendingPathComponent("b/.movie.mov.icloud"), name: "movie.mov", bytes: 500, modified: Date(), isLocal: false)
        let groups = duplicateFileGroups([local, cloud], hash: { _ in "h" })
        XCTAssertEqual(groups.count, 1)
        XCTAssertFalse(groups[0].verified)
    }

    func testPlaceholderIsListedByRealName() throws {
        let plist = try PropertyListSerialization.data(fromPropertyList: ["NSURLNameKey": "movie.mov", "NSURLFileSizeKey": 12345], format: .binary, options: 0)
        try plist.write(to: folder.url.appendingPathComponent(".movie.mov.icloud"))
        let files = listFiles(in: folder.url)
        XCTAssertEqual(files.map(\.name), ["movie.mov"])
        XCTAssertEqual(files.first?.bytes, 12345)
        XCTAssertEqual(files.first?.isLocal, false)
        XCTAssertEqual(files.first?.url.lastPathComponent, "movie.mov")
    }

    func testPlaceholderWithEmojiNameUsesRealURL() throws {
        let plist = try PropertyListSerialization.data(fromPropertyList: ["NSURLNameKey": "Trip 🌴.mov", "NSURLFileSizeKey": 10], format: .binary, options: 0)
        try plist.write(to: folder.url.appendingPathComponent(".Trip 🌴.mov.icloud"))
        let url = try XCTUnwrap(listFiles(in: folder.url).first?.url)
        XCTAssertEqual(url.lastPathComponent, "Trip 🌴.mov")
        XCTAssertEqual(url.deletingLastPathComponent().resolvingSymlinksInPath(), folder.url.resolvingSymlinksInPath())
    }

    func testUnverifiedGroupLeavesOutVerifiedCopies() {
        let a = FileInfo(url: URL(fileURLWithPath: "/A/IMG.pdf"), name: "IMG.pdf", bytes: 500, modified: old, isLocal: true)
        let b = FileInfo(url: URL(fileURLWithPath: "/B/IMG.pdf"), name: "IMG.pdf", bytes: 500, modified: Date(), isLocal: true)
        let cloud = FileInfo(url: URL(fileURLWithPath: "/C/IMG.pdf"), name: "IMG.pdf", bytes: 500, modified: Date(), isLocal: false)
        let groups = duplicateFileGroups([a, b, cloud], hash: { _ in "same" })
        let verified = groups.filter(\.verified)
        let unverified = groups.filter { !$0.verified }
        XCTAssertEqual(verified.count, 1)
        XCTAssertEqual(unverified.count, 1)
        XCTAssertEqual(Set(([unverified[0].keep] + unverified[0].others).map(\.url.path)), ["/A/IMG.pdf", "/C/IMG.pdf"])
    }

    func testNameWithSpacesAndEmoji() {
        folder.file("Trip 🌴 photo.jpg", "x")
        folder.file("Trip 🌴 photo (1).jpg", "x")
        XCTAssertEqual(duplicateFileGroups(listFiles(in: folder.url), hash: sha256).count, 1)
    }

    func testHiddenFilesSkipped() {
        folder.file(".DS_Store", "x")
        XCTAssertTrue(listFiles(in: folder.url).isEmpty)
    }

    func testLargeAndOld() {
        let now = Date()
        let files = [
            FileInfo(url: folder.url, name: "big", bytes: 200_000_000, modified: now, isLocal: true),
            FileInfo(url: folder.url, name: "old", bytes: 20_000_000, modified: now.addingTimeInterval(-200 * 86400), isLocal: true),
            FileInfo(url: folder.url, name: "small-old", bytes: 1_000, modified: now.addingTimeInterval(-400 * 86400), isLocal: true),
            FileInfo(url: folder.url, name: "fresh", bytes: 20_000_000, modified: now, isLocal: true),
        ]
        XCTAssertEqual(Set(largeAndOld(files, now: now).map(\.name)), ["big", "old"])
    }
}
