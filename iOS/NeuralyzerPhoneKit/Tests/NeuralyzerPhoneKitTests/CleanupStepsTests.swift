import XCTest
@testable import NeuralyzerPhoneKit

final class CleanupStepsTests: XCTestCase {
    func testBiggestWinComesFirst() {
        XCTAssertEqual(cleanupSteps.first?.id, "whatsapp-manage")
    }

    func testIDsAreUnique() {
        XCTAssertEqual(Set(cleanupSteps.map(\.id)).count, cleanupSteps.count)
    }

    func testWhatsAppStepsOpenWhatsApp() {
        for step in cleanupSteps where step.id.hasPrefix("whatsapp") {
            XCTAssertEqual(step.openURL?.scheme, "whatsapp")
            XCTAssertEqual(step.openLabel, "Open WhatsApp")
        }
    }

    func testNoPrivateSettingsLinks() {
        // App-prefs and prefs: URLs are private API and get apps rejected.
        for step in cleanupSteps {
            XCTAssertFalse(step.openURL?.scheme?.lowercased().contains("prefs") ?? false)
        }
    }

    func testCopyHasNoEmDashes() {
        for step in cleanupSteps {
            XCTAssertFalse((step.title + step.detail).contains("\u{2014}"))
        }
    }

    func testFreedSinceStart() {
        XCTAssertEqual(freedSince(baseline: 10_000_000_000, nowFree: 12_500_000_000), 2_500_000_000)
        XCTAssertEqual(freedSince(baseline: 10_000_000_000, nowFree: 9_000_000_000), 0)
    }
}
