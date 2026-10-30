import XCTest
@testable import NeuralyzerKit

final class ModelTests: XCTestCase {
    private func item(_ name: String, _ bytes: Int64) -> Item {
        Item(id: name, category: .xcode, name: name, url: URL(fileURLWithPath: "/tmp/\(name)"),
             root: URL(fileURLWithPath: "/tmp"), bytes: bytes, action: .delete, preselected: true)
    }

    func testCategoryResultSortsBySizeDescending() {
        let result = CategoryResult(id: .xcode, items: [item("a", 10), item("b", 30), item("c", 20)])
        XCTAssertEqual(result.items.map(\.name), ["b", "c", "a"])
        XCTAssertEqual(result.bytes, 60)
    }

    func testFormatBytes() {
        XCTAssertEqual(formatBytes(8_600_000_000), "8.6 GB")
    }

    func testEveryCategoryHasTitleAndSymbol() {
        for c in CategoryID.allCases {
            XCTAssertFalse(c.title.isEmpty)
            XCTAssertFalse(c.symbol.isEmpty)
        }
    }
}
