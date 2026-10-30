import Contacts
import NeuralyzerPhoneKit
import Observation
import Photos

/// What one card holds. Photo cards use `photos` or `photoGroups`, file cards `files` or `fileGroups`,
/// the Contacts card `contactGroups`.
struct CategoryContent {
    var photos: [PhotoInfo] = []
    var photoGroups: [PhotoGroup] = []
    var files: [FileInfo] = []
    var fileGroups: [FileGroup] = []
    var contactGroups: [ContactGroup] = []

    var isEmpty: Bool { photos.isEmpty && photoGroups.isEmpty && files.isEmpty && fileGroups.isEmpty && contactGroups.isEmpty }

    /// Bytes that deleting everything selectable here would free.
    var bytes: Int64 {
        photos.reduce(0) { $0 + estimatedBytes($1) }
            + photoGroups.flatMap(\.others).reduce(0) { $0 + estimatedBytes($1) }
            + files.reduce(0) { $0 + $1.bytes }
            + fileGroups.flatMap(\.others).reduce(0) { $0 + $1.bytes }
    }
}

@MainActor @Observable
final class PhoneStore {
    var results: [PhoneCategory: CategoryContent] = [:]
    var selection: Set<String> = []
    var scanning = false
    var progress: Double = 0
    var freedThisSession: Int64 = 0
    var photosAccess = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    var contactsAccess = CNContactStore.authorizationStatus(for: .contacts)
    var hasFolder = FolderAccess.hasFolder

    private let photos = PhotoScanner()

    var categories: [PhoneCategory] {
        PhoneCategory.allCases.filter { !(results[$0]?.isEmpty ?? true) }
    }

    var disk: (free: Int64, total: Int64) {
        let v = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        return (v?.volumeAvailableCapacityForImportantUsage ?? 0, Int64(v?.volumeTotalCapacity ?? 0))
    }

    // MARK: Permissions

