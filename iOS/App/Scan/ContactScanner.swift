import Contacts
import NeuralyzerPhoneKit

/// Reads contacts per account so merges never cross accounts. Notes are never read.
struct ContactScanner {
    static var keys: [CNKeyDescriptor] { [
        CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey, CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey, CNContactPostalAddressesKey, CNContactBirthdayKey, CNContactJobTitleKey,
        CNContactUrlAddressesKey, CNContactImageDataAvailableKey,
    ].map { $0 as CNKeyDescriptor } + [CNContactVCardSerialization.descriptorForRequiredKeys()] }

    let store = CNContactStore()

    func scan() -> [ContactInfo] {
        guard let containers = try? store.containers(matching: nil) else { return [] }
        return containers.flatMap { container -> [ContactInfo] in
            let predicate = CNContact.predicateForContactsInContainer(withIdentifier: container.identifier)
            let contacts = (try? store.unifiedContacts(matching: predicate, keysToFetch: Self.keys)) ?? []
            return contacts.map { c in
                let filled = [!c.givenName.isEmpty, !c.familyName.isEmpty, !c.organizationName.isEmpty, !c.jobTitle.isEmpty,
                              c.birthday != nil, c.imageDataAvailable].filter { $0 }.count
                    + c.phoneNumbers.count + c.emailAddresses.count + c.postalAddresses.count + c.urlAddresses.count
                return ContactInfo(id: c.identifier, container: container.identifier, givenName: c.givenName,
                                   familyName: c.familyName, organization: c.organizationName,
                                   phones: c.phoneNumbers.map(\.value.stringValue), emails: c.emailAddresses.map { $0.value as String },
                                   filledFields: filled)
            }
        }
    }
}
