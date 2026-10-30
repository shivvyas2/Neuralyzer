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
    /// What Neuralyzer suggests deleting, largest first.
    var recommended: [Recommendation] = []
    private var photoIndex: [String: PhotoInfo] = [:]
    private var fileIndex: [String: FileInfo] = [:]

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

    /// Re-reads access after a trip to Settings, and scans if Photos just became available.
    func refreshAccess() {
        let before = photosAccess
        photosAccess = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        contactsAccess = CNContactStore.authorizationStatus(for: .contacts)
        let usable: (PHAuthorizationStatus) -> Bool = { $0 == .authorized || $0 == .limited }
        if usable(photosAccess) && !usable(before) { scan() }
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
            let (found, allPhotos) = await Task.detached(priority: .userInitiated) { () -> ([PhoneCategory: CategoryContent], [PhotoInfo]) in
                var out: [PhoneCategory: CategoryContent] = [:]
                var allPhotos: [PhotoInfo] = []
                if canPhotos {
                    let all = scanner.scan { p in Task { @MainActor in self.progress = p * 0.6 } }
                    allPhotos = all
                    let exact = exactDuplicateGroups(all, confirm: { a, b in (scanner.distance(a, b) ?? 1) < 0.05 })
                    let inExact = Set(exact.flatMap { [$0.keep.id] + $0.others.map(\.id) })
                    let near = nearDuplicateGroups(all, excluding: inExact, distance: scanner.distance, threshold: 0.35,
                                                   progress: { p in Task { @MainActor in self.progress = 0.6 + p * 0.3 } })
                    out[.duplicates] = CategoryContent(photoGroups: exact + near)
                    for (category, list) in classify(all) { out[category] = CategoryContent(photos: list) }
                }
                Task { @MainActor in self.progress = 0.9 }
                if let files = FolderAccess.withFolder({ listFiles(in: $0) }) {
                    let groups = duplicateFileGroups(files, hash: sha256)
                    out[.icloudDuplicates] = CategoryContent(fileGroups: groups)
                    let grouped = Set(groups.flatMap(\.others).map(\.id))
                    out[.icloudLarge] = CategoryContent(files: largeAndOld(files, now: Date()).filter { !grouped.contains($0.id) })
                }
                if canContacts {
                    out[.contacts] = CategoryContent(contactGroups: contactGroups(ContactScanner().scan()))
                }
                return (out, allPhotos)
            }.value
            results = found
            photoIndex = Dictionary(allPhotos.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let files = found.values.flatMap { $0.files + $0.fileGroups.flatMap { [$0.keep] + $0.others } }
            fileIndex = Dictionary(files.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            recommended = recommendations(photos: allPhotos, photoGroups: found[.duplicates]?.photoGroups ?? [],
                                          fileGroups: found[.icloudDuplicates]?.fileGroups ?? [], now: Date())
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
        return await deletePhotoItems(items)
    }

    /// Every recommended item that is still checked.
    var selectedRecommended: [String] {
        recommended.flatMap(\.ids).filter { selection.contains($0) }
    }

    var selectedRecommendedBytes: Int64 {
        selectedRecommended.reduce(0) { $0 + (photoIndex[$1].map(estimatedBytes) ?? fileIndex[$1]?.bytes ?? 0) }
    }

    func selectAllRecommended() {
        selection.formUnion(recommended.flatMap(\.ids))
    }

    /// Deletes the checked recommended photos in one Photos confirmation, then trashes the checked files.
    func deleteRecommended() async {
        let ids = selectedRecommended
        let photos = ids.compactMap { photoIndex[$0] }
        if !photos.isEmpty { _ = await deletePhotoItems(photos) }
        let files = ids.compactMap { fileIndex[$0] }
        if !files.isEmpty {
            let removed = await Task.detached { Self.trash(files) }.value
            freedThisSession += files.filter { removed.contains($0.id) }.reduce(0) { $0 + $1.bytes }
            removeEverywhere(removed)
        }
    }

    private func deletePhotoItems(_ items: [PhotoInfo]) async -> Bool {
        guard !items.isEmpty else { return false }
        let ids = items.map(\.id)
        do {
            try await Self.deleteAssets(ids)
        } catch {
            return false
        }
        freedThisSession += items.reduce(0) { $0 + estimatedBytes($1) }
        removeEverywhere(Set(ids))
        return true
    }

    /// Photos runs the change block on its own queue, so it must not be tied to the main actor.
    nonisolated private static func deleteAssets(_ ids: [String]) async throws {
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil))
        }
    }

    /// Moves the selected iCloud Drive files to the Trash, coordinated with iCloud, off the main thread.
    func trashFiles(in category: PhoneCategory) async -> Int {
        guard let content = results[category] else { return 0 }
        let items = (content.files + content.fileGroups.flatMap(\.others)).filter { selection.contains($0.id) }
        let removed = await Task.detached { Self.trash(items) }.value
        freedThisSession += items.filter { removed.contains($0.id) }.reduce(0) { $0 + $1.bytes }
        removeEverywhere(removed)
        return removed.count
    }

    nonisolated private static func trash(_ items: [FileInfo]) -> Set<String> {
        var removed = Set<String>()
        _ = FolderAccess.withFolder { _ in
            let coordinator = NSFileCoordinator()
            for file in items {
                var error: NSError?
                coordinator.coordinate(writingItemAt: file.url, options: .forDeleting, error: &error) { url in
                    if (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) != nil { removed.insert(file.id) }
                }
            }
        }
        return removed
    }

    /// Merges each selected contact group into its fullest contact, after saving a vCard backup of all of them.
    /// Every field the app can read is carried over with its label; nothing is merged across accounts.
    func mergeContacts() async -> Int {
        guard let groups = results[.contacts]?.contactGroups.filter({ selection.contains($0.keep.id) && $0.sameContainer }), !groups.isEmpty else { return 0 }
        let mergedIDs = await Task.detached { Self.merge(groups) }.value
        results[.contacts]?.contactGroups.removeAll { mergedIDs.contains($0.keep.id) }
        selection.subtract(mergedIDs)
        return mergedIDs.count
    }

    nonisolated private static func merge(_ groups: [ContactGroup]) -> Set<String> {
        let store = CNContactStore()
        let ids = groups.flatMap { [$0.keep.id] + $0.others.map(\.id) }
        let contacts = ContactScanner.raw(ids, store: store)
        guard !contacts.isEmpty, backup(contacts) else { return [] }
        let byID = Dictionary(contacts.map { ($0.identifier, $0) }, uniquingKeysWith: { a, _ in a })
        var mergedIDs = Set<String>()
        for group in groups {
            guard let keeper = byID[group.keep.id]?.mutableCopy() as? CNMutableContact else { continue }
            let others = group.others.compactMap { byID[$0.id] }
            for other in others { Self.absorb(other, into: keeper) }
            let request = CNSaveRequest()
            request.update(keeper)
            for other in others {
                if let copy = other.mutableCopy() as? CNMutableContact { request.delete(copy) }
            }
            if (try? store.execute(request)) != nil { mergedIDs.insert(group.keep.id) }
        }
        return mergedIDs
    }

    /// Copies what `other` has and `keeper` lacks, keeping each value's label.
    nonisolated private static func absorb(_ other: CNContact, into keeper: CNMutableContact) {
        let phones = Set(keeper.phoneNumbers.map { normalizedPhone($0.value.stringValue) })
        keeper.phoneNumbers += other.phoneNumbers.filter { !phones.contains(normalizedPhone($0.value.stringValue)) }
        let emails = Set(keeper.emailAddresses.map { ($0.value as String).lowercased() })
        keeper.emailAddresses += other.emailAddresses.filter { !emails.contains(($0.value as String).lowercased()) }
        let addresses = Set(keeper.postalAddresses.map { CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress) })
        keeper.postalAddresses += other.postalAddresses.filter { !addresses.contains(CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress)) }
        let urls = Set(keeper.urlAddresses.map { ($0.value as String).lowercased() })
        keeper.urlAddresses += other.urlAddresses.filter { !urls.contains(($0.value as String).lowercased()) }
        if keeper.givenName.isEmpty { keeper.givenName = other.givenName }
        if keeper.familyName.isEmpty { keeper.familyName = other.familyName }
        if keeper.organizationName.isEmpty { keeper.organizationName = other.organizationName }
        if keeper.jobTitle.isEmpty { keeper.jobTitle = other.jobTitle }
        if keeper.birthday == nil { keeper.birthday = other.birthday }
        if keeper.imageData == nil, let image = other.imageData { keeper.imageData = image }
    }

    /// Writes every contact about to change to Files, in Neuralyzer's folder, before merging.
    nonisolated private static func backup(_ contacts: [CNContact]) -> Bool {
        guard let data = try? CNContactVCardSerialization.data(with: contacts) else { return false }
        let folder = URL.documentsDirectory.appending(path: "Contact Backups", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)).replacingOccurrences(of: ":", with: ".")
        return (try? data.write(to: folder.appending(path: "Contacts \(stamp) \(UUID().uuidString.prefix(4)).vcf"))) != nil
    }

    private func removeEverywhere(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        recommended = recommended.compactMap { r in
            let left = r.ids.filter { !ids.contains($0) }
            guard !left.isEmpty else { return nil }
            let bytes = left.reduce(Int64(0)) { $0 + (photoIndex[$1].map(estimatedBytes) ?? fileIndex[$1]?.bytes ?? 0) }
            return Recommendation(reason: r.reason, ids: left, bytes: bytes)
        }
        for (category, var content) in results {
            content.photos.removeAll { ids.contains($0.id) }
            let dropped = content.photoGroups.filter { ids.contains($0.keep.id) }.flatMap(\.others).map(\.id)
            selection.subtract(dropped)
            content.photoGroups = removing(ids, from: content.photoGroups)
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
