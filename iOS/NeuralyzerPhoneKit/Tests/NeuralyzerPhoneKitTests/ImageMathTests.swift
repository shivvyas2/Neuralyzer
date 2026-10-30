import XCTest
@testable import NeuralyzerPhoneKit

final class ImageMathTests: XCTestCase {
    private func gradient(leftToRight: Bool) -> [UInt8] {
        (0..<8).flatMap { _ in (0..<9).map { x in UInt8(leftToRight ? x * 28 : (8 - x) * 28) } }
    }

    func testHashStableForSameImage() {
        let g = gradient(leftToRight: true)
        XCTAssertEqual(differenceHash(gray: g, width: 9, height: 8), differenceHash(gray: g, width: 9, height: 8))
    }

    func testHashDiffersForGradientDirection() {
        let a = differenceHash(gray: gradient(leftToRight: true), width: 9, height: 8)
        let b = differenceHash(gray: gradient(leftToRight: false), width: 9, height: 8)
        XCTAssertEqual(hammingDistance(a, b), 64)
    }

    func testFlatImageHasZeroVariance() {
        XCTAssertEqual(laplacianVariance(gray: [UInt8](repeating: 128, count: 64 * 64), width: 64, height: 64), 0)
    }

    func testCheckerboardHasHighVariance() {
        let board = (0..<64).flatMap { y in (0..<64).map { x in UInt8((x + y) % 2 == 0 ? 255 : 0) } }
        XCTAssertGreaterThan(laplacianVariance(gray: board, width: 64, height: 64), 1000)
    }
}
