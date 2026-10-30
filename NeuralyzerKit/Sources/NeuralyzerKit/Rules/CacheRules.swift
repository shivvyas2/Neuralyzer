import Foundation

/// Package manager caches, relative to home. Each is one row.
let packageCachePaths = [
    ".npm/_cacache", "Library/pnpm/store", "Library/Caches/Yarn", ".bun/install/cache", "Library/Caches/pip",
    "Library/Caches/Homebrew", "Library/Caches/CocoaPods", ".gradle/caches", ".cargo/registry", "go/pkg/mod",
    "Library/Caches/org.swift.swiftpm",
]

public struct PackageCacheRule: CategoryRule {
    public let id = CategoryID.packageCaches
    public init() {}

    public func scan(_ env: ScanEnvironment) async -> [Item] {
        var items = packageCachePaths.compactMap { path -> Item? in
            let url = env.home.appending(path)
            return makeItem(url, root: url.deletingLastPathComponent(), name: Self.name(path), category: id,
                            action: .delete, preselected: true, env: env)
        }
        // ~/.cache holds tool downloads such as models, so nothing there is preselected.
        items += childrenAsItems(of: env.home.appending(".cache"), category: id, action: .delete, preselected: false, env: env)
        return items
    }

    static func name(_ path: String) -> String {
        switch path {
        case ".npm/_cacache": "npm"
        case "Library/pnpm/store": "pnpm"
        case ".bun/install/cache": "Bun"
        case ".gradle/caches": "Gradle"
        case ".cargo/registry": "Cargo"
        case "go/pkg/mod": "Go modules"
        case "Library/Caches/org.swift.swiftpm": "Swift Package Manager"
        default: URL(fileURLWithPath: path).lastPathComponent
        }
    }
}

public struct AppCacheRule: CategoryRule {
    public let id = CategoryID.appCaches
    public init() {}

    public func scan(_ env: ScanEnvironment) async -> [Item] {
        let claimed = Set(packageCachePaths.map { env.home.appending($0).standardizedFileURL.path })
        let caches = env.home.appending("Library/Caches")
        var items = childrenAsItems(of: caches, category: id, action: .delete, preselected: true, env: env,
                                    include: { !claimed.contains($0.standardizedFileURL.path) })
        let logs = env.home.appending("Library/Logs")
        items += childrenAsItems(of: logs, category: id, action: .delete, preselected: true, env: env,
                                 include: { !["DiagnosticReports", "Neuralyzer"].contains($0.lastPathComponent) })
        return items
    }
}
