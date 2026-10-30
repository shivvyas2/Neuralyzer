import XCTest
@testable import NeuralyzerPhoneKit

final class RecommendTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func daysAgo(_ d: Double) -> Date { now.addingTimeInterval(-d * 86400) }

    func testExtraCopiesAreRecommendedButNotFavorites() {
        let g = PhotoGroup(keep: photo("k"), others: [photo("o1"), photo("o2", favorite: true)], exact: true)
        let recs = recommendations(photos: [], photoGroups: [g], fileGroups: [], now: now)
        XCTAssertEqual(recs.first?.reason, "Extra copies of photos you already have")
        XCTAssertEqual(recs.first?.ids, ["o1"])
    }

    func testNearDuplicatesAreNotRecommended() {
        let g = PhotoGroup(keep: photo("k"), others: [photo("o1")], exact: false)
        XCTAssertTrue(recommendations(photos: [], photoGroups: [g], fileGroups: [], now: now).isEmpty)
    }

    func testOnlyOldScreenshots() {
        let recs = recommendations(photos: [photo("old", created: daysAgo(40), screenshot: true), photo("new", created: daysAgo(2), screenshot: true)],
                                   photoGroups: [], fileGroups: [], now: now)
        XCTAssertEqual(recs.map(\.reason), ["Screenshots older than 30 days"])
        XCTAssertEqual(recs[0].ids, ["old"])
    }

    func testOldWhatsAppMedia() {
        let recs = recommendations(photos: [photo("w", created: daysAgo(100), whatsapp: true), photo("fresh", created: daysAgo(10), whatsapp: true)],
                                   photoGroups: [], fileGroups: [], now: now)
        XCTAssertEqual(recs.first?.ids, ["w"])
        XCTAssertEqual(recs.first?.reason, "WhatsApp media older than 90 days")
    }

    func testBurstExtrasAndBlurry() {
        let recs = recommendations(photos: [photo("extra", burst: "B"), photo("rep", burst: "B", representative: true), photo("blur", blur: 5)],
                                   photoGroups: [], fileGroups: [], now: now)
        XCTAssertEqual(Set(recs.map(\.reason)), ["Extra shots from bursts", "Blurry photos"])
        XCTAssertFalse(recs.flatMap(\.ids).contains("rep"))
    }

    func testEachItemAppearsOnce() {
        let shot = photo("s", created: daysAgo(100), screenshot: true, whatsapp: true)
        let recs = recommendations(photos: [shot], photoGroups: [], fileGroups: [], now: now)
        XCTAssertEqual(recs.flatMap(\.ids), ["s"])
    }

    func testVerifiedFileCopiesOnly() {
        let a = FileInfo(url: URL(fileURLWithPath: "/a"), name: "a", bytes: 100, modified: now, isLocal: true)
        let b = FileInfo(url: URL(fileURLWithPath: "/b"), name: "a", bytes: 100, modified: now, isLocal: true)
        let recs = recommendations(photos: [], photoGroups: [], fileGroups: [FileGroup(keep: a, others: [b], verified: true),
                                                                              FileGroup(keep: b, others: [a], verified: false)], now: now)
        XCTAssertEqual(recs.map(\.reason), ["Extra copies of iCloud files"])
        XCTAssertEqual(recs[0].ids, ["/b"])
        XCTAssertEqual(recs[0].bytes, 100)
    }

    func testSortedBySize() {
        let recs = recommendations(photos: [photo("blur", w: 100, h: 100, blur: 5), photo("big", burst: "B")], photoGroups: [], fileGroups: [], now: now)
        XCTAssertEqual(recs.map(\.reason), ["Extra shots from bursts", "Blurry photos"])
    }
}
