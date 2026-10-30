import XCTest
@testable import NeuralyzerPhoneKit

final class DuplicatesTests: XCTestCase {
    let year = Date(timeIntervalSince1970: 1_700_000_000)

    func testExactDuplicatesAnyDate() {
        let a = photo("a", created: year, hash: 0b1010)
        let b = photo("b", created: year.addingTimeInterval(365 * 86400), hash: 0b1011)
        let groups = exactDuplicateGroups([a, b, photo("c", hash: 0xFFFF_0000)])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(([groups[0].keep] + groups[0].others).map(\.id)), ["a", "b"])
        XCTAssertTrue(groups[0].exact)
    }

    func testDifferentSizeNotExact() {
        XCTAssertTrue(exactDuplicateGroups([photo("a", w: 100, h: 100, hash: 1), photo("b", w: 200, h: 100, hash: 1)]).isEmpty)
    }

    func testMissingHashNeverGroups() {
        XCTAssertTrue(exactDuplicateGroups([photo("a"), photo("b")]).isEmpty)
    }

    func testKeeperPrefersFavorite() {
        let k = pickKeeper([photo("a", created: year), photo("b", created: year.addingTimeInterval(9), favorite: true)])
        XCTAssertEqual(k.id, "b")
    }

    func testKeeperPrefersEditedThenLarger() {
        XCTAssertEqual(pickKeeper([photo("a", w: 4000, h: 3000), photo("b", w: 100, h: 100, edited: true)]).id, "b")
        XCTAssertEqual(pickKeeper([photo("a", w: 100, h: 100), photo("b", w: 4000, h: 3000)]).id, "b")
    }

    func testAllFavoritesKeepEarliest() {
        let k = pickKeeper([photo("late", created: year.addingTimeInterval(60), favorite: true),
                            photo("early", created: year, favorite: true),
                            photo("nodate", favorite: true)])
        XCTAssertEqual(k.id, "early")
    }

    func testNearDuplicatesNotIncludingExact() {
        let a = photo("a", hash: 0), b = photo("b", hash: 0b111), c = photo("c", hash: 0)
        let groups = nearDuplicateGroups([a, b, c], excluding: ["c"], distance: { x, y in
            Set([x.id, y.id]) == ["a", "b"] ? 0.1 : 0.9
        }, threshold: 0.35)
        XCTAssertEqual(groups.count, 1)
        XCTAssertFalse(groups[0].exact)
        XCTAssertEqual(Set(([groups[0].keep] + groups[0].others).map(\.id)), ["a", "b"])
    }

    func testNearDuplicatesSkipVideosAndOtherAspects() {
        let groups = nearDuplicateGroups([photo("a", hash: 0), photo("b", w: 1000, h: 3000, hash: 0), photo("v", video: true, duration: 3, hash: 0)],
                                         excluding: [], distance: { _, _ in 0 }, threshold: 0.35)
        XCTAssertTrue(groups.isEmpty)
    }

    func testNearDuplicatesOnlyCompareSimilarThumbnails() {
        var calls = 0
        let groups = nearDuplicateGroups([photo("a", hash: 0), photo("b", hash: UInt64.max)], excluding: [], distance: { _, _ in
            calls += 1
            return 0
        }, threshold: 0.35)
        XCTAssertTrue(groups.isEmpty)
        XCTAssertEqual(calls, 0)
    }

    func testBurstFramesAreNeverDuplicates() {
        let groups = exactDuplicateGroups([photo("f1", burst: "B", hash: 7), photo("f2", burst: "B", representative: true, hash: 7)])
        XCTAssertTrue(groups.isEmpty)
    }

    func testExactNeedsConfirmation() {
        let groups = exactDuplicateGroups([photo("a", hash: 7), photo("b", hash: 7)], confirm: { _, _ in false })
        XCTAssertTrue(groups.isEmpty)
    }

    func testRemovingKeeperDropsTheGroup() {
        let g = PhotoGroup(keep: photo("k"), others: [photo("o1"), photo("o2")], exact: true)
        XCTAssertTrue(removing(["k"], from: [g]).isEmpty)
        XCTAssertEqual(removing(["o1"], from: [g]).first?.others.map(\.id), ["o2"])
        XCTAssertTrue(removing(["o1", "o2"], from: [g]).isEmpty)
    }

    func testNearDuplicateWorkIsCapped() {
        let photos = (0..<40).map { photo("p\($0)", hash: 0) }
        var calls = 0
        _ = nearDuplicateGroups(photos, excluding: [], distance: { _, _ in calls += 1; return 0.9 }, threshold: 0.35, maxComparisons: 25)
        XCTAssertLessThanOrEqual(calls, 25)
    }

    func testNearDuplicateProgressReachesOne() {
        var last = 0.0
        _ = nearDuplicateGroups((0..<10).map { photo("p\($0)", hash: 0) }, excluding: [], distance: { _, _ in 0.9 }, threshold: 0.35,
                                progress: { last = $0 })
        XCTAssertEqual(last, 1)
    }

    func testVideosNeedSimilarDuration() {
        let a = photo("a", video: true, duration: 10, hash: 5)
        let b = photo("b", video: true, duration: 10.3, hash: 5)
        let c = photo("c", video: true, duration: 30, hash: 5)
        let groups = exactDuplicateGroups([a, b, c])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].others.count, 1)
    }
}
