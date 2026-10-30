import XCTest
@testable import NeuralyzerPhoneKit

func photo(_ id: String, w: Int = 4032, h: Int = 3024, video: Bool = false, duration: Double = 0, created: Date? = nil,
           favorite: Bool = false, edited: Bool = false, screenshot: Bool = false, filename: String? = nil,
           burst: String? = nil, representative: Bool = false, pick: Bool = false, whatsapp: Bool = false,
           hash: UInt64? = nil, blur: Double? = nil) -> PhotoInfo {
    PhotoInfo(id: id, isVideo: video, pixelWidth: w, pixelHeight: h, duration: duration, created: created,
              isFavorite: favorite, hasEdits: edited, isScreenshot: screenshot, originalFilename: filename,
              burstID: burst, isBurstRepresentative: representative, isBurstUserPick: pick,
              inWhatsAppAlbum: whatsapp, thumbHash: hash, blurScore: blur)
}

final class ModelTests: XCTestCase {
    func testEstimate12MPPhoto() {
        let b = estimatedBytes(photo("a"))
        XCTAssertGreaterThan(b, 5_000_000)
        XCTAssertLessThan(b, 6_000_000)
    }

    func testEstimate4KMinute() {
        XCTAssertEqual(estimatedBytes(photo("v", w: 3840, h: 2160, video: true, duration: 60)), 360_000_000)
    }

    func testAboutSize() {
        XCTAssertEqual(aboutSize(2_400_000_000), "About 2.4 GB")
    }

    func testEveryCategoryHasTitleAndSymbol() {
        for c in PhoneCategory.allCases {
            XCTAssertFalse(c.title.isEmpty)
            XCTAssertFalse(c.symbol.isEmpty)
        }
    }
}
