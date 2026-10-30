import Foundation

/// Decides whether a path may be cleaned. Anything outside its category root is refused,
/// as is anything Claude Code needs to keep working.
public struct SafetyGuard: Sendable {
    public let home: URL

    /// Folder names under `~/.claude` that are never touched, at any depth.
    static let claudeProtectedAnywhere: Set<String> = ["memory", "skills", "agents", "commands"]
    /// Files at the top of `~/.claude` that are never touched.
    static let claudeProtectedTop: Set<String> = ["settings.json", "settings.local.json", "CLAUDE.md", ".credentials.json"]

    public init(home: URL) {
        self.home = home.resolvingSymlinksInPath()
    }

    public func allows(_ url: URL, root: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        guard path != home.path, path != rootPath, path.hasPrefix(rootPath + "/") else { return false }
        return !isClaudeProtected(path)
    }

    private func isClaudeProtected(_ path: String) -> Bool {
        let claude = home.appendingPathComponent(".claude").path
        guard path == claude || path.hasPrefix(claude + "/") else { return false }
        let parts = path.dropFirst(claude.count).split(separator: "/").map(String.init)
        guard let first = parts.first else { return true }
        if Self.claudeProtectedTop.contains(first) { return true }
        if first == "plugins" && (parts.count < 3 || parts[1] != "cache") { return true }
        return parts.contains { Self.claudeProtectedAnywhere.contains($0) }
    }
}
