import CryptoKit
import Foundation

public struct FileInfo: Sendable, Hashable, Identifiable {
    public let url: URL
    public let name: String
    public let bytes: Int64
    public let modified: Date
    /// False for an iCloud file that is not downloaded to the phone.
    public let isLocal: Bool

    public var id: String { url.path }

    public init(url: URL, name: String, bytes: Int64, modified: Date, isLocal: Bool) {
        self.url = url
        self.name = name
        self.bytes = bytes
        self.modified = modified
        self.isLocal = isLocal
    }
}

public struct FileGroup: Sendable, Hashable {
    public let keep: FileInfo
    public let others: [FileInfo]
    /// True when every copy was compared byte for byte. Unverified groups are never preselected.
    public let verified: Bool

    public init(keep: FileInfo, others: [FileInfo], verified: Bool) {
        self.keep = keep
        self.others = others
        self.verified = verified
    }
}

/// Every file under `folder`, including iCloud files that are not downloaded. Never triggers a download.
public func listFiles(in folder: URL) -> [FileInfo] {
    let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey,
                                  .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
    guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys,
                                                      options: [.skipsPackageDescendants], errorHandler: { _, _ in true }) else { return [] }
    var files: [FileInfo] = []
    while let url = walker.nextObject() as? URL {
        let name = url.lastPathComponent
        guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
        let modified = v.contentModificationDate ?? .distantPast
        if name.hasPrefix(".") {
            if name.hasSuffix(".icloud"), let placeholder = placeholderInfo(url, modified: modified) { files.append(placeholder) }
            continue
        }
        // An iCloud item shown under its real name but not downloaded is not local; reading it would download it.
        let local = v.isUbiquitousItem != true || v.ubiquitousItemDownloadingStatus == .current
        files.append(FileInfo(url: url, name: name, bytes: Int64(v.fileSize ?? 0), modified: modified, isLocal: local))
    }
    return files
}

/// An iCloud placeholder (`.name.icloud`) is a small plist holding the real name and size.
private func placeholderInfo(_ url: URL, modified: Date) -> FileInfo? {
    guard let data = try? Data(contentsOf: url),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
    let fallback = String(url.lastPathComponent.dropFirst().dropLast(".icloud".count))
    let name = plist["NSURLNameKey"] as? String ?? fallback
    let bytes = (plist["NSURLFileSizeKey"] as? NSNumber)?.int64Value ?? 0
    // The real item's URL, so trashing acts on the file and not on its placeholder.
    return FileInfo(url: url.deletingLastPathComponent().appendingPathComponent(name), name: name, bytes: bytes,
                    modified: modified, isLocal: false)
}

/// SHA-256 of a local file, read in 1 MB chunks.
public func sha256(of url: URL) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }
    var hasher = SHA256()
    while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
        hasher.update(data: chunk)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

/// Copies of the same file. Local copies must match byte for byte; a copy that is only in
/// iCloud can only match by name and size, so its group is marked unverified. The oldest copy is kept.
public func duplicateFileGroups(_ files: [FileInfo], hash: (URL) -> String?) -> [FileGroup] {
    var groups: [FileGroup] = []
    for sameSize in Dictionary(grouping: files.filter { $0.bytes > 0 }, by: \.bytes).values where sameSize.count > 1 {
        let local = sameSize.filter(\.isLocal)
        var byHash: [String: [FileInfo]] = [:]
        if local.count > 1 {
            for file in local { if let h = hash(file.url) { byHash[h, default: []].append(file) } }
        }
        var inVerified = Set<URL>()
        var candidates = local
        for copies in byHash.values where copies.count > 1 {
            let group = makeGroup(copies, verified: true)
            groups.append(group)
            // Only the kept copy of a verified group may also stand for it in a name match.
            inVerified.formUnion(group.others.map(\.url))
        }
        candidates.removeAll { inVerified.contains($0.url) }
        let cloud = sameSize.filter { !$0.isLocal }
        for name in Set(cloud.map(\.name)) {
            let copies = (candidates + cloud).filter { $0.name == name }
            if copies.count > 1 { groups.append(makeGroup(copies, verified: false)) }
        }
    }
    return groups
}

private func makeGroup(_ copies: [FileInfo], verified: Bool) -> FileGroup {
    let keep = copies.min { ($0.modified, $0.url.path) < ($1.modified, $1.url.path) }!
    return FileGroup(keep: keep, others: copies.filter { $0 != keep }.sorted { $0.url.path < $1.url.path }, verified: verified)
}

/// Files over `largeBytes`, or over `oldBytes` and not modified in `oldAge`. A file that is not on the
/// phone only has its placeholder's date, so it can count as large but never as old.
public func largeAndOld(_ files: [FileInfo], now: Date, largeBytes: Int64 = 100_000_000, oldBytes: Int64 = 10_000_000,
                        oldAge: TimeInterval = 180 * 86400) -> [FileInfo] {
    files.filter { $0.bytes > largeBytes || ($0.isLocal && $0.bytes > oldBytes && $0.modified < now.addingTimeInterval(-oldAge)) }
}
