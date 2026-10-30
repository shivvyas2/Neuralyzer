import AppKit
import NeuralyzerKit
import Observation

@MainActor @Observable
final class ScanStore {
    var hasAccess = false
    var results: [CategoryID: CategoryResult] = [:]
    var selection: Set<Item.ID> = []
    var scanning = false
    var used: Int64 = 0
    var total: Int64 = 0

    private let env = ScanEnvironment.live()
    private var polling: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?

    /// Categories with something in them, largest first.
    var categories: [CategoryResult] {
        results.values.sorted { $0.bytes > $1.bytes }
    }

    init() {
        hasAccess = checkAccess()
        refreshSpace()
    }

    func startAccessPolling() {
        polling?.cancel()
        polling = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let granted = self.checkAccess()
                if granted != self.hasAccess { self.hasAccess = granted }
                if granted { return }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func checkAccess() -> Bool {
        #if DEBUG
        if Snapshot.assumeAccess { return true }
        #endif
        return Access.hasFullDiskAccess(home: env.home)
    }

    func scan() {
        scanTask?.cancel()
        scanning = true
        results = [:]
        selection = []
        refreshSpace()
        let env = env
        scanTask = Task { [weak self] in
            for await result in DiskScanner().scan(env) {
                guard let self else { return }
                self.results[result.id] = result
                self.selection.formUnion(result.items.filter(\.preselected).map(\.id))
            }
            self?.scanning = false
        }
    }

    func items(in category: CategoryID) -> [Item] {
        results[category]?.items ?? []
    }

    func selectedItems(in category: CategoryID) -> [Item] {
        items(in: category).filter { selection.contains($0.id) }
    }

    func toggle(_ item: Item) {
        if selection.contains(item.id) { selection.remove(item.id) } else { selection.insert(item.id) }
    }

    func blockers(for items: [Item]) -> [String] {
        runningBlockers(for: items) { bundle in
            !NSRunningApplication.runningApplications(withBundleIdentifier: bundle).isEmpty
        }
    }

    func clean(_ items: [Item]) async -> CleanReport {
        let report = await Cleaner(env: env).clean(items)
        drop(items)
        return report
    }

    /// Deletes for good only what this clean just moved to the Trash.
    func deleteTrashed(_ report: CleanReport) async {
        _ = await Cleaner(env: env).deleteTrashed(report.trashedURLs)
        refreshSpace()
    }

    /// Removes cleaned rows right away, then rescans so sizes are exact.
    private func drop(_ cleaned: [Item]) {
        let ids = Set(cleaned.map(\.id))
        for (id, result) in results {
            let left = result.items.filter { !ids.contains($0.id) }
            results[id] = left.isEmpty ? nil : CategoryResult(id: id, items: left)
        }
        selection.subtract(ids)
        refreshSpace()
    }

    func refreshSpace() {
        (used, total) = diskSpace(home: env.home)
    }

    func openFullDiskAccess() {
        NSWorkspace.shared.open(Access.fullDiskAccessURL)
    }
}
