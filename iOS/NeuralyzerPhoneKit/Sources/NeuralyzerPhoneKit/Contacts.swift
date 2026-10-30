import Foundation

public struct ContactInfo: Sendable, Hashable, Identifiable {
    public let id: String
    /// The account the contact lives in (iCloud, Google, Exchange).
    public let container: String
    public let givenName: String
    public let familyName: String
    public let organization: String
    public let phones: [String]
    public let emails: [String]
    /// How many fields are filled in; the fullest contact is kept.
    public let filledFields: Int

    public init(id: String, container: String, givenName: String, familyName: String, organization: String,
                phones: [String], emails: [String], filledFields: Int) {
        self.id = id
        self.container = container
        self.givenName = givenName
        self.familyName = familyName
        self.organization = organization
        self.phones = phones
        self.emails = emails
        self.filledFields = filledFields
    }

    var normalizedName: String {
        [givenName, familyName].joined(separator: " ").lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

public struct ContactGroup: Sendable, Hashable {
    public let keep: ContactInfo
    public let others: [ContactInfo]
    /// Linked by a shared phone number or email, not just a name.
    public let strong: Bool
    /// Every copy is in the same account, so a merge never deletes across accounts.
    public let sameContainer: Bool
    /// Every copy has the same name, or no name.
    public let namesAgree: Bool
}

/// Digits only, with any extension dropped and a leading US "1" removed, so "+1 (415) 555-0100",
/// "415.555.0100" and "415-555-0100 x22" match, while "+44 20 7946 0958" stays its own number.
public func normalizedPhone(_ s: String) -> String {
    let number = s.prefix { !$0.isLetter && $0 != "#" && $0 != ";" && $0 != "," }
    let digits = String(number.filter(\.isNumber))
    return digits.count == 11 && digits.hasPrefix("1") ? String(digits.dropFirst()) : digits
}

/// Duplicate contacts. A shared phone or email makes a strong match; a matching full name alone makes a weak one.
public func contactGroups(_ contacts: [ContactInfo]) -> [ContactGroup] {
    var strongParent = Array(contacts.indices)
    var parent = Array(contacts.indices)
    func find(_ p: inout [Int], _ i: Int) -> Int {
        var i = i
        while p[i] != i { p[i] = p[p[i]]; i = p[i] }
        return i
    }
    func link(by key: (ContactInfo) -> [String], strong: Bool) {
        var holders: [String: [Int]] = [:]
        for (i, contact) in contacts.enumerated() {
            for k in Set(key(contact)) where !k.isEmpty { holders[k, default: []].append(i) }
        }
        for indices in holders.values where indices.count > 1 {
            // A number or email held by three or more contacts is a switchboard or a shared inbox,
            // not proof of a duplicate, so it never links anyone.
            if strong && indices.count > 2 { continue }
            for i in indices.dropFirst() {
                parent[find(&parent, i)] = find(&parent, indices[0])
                if strong { strongParent[find(&strongParent, i)] = find(&strongParent, indices[0]) }
            }
        }
    }
    link(by: { $0.phones.map(normalizedPhone).filter { $0.count >= 7 } }, strong: true)
    link(by: { $0.emails.map { $0.lowercased().trimmingCharacters(in: .whitespaces) } }, strong: true)
    link(by: { [$0.normalizedName] }, strong: false)

    let sets = Dictionary(grouping: contacts.indices) { find(&parent, $0) }.values.filter { $0.count > 1 }
    return sets.map { indices in
        let members = indices.map { contacts[$0] }
        let keep = members.min { ($1.filledFields, $0.id) < ($0.filledFields, $1.id) }!
        let strong = Set(indices.map { find(&strongParent, $0) }).count == 1
        let names = Set(members.map(\.normalizedName).filter { !$0.isEmpty })
        return ContactGroup(keep: keep, others: members.filter { $0.id != keep.id }, strong: strong,
                            sameContainer: Set(members.map(\.container)).count == 1, namesAgree: names.count <= 1)
    }
}

/// Only sure matches inside one account, with the same name, are checked by default.
public func isPreselected(_ group: ContactGroup) -> Bool {
    group.strong && group.sameContainer && group.namesAgree
}

public func mergedPhones(_ g: ContactGroup) -> [String] {
    // Entries with no digits ("ask front desk") are kept as written.
    merged(([g.keep] + g.others).flatMap(\.phones)) { p in
        let n = normalizedPhone(p)
        return n.isEmpty ? "text:" + p.lowercased() : n
    }
}

public func mergedEmails(_ g: ContactGroup) -> [String] {
    merged(([g.keep] + g.others).flatMap(\.emails)) { $0.lowercased() }
}

private func merged(_ values: [String], key: (String) -> String) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert(key($0)).inserted }
}