    func requestPhotos() async {
        photosAccess = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func requestContacts() async {
        _ = try? await CNContactStore().requestAccess(for: .contacts)
        contactsAccess = CNContactStore.authorizationStatus(for: .contacts)
    }

    func folderPicked(_ url: URL) {
        FolderAccess.save(url)
        hasFolder = FolderAccess.hasFolder
    }

    // MARK: Scanning

    func scan() {
        guard !scanning else { return }
        scanning = true
        progress = 0
        let scanner = photos
        let canPhotos = photosAccess == .authorized || photosAccess == .limited
        let canContacts = contactsAccess == .authorized || contactsAccess == .limited
        Task {
            let found = await Task.detached(priority: .userInitiated) { () -> [PhoneCategory: CategoryContent] in
                var out: [PhoneCategory: CategoryContent] = [:]
                if canPhotos {
                    let all = scanner.scan { p in Task { @MainActor in self.progress = p * 0.8 } }
                    let exact = exactDuplicateGroups(all)
                    let inExact = Set(exact.flatMap { [$0.keep.id] + $0.others.map(\.id) })
                    let near = nearDuplicateGroups(all, excluding: inExact, distance: scanner.distance, threshold: 0.35)
                    out[.duplicates] = CategoryContent(photoGroups: exact + near)
                    for (category, list) in classify(all) { out[category] = CategoryContent(photos: list) }
                }
                if let files = FolderAccess.withFolder({ listFiles(in: $0) }) {
                    let groups = duplicateFileGroups(files, hash: sha256)
                    out[.icloudDuplicates] = CategoryContent(fileGroups: groups)
                    let grouped = Set(groups.flatMap(\.others).map(\.id))
                    out[.icloudLarge] = CategoryContent(files: largeAndOld(files, now: Date()).filter { !grouped.contains($0.id) })
                }
                if canContacts {
                    out[.contacts] = CategoryContent(contactGroups: contactGroups(ContactScanner().scan()))
                }
                return out
            }.value
            results = found
            selection = Self.preselection(found)
            progress = 1
            scanning = false
        }
    }

    private static func preselection(_ results: [PhoneCategory: CategoryContent]) -> Set<String> {
        var ids = Set<String>()
        for (category, content) in results {
            ids.formUnion(content.photoGroups.filter(\.exact).flatMap(\.others).map(\.id))
            if isPreselected(category) { ids.formUnion(content.photos.map(\.id)) }
            ids.formUnion(content.fileGroups.filter(\.verified).flatMap(\.others).map(\.id))
            ids.formUnion(content.contactGroups.filter { isPreselected($0) }.map(\.keep.id))
        }
        return ids
    }

    func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    // MARK: Deleting

    /// Deletes the selected photos and videos. iOS shows its own confirmation; they go to Recently Deleted.
    func deletePhotos(in category: PhoneCategory) async -> Bool {
        guard let content = results[category] else { return false }
        let items = (content.photos + content.photoGroups.flatMap(\.others)).filter { selection.contains($0.id) }
        guard !items.isEmpty else { return false }
        let ids = items.map(\.id)
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil))
            }
        } catch {
            return false
        }
        freedThisSession += items.reduce(0) { $0 + estimatedBytes($1) }
        removeEverywhere(Set(ids))
        return true
    }

    /// Moves the selected iCloud Drive files to the Trash, coordinated with iCloud.
    func trashFiles(in category: PhoneCategory) -> Int {
        guard let content = results[category] else { return 0 }
        let items = (content.files + content.fileGroups.flatMap(\.others)).filter { selection.contains($0.id) }
        var removed = Set<String>()
        _ = FolderAccess.withFolder { _ in
            let coordinator = NSFileCoordinator()
            for file in items {
                var error: NSError?
                coordinator.coordinate(writingItemAt: file.url, options: .forDeleting, error: &error) { url in
                    if (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) != nil {
                        removed.insert(file.id)
                        freedThisSession += file.bytes
                    }
                }
            }
        }
        removeEverywhere(removed)
        return removed.count
    }

    /// Merges each selected contact group into its fullest contact, after saving a vCard backup of all of them.
    func mergeContacts() -> Int {
        guard let groups = results[.contacts]?.contactGroups.filter({ selection.contains($0.keep.id) }), !groups.isEmpty else { return 0 }
        let store = CNContactStore()
        let ids = groups.flatMap { [$0.keep.id] + $0.others.map(\.id) }
        guard let contacts = try? store.unifiedContacts(matching: CNContact.predicateForContacts(withIdentifiers: ids), keysToFetch: ContactScanner.keys),
              backup(contacts) else { return 0 }
        let byID = Dictionary(uniqueKeysWithValues: contacts.map { ($0.identifier, $0) })
        var merged = 0
        for group in groups {
            guard let keeper = byID[group.keep.id]?.mutableCopy() as? CNMutableContact else { continue }
            let phones = Set(keeper.phoneNumbers.map { normalizedPhone($0.value.stringValue) })
            let emails = Set(keeper.emailAddresses.map { ($0.value as String).lowercased() })
            for phone in mergedPhones(group) where !phones.contains(normalizedPhone(phone)) {
                keeper.phoneNumbers.append(CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone)))
            }
            for email in mergedEmails(group) where !emails.contains(email.lowercased()) {
                keeper.emailAddresses.append(CNLabeledValue(label: CNLabelHome, value: email as NSString))
            }
            let request = CNSaveRequest()
            request.update(keeper)
            for other in group.others {
                if let copy = byID[other.id]?.mutableCopy() as? CNMutableContact { request.delete(copy) }
            }
            if (try? store.execute(request)) != nil { merged += 1 }
        }
        results[.contacts]?.contactGroups.removeAll { g in groups.contains { $0.keep.id == g.keep.id } }
        return merged
    }

    /// Writes every contact about to change to Files, in Neuralyzer's folder, before merging.
    private func backup(_ contacts: [CNContact]) -> Bool {
        guard let data = try? CNContactVCardSerialization.data(with: contacts) else { return false }
        let folder = URL.documentsDirectory.appending(path: "Contact Backups", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)).replacingOccurrences(of: ":", with: ".")
        return (try? data.write(to: folder.appending(path: "Contacts \(stamp).vcf"))) != nil
    }

    private func removeEverywhere(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        for (category, var content) in results {
            content.photos.removeAll { ids.contains($0.id) }
            content.photoGroups = content.photoGroups.compactMap { g in
                let others = g.others.filter { !ids.contains($0.id) }
                return others.isEmpty ? nil : PhotoGroup(keep: g.keep, others: others, exact: g.exact)
            }
            content.files.removeAll { ids.contains($0.id) }
            content.fileGroups = content.fileGroups.compactMap { g in
                let others = g.others.filter { !ids.contains($0.id) }
                return others.isEmpty ? nil : FileGroup(keep: g.keep, others: others, verified: g.verified)
            }
            results[category] = content
        }
        selection.subtract(ids)
    }
}
