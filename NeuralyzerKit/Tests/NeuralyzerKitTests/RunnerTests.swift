import XCTest
@testable import NeuralyzerKit

final class RunnerTests: XCTestCase {
    func testReturnsOutput() async throws {
        let data = try await ProcessRunner().run("/bin/echo", ["hi"])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "hi\n")
    }

    func testHungCommandTimesOut() async {
        let start = Date()
        do {
            _ = try await ProcessRunner(timeout: 0.5).run("/bin/sleep", ["10"])
            XCTFail("expected a timeout")
        } catch {}
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }
}
