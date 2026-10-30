import Foundation

/// Old Claude Code session logs inside one project folder: `*.jsonl` files and session folders
/// named by UUID, untouched for an hour. Memory and anything else in the folder never match.
public func claudeSessionEntries(in folder: URL, olderThan cutoff: Date) -> [URL] {
    children(of: folder).filter { url in
        let name = url.lastPathComponent
        let isSession = url.pathExtension == "jsonl" || UUID(uuidString: name) != nil
        return isSession && newestModification(of: url) < cutoff
    }
}

public struct ClaudeRule: CategoryRule {
    public let id = CategoryID.claudeCode
    public init() {}

    /// Rebuildable folders at the top of `~/.claude`.
    static let looseFolders = ["shell-snapshots", "todos", "statsig", "telemetry", "paste-cache"]
    /// Cache folders inside the Claude app's support folder.
    static let appCaches = ["Cache", "Code Cache", "GPUCache", "DawnGraphiteCache", "DawnWebGPUCache", "GraphiteDawnCache", "logs"]

    public func scan(_ env: ScanEnvironment) async -> [Item] {
        let claude = env.home.appending(".claude")
        let projects = claude.appending("projects")
        let cutoff = env.now.addingTimeInterval(-3600)
        var items: [Item] = children(of: projects).compactMap { folder in
            let bytes = claudeSessionEntries(in: folder, olderThan: cutoff).reduce(Int64(0)) { $0 + allocatedSize(of: $1) }
            return makeItem(folder, root: projects, name: Self.projectName(folder, home: env.home), category: id,
                            action: .deleteContents(keep: ["memory"]), preselected: false, env: env, bytes: bytes)
        }
        items += Self.looseFolders.compactMap {
            makeItem(claude.appending($0), root: claude, category: id, action: .delete, preselected: true, env: env)
        }
        // Leftover clones from plugin installs. Installed plugins themselves are never listed.
        let pluginCache = claude.appending("plugins/cache")
        items += childrenAsItems(of: pluginCache, category: id, action: .delete, preselected: true, env: env,
                                 include: { $0.lastPathComponent.hasPrefix("temp_git_") })
        let app = env.home.appending("Library/Application Support/Claude")
        items += Self.appCaches.compactMap {
            makeItem(app.appending($0), root: app, name: "Claude \($0)", category: id, action: .delete, preselected: true, env: env)
        }
        return items
    }

    /// `-Users-me-Projects-app` reads as `Projects-app`.
    static func projectName(_ folder: URL, home: URL) -> String {
        let prefix = home.path.replacingOccurrences(of: "/", with: "-")
        let name = folder.lastPathComponent
        guard name.hasPrefix(prefix) else { return name }
        let rest = name.dropFirst(prefix.count).drop { $0 == "-" }
        return rest.isEmpty ? "Home" : String(rest)
    }
}
