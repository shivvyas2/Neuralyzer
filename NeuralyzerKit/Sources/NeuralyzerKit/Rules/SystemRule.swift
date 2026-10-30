import Foundation

/// System level clutter: caches and logs macOS and apps keep outside your home folder,
/// simulator system caches, old temp files, Time Machine local snapshots, old macOS
/// installers, and iPhone backups. Nothing here is preselected.
public struct SystemRule: CategoryRule {
    public let id = CategoryID.system
    public init() {}

    /// Untouched this long, a temp or cache entry is no longer in use.
    static let tempAge: TimeInterval = 3 * 86400

    public func scan(_ env: ScanEnvironment) async -> [Item] {
        let library = env.systemRoot.appending("Library")
        // Owned by the system, so these are removed with administrator rights.
        var items: [Item] = ["Caches", "Logs", "Developer/CoreSimulator/Caches"].flatMap {
            childrenAsItems(of: library.appending($0), category: id, action: .adminDelete, preselected: false, env: env)
        }

        let cutoff = env.now.addingTimeInterval(-Self.tempAge)
        for dir in env.tempDirs {
            items += childrenAsItems(of: dir, category: id, action: .delete, preselected: false, env: env,
                                     include: { newestModification(of: $0) < cutoff })
        }

        let applications = env.systemRoot.appending("Applications")
        items += childrenAsItems(of: applications, category: id, action: .trash, preselected: false, env: env,
                                 name: { $0.deletingPathExtension().lastPathComponent },
                                 include: { $0.lastPathComponent.hasPrefix("Install macOS") && $0.pathExtension == "app" })

        let backups = env.home.appending("Library/Application Support/MobileSync/Backup")
        items += childrenAsItems(of: backups, category: id, action: .trash, preselected: false, env: env,
                                 name: { "\(Self.deviceName($0)) backup" })

        return items + (await snapshots(env))
    }

    /// Time Machine snapshots carry no size, since APFS shares their blocks with live files.
    private func snapshots(_ env: ScanEnvironment) async -> [Item] {
        guard let data = try? await env.runner.run("/usr/bin/tmutil", ["listlocalsnapshots", "/"]) else { return [] }
        return String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { line in
            let name = line.trimmingCharacters(in: .whitespaces)
            let prefix = "com.apple.TimeMachine.", suffix = ".local"
            guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
            let stamp = String(name.dropFirst(prefix.count).dropLast(suffix.count))
            return Item(id: "snapshot:\(stamp)", category: id, name: "Time Machine snapshot \(stamp.prefix(10))",
                        url: env.systemRoot, root: nil, bytes: 0, action: .tmutilDeleteSnapshot(date: stamp), preselected: false)
        }
    }

    static func deviceName(_ backup: URL) -> String {
        let info = backup.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: info),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let name = plist["Device Name"] as? String else { return "iPhone" }
        return name
    }
}
