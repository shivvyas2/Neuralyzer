import Foundation

/// One group of things that are safe to delete, with the reason in plain words.
public struct Recommendation: Sendable, Identifiable {
    public let reason: String
    public let items: [Item]
    public var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    public var id: String { reason }
}

/// What Neuralyzer suggests cleaning: only data that rebuilds itself, plus crash reports and installers
/// already used. Personal files, VMs, archives, the Trash, and System items are never suggested. Largest first.
public func recommendations(_ results: [CategoryResult]) -> [Recommendation] {
    let items = results.flatMap(\.items)
    func pick(_ category: CategoryID, _ test: (Item) -> Bool) -> [Item] { items.filter { $0.category == category && test($0) } }

    let rules: [(String, [Item])] = [
        ("Xcode build data Xcode rebuilds", pick(.xcode) { $0.action == .delete }),
        ("Simulators that no longer run", pick(.simulators) { $0.preselected }),
        ("Package downloads your tools fetch again", pick(.packageCaches) { $0.preselected }),
        ("App caches apps rebuild", pick(.appCaches) { $0.preselected }),
        ("Claude Code caches", pick(.claudeCode) { $0.preselected }),
        ("Crash reports", pick(.junk) { $0.action == .delete }),
        ("Installers you already used", pick(.junk) { $0.action == .trash }),
    ]
    return rules.compactMap { reason, list in list.isEmpty ? nil : Recommendation(reason: reason, items: list) }
        .sorted { $0.bytes > $1.bytes }
}
