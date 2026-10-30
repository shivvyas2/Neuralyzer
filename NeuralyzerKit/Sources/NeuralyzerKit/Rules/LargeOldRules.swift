import CoreServices
import Foundation

let personalFolders = ["Downloads", "Desktop", "Documents", "Movies"]

/// Top level items in the personal folders, with their size. Installers belong to Junk.
func personalItems(_ env: ScanEnvironment) -> [(url: URL, root: URL, bytes: Int64)] {
    personalFolders.flatMap { folder -> [(url: URL, root: URL, bytes: Int64)] in
        let root = env.home.appending(folder)
        return children(of: root).filter { !isInstaller($0) && $0.lastPathComponent != ".localized" && $0.lastPathComponent != ".DS_Store" }
            .map { ($0, root, allocatedSize(of: $0)) }
    }
}

public struct LargeFileRule: CategoryRule {
    public let id = CategoryID.largeFiles
    let largeBytes: Int64

    public init(largeBytes: Int64 = 500_000_000) { self.largeBytes = largeBytes }

    public func scan(_ env: ScanEnvironment) async -> [Item] {
        personalItems(env).filter { $0.bytes > largeBytes }.compactMap {
            makeItem($0.url, root: $0.root, category: id, action: .trash, preselected: false, env: env, bytes: $0.bytes)
        }
    }
}

public struct OldFileRule: CategoryRule {
    public let id = CategoryID.oldFiles
    let largeBytes: Int64
    let oldBytes: Int64
    let oldAge: TimeInterval

    public init(largeBytes: Int64 = 500_000_000, oldBytes: Int64 = 50_000_000, oldAge: TimeInterval = 90 * 86400) {
        self.largeBytes = largeBytes
        self.oldBytes = oldBytes
        self.oldAge = oldAge
    }

    public func scan(_ env: ScanEnvironment) async -> [Item] {
        let cutoff = env.now.addingTimeInterval(-oldAge)
        return personalItems(env)
            .filter { $0.bytes > oldBytes && $0.bytes <= largeBytes && lastUsed($0.url) < cutoff }
            .compactMap {
                makeItem($0.url, root: $0.root, category: id, action: .trash, preselected: false, env: env, bytes: $0.bytes)
            }
    }
}

/// The later of Spotlight's last used date and the newest modification inside.
func lastUsed(_ url: URL) -> Date {
    var spotlight: Date?
    if let md = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) {
        spotlight = MDItemCopyAttribute(md, kMDItemLastUsedDate) as? Date
    }
    return max(spotlight ?? .distantPast, newestModification(of: url))
}

/// Newest modification date of a file, or of anything inside a folder.
func newestModification(of url: URL) -> Date {
    let key: Set<URLResourceKey> = [.contentModificationDateKey]
    var newest = (try? url.resourceValues(forKeys: key).contentModificationDate) ?? .distantPast
    guard let walker = FileManager.default.enumerator(
        at: url, includingPropertiesForKeys: Array(key), options: [], errorHandler: { _, _ in true }
    ) else { return newest }
    for case let child as URL in walker {
        if let d = try? child.resourceValues(forKeys: key).contentModificationDate, d > newest { newest = d }
    }
    return newest
}
