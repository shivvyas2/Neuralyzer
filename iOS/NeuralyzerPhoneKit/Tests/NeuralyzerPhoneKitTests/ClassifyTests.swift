import XCTest
@testable import NeuralyzerPhoneKit

final class ClassifyTests: XCTestCase {
    private func ids(_ r: [PhoneCategory: [PhotoInfo]], _ c: PhoneCategory) -> Set<String> { Set((r[c] ?? []).map(\.id)) }

    func testScreenshots() {
        XCTAssertEqual(ids(classify([photo("s", screenshot: true), photo("p")]), .screenshots), ["s"])
    }

    func testScreenRecordings() {
        let r = classify([photo("r", video: true, duration: 5, filename: "RPReplay_Final1690000000.MP4"),
                          photo("v", video: true, duration: 5, filename: "IMG_0001.MOV")])
        XCTAssertEqual(ids(r, .screenRecordings), ["r"])
    }

    func testBurstExtrasOnly() {
        let r = classify([photo("rep", burst: "B", representative: true), photo("pick", burst: "B", pick: true), photo("extra", burst: "B")])
        XCTAssertEqual(ids(r, .bursts), ["extra"])
    }

    func testBlurry() {
        XCTAssertEqual(ids(classify([photo("b", blur: 10), photo("s", blur: 500), photo("u")]), .blurry), ["b"])
    }

    func testBigVideos() {
        let r = classify([photo("big", w: 3840, h: 2160, video: true, duration: 60), photo("small", w: 1280, h: 720, video: true, duration: 10)])
        XCTAssertEqual(ids(r, .bigVideos), ["big"])
    }

    func testWhatsApp() {
        XCTAssertEqual(ids(classify([photo("w", whatsapp: true), photo("p")]), .whatsapp), ["w"])
    }

    func testOnlyBurstsPreselected() {
        XCTAssertTrue(isPreselected(.bursts))
        for c in [PhoneCategory.screenshots, .screenRecordings, .blurry, .bigVideos, .whatsapp] {
            XCTAssertFalse(isPreselected(c))
        }
    }
}
