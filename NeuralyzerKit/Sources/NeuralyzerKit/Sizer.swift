import Foundation

private let sizeKeys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey]

/// Bytes on disk for a file or a whole folder tree. Symlinks are not followed and
/// anything unreadable counts as zero.
public func allocatedSize(of url: URL) -> Int64 {
    guard let values = try? url.resourceValues(forKeys: Set(sizeKeys)) else { return 0 }
    if values.isSymbolicLink == true { return 0 }
    if values.isRegularFile == true { return Int64(values.totalFileAllocatedSize ?? 0) }
    guard let walker = FileManager.default.enumerator(
        at: url, includingPropertiesForKeys: sizeKeys, options: [], errorHandler: { _, _ in true }
    ) else { return 0 }
    var total: Int64 = 0
    for case let child as URL in walker {
        guard let v = try? child.resourceValues(forKeys: Set(sizeKeys)), v.isRegularFile == true else { continue }
        total += Int64(v.totalFileAllocatedSize ?? 0)
    }
    return total
}
