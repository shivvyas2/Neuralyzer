import Foundation

/// Runs every category rule at once and yields each category as it finishes.
public struct DiskScanner: Sendable {
    public init() {}

    public static func all() -> [any CategoryRule] {
        [XcodeRule(), SimulatorRule(), ClaudeRule(), PackageCacheRule(), ProjectBuildRule(), VMRule(),
         AppCacheRule(), JunkRule(), TrashRule(), LargeFileRule(), OldFileRule()]
    }

    public func scan(_ env: ScanEnvironment, rules: [any CategoryRule] = DiskScanner.all()) -> AsyncStream<CategoryResult> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: CategoryResult.self) { group in
                    for rule in rules {
                        group.addTask { CategoryResult(id: rule.id, items: await rule.scan(env)) }
                    }
                    for await result in group where !result.items.isEmpty {
                        continuation.yield(result)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Used and total bytes of the volume holding `home`.
public func diskSpace(home: URL) -> (used: Int64, total: Int64) {
    let v = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
    let total = Int64(v?.volumeTotalCapacity ?? 0)
    let free = v?.volumeAvailableCapacityForImportantUsage ?? 0
    return (max(0, total - free), total)
}
