import XCTest
@testable import NeuralyzerKit

final class SizerTests: XCTestCase {
    let home = FakeHome()

    func testSizesNestedFiles() {
        home.file("a/one", bytes: 4096)
        home.file("a/b/two", bytes: 4096)
        XCTAssertGreaterThanOrEqual(allocatedSize(of: home.path("a")), 8192)
    }

    func testSizesPlainFile() {
        let f = home.file("f", bytes: 8192)
        XCTAssertGreaterThanOrEqual(allocatedSize(of: f), 8192)
    }

    func testUnreadableSubfolderCountsZero() throws {
        home.file("a/readable", bytes: 4096)
        home.file("a/locked/secret", bytes: 1_000_000)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: home.path("a/locked").path)
        let size = allocatedSize(of: home.path("a"))
        XCTAssertGreaterThanOrEqual(size, 4096)
        XCTAssertLessThan(size, 1_000_000)
    }

    func testDoesNotFollowSymlinks() {
        home.file("big/blob", bytes: 1_000_000)
        home.link("a/link", to: "big")
        XCTAssertLessThan(allocatedSize(of: home.path("a")), 1_000_000)
    }

    func testMissingPathIsZero() {
        XCTAssertEqual(allocatedSize(of: home.path("nope")), 0)
    }
}
