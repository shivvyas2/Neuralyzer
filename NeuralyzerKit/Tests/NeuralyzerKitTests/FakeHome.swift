import Foundation

/// A throwaway home directory for tests. Removed when released.
final class FakeHome {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("neuralyzer-\(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        chmodAll(url)
        try? FileManager.default.removeItem(at: url)
    }

    func path(_ p: String) -> URL { url.appendingPathComponent(p) }

    @discardableResult
    func file(_ p: String, bytes: Int = 4096, modified: Date? = nil) -> URL {
        let u = path(p)
        try! FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: u.path, contents: Data(repeating: 1, count: bytes))
        if let modified { touch(u, modified) }
        return u
    }

    @discardableResult
    func dir(_ p: String) -> URL {
        let u = path(p)
        try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func link(_ p: String, to target: String) {
        let u = path(p)
        try! FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! FileManager.default.createSymbolicLink(at: u, withDestinationURL: path(target))
    }

    func touch(_ u: URL, _ date: Date) {
        try! FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: u.path)
    }

    func exists(_ p: String) -> Bool { FileManager.default.fileExists(atPath: path(p).path) }

    private func chmodAll(_ u: URL) {
        guard let e = FileManager.default.enumerator(atPath: u.path) else { return }
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: u.path)
        for case let p as String in e {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: u.appendingPathComponent(p).path)
        }
    }
}
