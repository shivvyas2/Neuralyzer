import Foundation

public struct CleanReport: Sendable {
    /// Bytes removed for good.
    public var freed: Int64 = 0
    /// Bytes moved to the Trash, which free up only once the Trash is emptied.
    public var trashed: Int64 = 0
    /// Items that could not be cleaned.
    public var failures: [String] = []
}

/// Carries out a clean and writes one log line per item.
public actor Cleaner {
    let env: ScanEnvironment
    let log: URL
    let trash: @Sendable (URL) throws -> Void
    let guardian: SafetyGuard

    public init(
        env: ScanEnvironment,
        log: URL? = nil,
        trash: @escaping @Sendable (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) {
        self.env = env
        self.log = log ?? env.home.appendingPathComponent("Library/Logs/Neuralyzer/clean.log")
        self.trash = trash
        self.guardian = SafetyGuard(home: env.home)
    }

    public func clean(_ items: [Item]) async -> CleanReport {
        var report = CleanReport()
        for item in items {
            await clean(item, into: &report)
        }
        return report
    }

    private func clean(_ item: Item, into report: inout CleanReport) async {
        let fm = FileManager.default
        switch item.action {
        case .simctlDeleteDevice(let udid):
            await run(["simctl", "delete", udid], item, &report)
            return
        case .simctlDeleteRuntime(let id):
            await run(["simctl", "runtime", "delete", id], item, &report)
            return
        default:
            break
        }
        guard fm.fileExists(atPath: item.url.path) else {
            write("skipped", 0, item.url.path)
            return
        }
        guard let root = item.root, guardian.allows(item.url, root: root) else {
            write("refused", 0, item.url.path)
            report.failures.append(item.name)
            return
        }
        do {
            switch item.action {
            case .delete:
                try fm.removeItem(at: item.url)
                report.freed += item.bytes
                write("delete", item.bytes, item.url.path)
            case .trash:
                try trash(item.url)
                report.trashed += item.bytes
                write("trash", item.bytes, item.url.path)
            case .deleteContents(let keep):
                let cutoff = env.now.addingTimeInterval(-3600)
                for entry in claudeSessionEntries(in: item.url, olderThan: cutoff) where !keep.contains(entry.lastPathComponent) {
                    let bytes = allocatedSize(of: entry)
                    try fm.removeItem(at: entry)
                    report.freed += bytes
                    write("delete", bytes, entry.path)
                }
            case .simctlDeleteDevice, .simctlDeleteRuntime:
                break
            }
        } catch {
            write("failed", 0, item.url.path)
            report.failures.append(item.name)
        }
    }

    private func run(_ args: [String], _ item: Item, _ report: inout CleanReport) async {
        do {
            _ = try await env.runner.run(SimulatorRule.xcrun, args)
            report.freed += item.bytes
            write(args.joined(separator: " "), item.bytes, item.id)
        } catch {
            write("failed", 0, item.id)
            report.failures.append(item.name)
        }
    }

    /// Permanently removes everything in the Trash. Returns the bytes freed.
    public func emptyTrash() async -> Int64 {
        let trashFolder = env.home.appendingPathComponent(".Trash")
        var freed: Int64 = 0
        for entry in children(of: trashFolder) where guardian.allows(entry, root: trashFolder) {
            let bytes = allocatedSize(of: entry)
            if (try? FileManager.default.removeItem(at: entry)) != nil {
                freed += bytes
                write("delete", bytes, entry.path)
            }
        }
        return freed
    }

    private func write(_ action: String, _ bytes: Int64, _ target: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date()))\t\(action)\t\(bytes)\t\(target)\n"
        let fm = FileManager.default
        try? fm.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: log) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            fm.createFile(atPath: log.path, contents: Data(line.utf8))
        }
    }
}
