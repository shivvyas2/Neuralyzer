import Foundation

public struct CleanReport: Sendable {
    /// Bytes removed for good.
    public var freed: Int64 = 0
    /// Bytes moved to the Trash, which free up only once the Trash is emptied.
    public var trashed: Int64 = 0
    /// Where trashed items ended up, so they alone can be deleted for good.
    public var trashedURLs: [URL] = []
    /// Items that could not be cleaned.
    public var failures: [String] = []
}

/// Carries out a clean and writes one log line per item.
public actor Cleaner {
    let env: ScanEnvironment
    let log: URL
    let trash: @Sendable (URL) throws -> URL?
    let guardian: SafetyGuard

    public init(
        env: ScanEnvironment,
        log: URL? = nil,
        trash: @escaping @Sendable (URL) throws -> URL? = { url in
            var result: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &result)
            return result as URL?
        }
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
            // Removed in Xcode since the scan: nothing left to do.
            guard fm.fileExists(atPath: item.url.path) else {
                write("skipped", 0, item.id)
                return
            }
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
                try remove(item.url)
                report.freed += item.bytes
                write("delete", item.bytes, item.url.path)
            case .trash:
                if let landed = try trash(item.url) { report.trashedURLs.append(landed) }
                report.trashed += item.bytes
                write("trash", item.bytes, item.url.path)
            case .deleteContents(let keep):
                let cutoff = env.now.addingTimeInterval(-3600)
                for entry in claudeSessionEntries(in: item.url, olderThan: cutoff) where !keep.contains(entry.lastPathComponent) {
                    let bytes = allocatedSize(of: entry)
                    do {
                        try remove(entry)
                        report.freed += bytes
                        write("delete", bytes, entry.path)
                    } catch {
                        write(Self.isMissing(error) ? "skipped" : "failed", 0, entry.path)
                    }
                }
            case .simctlDeleteDevice, .simctlDeleteRuntime:
                break
            }
        } catch where Self.isMissing(error) {
            write("skipped", 0, item.url.path)
        } catch {
            write("failed", 0, item.url.path)
            report.failures.append(item.name)
        }
    }

    /// Removes a file or folder. Trees made read-only, like Go's module cache, are made
    /// writable and tried once more.
    private func remove(_ url: URL) throws {
        do {
            try FileManager.default.removeItem(at: url)
        } catch where !Self.isMissing(error) {
            makeWritable(url)
            try FileManager.default.removeItem(at: url)
        }
    }

    private func makeWritable(_ url: URL) {
        let fm = FileManager.default
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        guard let walker = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return }
        for case let child as URL in walker {
            let v = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if v?.isDirectory == true && v?.isSymbolicLink != true {
                try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: child.path)
            }
        }
    }

    static func isMissing(_ error: Error) -> Bool {
        let e = error as NSError
        if e.domain == NSCocoaErrorDomain && (e.code == NSFileNoSuchFileError || e.code == NSFileReadNoSuchFileError) { return true }
        if e.domain == NSPOSIXErrorDomain && e.code == Int(ENOENT) { return true }
        if let underlying = e.userInfo[NSUnderlyingErrorKey] as? NSError { return isMissing(underlying) }
        return false
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

    /// Permanently removes items an earlier clean moved to the Trash, and nothing else
    /// that is in the Trash. Returns the bytes freed.
    public func deleteTrashed(_ urls: [URL]) async -> Int64 {
        let trashFolder = env.home.appendingPathComponent(".Trash")
        var freed: Int64 = 0
        for entry in urls where guardian.allows(entry, root: trashFolder) {
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
