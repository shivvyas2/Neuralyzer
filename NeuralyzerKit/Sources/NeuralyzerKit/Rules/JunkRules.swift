import Foundation

func isInstaller(_ url: URL) -> Bool { ["dmg", "pkg"].contains(url.pathExtension.lowercased()) }

public struct JunkRule: CategoryRule {
    public let id = CategoryID.junk
    public init() {}

    public func scan(_ env: ScanEnvironment) async -> [Item] {
        let logs = env.home.appending("Library/Logs")
        var items = [makeItem(logs.appending("DiagnosticReports"), root: logs, name: "Crash Reports",
                              category: id, action: .delete, preselected: true, env: env)].compactMap { $0 }
        items += childrenAsItems(of: env.home.appending("Downloads"), category: id, action: .trash,
                                 preselected: false, env: env, include: isInstaller)
        return items
    }
}

public struct TrashRule: CategoryRule {
    public let id = CategoryID.trash
    public init() {}

    public func scan(_ env: ScanEnvironment) async -> [Item] {
        childrenAsItems(of: env.home.appending(".Trash"), category: id, action: .delete, preselected: false, env: env)
    }
}

public struct VMRule: CategoryRule {
    public let id = CategoryID.vms
    public init() {}

    static let places: [(path: String, name: String)] = [
        ("Library/Containers/com.docker.docker", "Docker"),
        ("Library/Containers/com.utmapp.UTM", "UTM"),
        ("Parallels", "Parallels"),
        ("Virtual Machines.localized", "VMware Fusion"),
        (".orbstack", "OrbStack"),
        (".tart", "Tart"),
        (".ollama/models", "Ollama models"),
    ]

    public func scan(_ env: ScanEnvironment) async -> [Item] {
        Self.places.compactMap { place in
            let url = env.home.appending(place.path)
            return makeItem(url, root: url.deletingLastPathComponent(), name: place.name, category: id,
                            action: .trash, preselected: false, env: env)
        }
    }
}

public struct ProjectBuildRule: CategoryRule {
    public let id = CategoryID.projectBuilds
    public init() {}

    static let names: Set<String> = ["node_modules", ".build", ".next", "build", "DerivedData"]
    static let maxDepth = 6
    /// A folder named `build` is only offered when one of these sits beside it, since
    /// plenty of projects keep committed files in `build`.
    static let buildSystemFiles = ["package.json", "build.gradle", "build.gradle.kts", "CMakeLists.txt", "Package.swift", "pubspec.yaml"]

    static func isGeneratedBuild(_ url: URL) -> Bool {
        let parent = url.deletingLastPathComponent()
        let fm = FileManager.default
        if buildSystemFiles.contains(where: { fm.fileExists(atPath: parent.appendingPathComponent($0).path) }) { return true }
        return children(of: parent).contains { $0.pathExtension == "xcodeproj" }
    }

    public func scan(_ env: ScanEnvironment) async -> [Item] { find(env) }

    private func find(_ env: ScanEnvironment) -> [Item] {
        let projects = env.home.appending("Projects").resolvingSymlinksInPath()
        guard let walker = FileManager.default.enumerator(
            at: projects, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [],
            errorHandler: { _, _ in true }
        ) else { return [] }
        var items: [Item] = []
        for case let url as URL in walker {
            let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard v?.isDirectory == true, v?.isSymbolicLink != true else { continue }
            let name = url.lastPathComponent
            if Self.names.contains(name) {
                walker.skipDescendants()
                if name == "build" && !Self.isGeneratedBuild(url) { continue }
                let relative = String(url.resolvingSymlinksInPath().path.dropFirst(projects.path.count + 1))
                // A `build` folder can still hold something hand made, so it goes to the Trash.
                let action: Action = name == "build" ? .trash : .delete
                if let item = makeItem(url, root: projects, name: relative, category: id, action: action,
                                       preselected: false, env: env) { items.append(item) }
            } else if name == ".git" || walker.level >= Self.maxDepth {
                walker.skipDescendants()
            }
        }
        return items
    }
}
