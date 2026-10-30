import Contacts
import NeuralyzerPhoneKit

/// Reads contacts per account so merges never cross accounts. Notes are never read.
struct ContactScanner {
    static var keys: [CNKeyDescriptor] { [
        CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey, CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey, CNContactPostalAddressesKey, CNContactBirthdayKey, CNContactJobTitleKey,
        CNContactUrlAddressesKey, CNContactImageDataAvailableKey, CNContactImageDataKey,
    ].map { $0 as CNKeyDescriptor } + [CNContactVCardSerialization.descriptorForRequiredKeys()] }

    let store = CNContactStore()

    /// Contacts as they are stored in each account, not unified, so a merge only touches one account.
    func scan() -> [ContactInfo] {
        guard let containers = try? store.containers(matching: nil) else { return [] }
        return containers.flatMap { container -> [ContactInfo] in
            let request = CNContactFetchRequest(keysToFetch: Self.keys)
            request.unifyResults = false
            request.predicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
            var out: [ContactInfo] = []
            try? store.enumerateContacts(with: request) { c, _ in
                let filled = [!c.givenName.isEmpty, !c.familyName.isEmpty, !c.organizationName.isEmpty, !c.jobTitle.isEmpty,
                              c.birthday != nil, c.imageDataAvailable].filter { $0 }.count
                    + c.phoneNumbers.count + c.emailAddresses.count + c.postalAddresses.count + c.urlAddresses.count
                out.append(ContactInfo(id: c.identifier, container: container.identifier, givenName: c.givenName,
                                       familyName: c.familyName, organization: c.organizationName,
                                       phones: c.phoneNumbers.map(\.value.stringValue), emails: c.emailAddresses.map { $0.value as String },
                                       filledFields: filled))
            }
            return out
        }
    }

    /// The stored, non unified contacts for these identifiers.
    static func raw(_ ids: [String], store: CNContactStore) -> [CNContact] {
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.unifyResults = false
        request.predicate = CNContact.predicateForContacts(withIdentifiers: ids)
        var out: [CNContact] = []
        try? store.enumerateContacts(with: request) { c, _ in out.append(c) }
        return out
    }
}
