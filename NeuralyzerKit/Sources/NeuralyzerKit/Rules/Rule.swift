import Foundation

/// Finds the items for one category.
public protocol CategoryRule: Sendable {
    var id: CategoryID { get }
    func scan(_ env: ScanEnvironment) async -> [Item]
}

/// Builds one row for `url`, or nil when it is missing, empty, or refused by the safety guard.
func makeItem(
    _ url: URL, root: URL, name: String? = nil, category: CategoryID, action: Action,
    preselected: Bool, env: ScanEnvironment, bytes: Int64? = nil
) -> Item? {
    guard FileManager.default.fileExists(atPath: url.path),
          SafetyGuard(home: env.home).allows(url, root: root) else { return nil }
    let size = bytes ?? allocatedSize(of: url)
    guard size > 0 else { return nil }
    return Item(id: url.path, category: category, name: name ?? url.lastPathComponent, url: url,
                root: root, bytes: size, action: action, preselected: preselected)
}

/// One row per immediate child of `root`.
func childrenAsItems(
    of root: URL, category: CategoryID, action: Action, preselected: Bool, env: ScanEnvironment,
    name: (URL) -> String = { $0.lastPathComponent }, include: (URL) -> Bool = { _ in true }
) -> [Item] {
    children(of: root).filter(include).compactMap {
        makeItem($0, root: root, name: name($0), category: category, action: action, preselected: preselected, env: env)
    }
}

func children(of url: URL) -> [URL] {
    (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? []
}

extension URL {
    func appending(_ path: String) -> URL { appendingPathComponent(path) }
}
