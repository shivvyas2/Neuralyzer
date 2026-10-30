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
        let groups = contactGroups([c("a", "Sam", phones: ["+1 415 555 0100"], filled: 5), c("b", "Sam", phones: ["4155550100"])])
        XCTAssertEqual(groups.count, 1)
        XCTAssertTrue(groups[0].strong)
        XCTAssertEqual(groups[0].keep.id, "a")
        XCTAssertTrue(isPreselected(groups[0]))
    }

    func testDifferentNamesSharingAPhoneAreNotPreselected() {
        let groups = contactGroups([c("a", "Sam", phones: ["4155550100"]), c("b", "Alex", phones: ["4155550100"])])
        XCTAssertEqual(groups.count, 1)
        XCTAssertFalse(isPreselected(groups[0]))
    }

    func testOneEmptyNameStillPreselected() {
        let groups = contactGroups([c("a", "Sam", phones: ["4155550100"]), c("b", "", phones: ["4155550100"])])
        XCTAssertTrue(isPreselected(groups[0]))
    }

    func testSwitchboardNumberDoesNotChainPeople() {
        let people = (0..<5).map { c("p\($0)", "Person\($0)", phones: ["+1 800 555 0100"]) }
        let groups = contactGroups(people)
        XCTAssertTrue(groups.allSatisfy { !isPreselected($0) })
        XCTAssertTrue(groups.allSatisfy { !$0.strong })
    }

    func testSharedEmailIgnoresCase() {
        XCTAssertEqual(contactGroups([c("a", "A", emails: ["Me@X.com"]), c("b", "A", emails: ["me@x.com"])]).count, 1)
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

    func testPhoneExtensionIgnored() {
        XCTAssertEqual(normalizedPhone("415-555-0100 ext. 22"), normalizedPhone("4155550100"))
        XCTAssertEqual(normalizedPhone("415-555-0100 x22"), normalizedPhone("4155550100"))
    }

    func testDifferentCountryCodesStayDifferent() {
        XCTAssertNotEqual(normalizedPhone("+44 20 7946 0958"), normalizedPhone("+1 207 946 0958"))
        XCTAssertEqual(normalizedPhone("+1 415 555 0100"), normalizedPhone("415 555 0100"))
    }

    func testPhonesWithoutDigitsAreAllKept() {
        let g = contactGroups([c("a", "A", phones: ["4155550100", "ask front desk"]), c("b", "A", phones: ["4155550100", "see notes"])])[0]
        XCTAssertEqual(mergedPhones(g), ["4155550100", "ask front desk", "see notes"])
    }

    func testEmptyNamesNeverMatch() {
        XCTAssertTrue(contactGroups([c("a", ""), c("b", "")]).isEmpty)
    }
}
