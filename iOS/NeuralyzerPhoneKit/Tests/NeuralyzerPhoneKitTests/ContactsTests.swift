import XCTest
@testable import NeuralyzerPhoneKit

final class ContactsTests: XCTestCase {
    private func c(_ id: String, _ given: String, _ family: String = "", container: String = "icloud",
                   phones: [String] = [], emails: [String] = [], filled: Int = 1) -> ContactInfo {
        ContactInfo(id: id, container: container, givenName: given, familyName: family, organization: "",
                    phones: phones, emails: emails, filledFields: filled)
    }

    func testPhoneNormalization() {
        XCTAssertEqual(normalizedPhone("+1 (415) 555-0100"), normalizedPhone("415.555.0100"))
    }

    func testSharedPhoneGroups() {
        let groups = contactGroups([c("a", "Sam", phones: ["+1 415 555 0100"], filled: 5), c("b", "Samuel", phones: ["4155550100"])])
        XCTAssertEqual(groups.count, 1)
        XCTAssertTrue(groups[0].strong)
        XCTAssertEqual(groups[0].keep.id, "a")
        XCTAssertTrue(isPreselected(groups[0]))
    }

    func testSharedEmailIgnoresCase() {
        XCTAssertEqual(contactGroups([c("a", "A", emails: ["Me@X.com"]), c("b", "B", emails: ["me@x.com"])]).count, 1)
    }

    func testSameNameOnlyIsWeak() {
        let groups = contactGroups([c("a", "John", "Smith", phones: ["111"]), c("b", "john", "smith", phones: ["222"])])
        XCTAssertEqual(groups.count, 1)
        XCTAssertFalse(groups[0].strong)
        XCTAssertFalse(isPreselected(groups[0]))
    }

    func testCrossContainerNotPreselected() {
        let groups = contactGroups([c("a", "A", container: "icloud", phones: ["4155550100"]), c("b", "A", container: "google", phones: ["4155550100"])])
        XCTAssertEqual(groups.count, 1)
        XCTAssertFalse(groups[0].sameContainer)
        XCTAssertFalse(isPreselected(groups[0]))
    }

    func testMergedFieldsUnion() {
        let g = contactGroups([c("a", "A", phones: ["4155550100"], emails: ["a@x.com"], filled: 4),
                               c("b", "A", phones: ["(415) 555-0100", "4155550199"], emails: ["b@x.com"])])[0]
        XCTAssertEqual(mergedPhones(g), ["4155550100", "4155550199"])
        XCTAssertEqual(mergedEmails(g), ["a@x.com", "b@x.com"])
    }

    func testEmptyNamesNeverMatch() {
        XCTAssertTrue(contactGroups([c("a", ""), c("b", "")]).isEmpty)
    }
}
