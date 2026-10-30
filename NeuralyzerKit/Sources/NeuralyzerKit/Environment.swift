import Foundation

public protocol CommandRunner: Sendable {
    func run(_ launchPath: String, _ args: [String]) async throws -> Data
}

public struct CommandFailed: Error, Sendable {
    public let status: Int32
}

/// Runs a command and returns its standard output. A command still running after
/// `timeout` seconds is stopped and treated as failed, so a stuck tool cannot stall a scan.
public struct ProcessRunner: CommandRunner {
    let timeout: TimeInterval

    public init(timeout: TimeInterval = 60) { self.timeout = timeout }

    public func run(_ launchPath: String, _ args: [String]) async throws -> Data {
        let timeout = timeout
        return try await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: launchPath)
            p.arguments = args
            let out = Pipe()
            p.standardOutput = out
            p.standardError = FileHandle.nullDevice
            try p.run()
            let watchdog = DispatchWorkItem { if p.isRunning { p.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)
            defer { watchdog.cancel() }
            // Read before waiting so a large output cannot fill the pipe and stall the process.
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { throw CommandFailed(status: p.terminationStatus) }
            return data
        }.value
    }
}

/// Runs a shell script as administrator. macOS shows its own password prompt.
public protocol AdminRunner: Sendable {
    func run(shell script: String) async throws
}

/// Asks for the administrator password through AppleScript, once per script.
public struct AppleScriptAdmin: AdminRunner {
    public init() {}

    public func run(shell script: String) async throws {
        let escaped = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        // Long timeout: the person may take a while to type their password.
        _ = try await ProcessRunner(timeout: 600).run("/usr/bin/osascript", ["-e", "do shell script \"\(escaped)\" with administrator privileges"])
    }
}

/// Wraps a value in single quotes for the shell.
public func shellQuote(_ s: String) -> String {
    "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

/// The per-user temp and cache folders macOS keeps under /private/var/folders.
func darwinUserDirs() -> [URL] {
    [_CS_DARWIN_USER_TEMP_DIR, _CS_DARWIN_USER_CACHE_DIR].compactMap { name in
        var buffer = [CChar](repeating: 0, count: 1024)
        guard confstr(name, &buffer, buffer.count) > 0 else { return nil }
        return URL(fileURLWithPath: String(cString: buffer), isDirectory: true)
    }
}

/// Everything a scan or clean depends on, so tests can swap in a fake home and commands.
public struct ScanEnvironment: Sendable {
    public let home: URL
    public let now: Date
    public let runner: any CommandRunner
    public let admin: any AdminRunner
    /// Where /Library and /Applications live. Tests point this at a throwaway folder.
    public let systemRoot: URL
    /// The per-user temp and cache folders.
    public let tempDirs: [URL]

    public init(
        home: URL, now: Date = Date(), runner: any CommandRunner = ProcessRunner(), admin: any AdminRunner = AppleScriptAdmin(),
        systemRoot: URL = URL(fileURLWithPath: "/"), tempDirs: [URL]? = nil
    ) {
        self.home = home
        self.now = now
        self.runner = runner
        self.admin = admin
        self.systemRoot = systemRoot
        self.tempDirs = tempDirs ?? darwinUserDirs()
    }

    public static func live() -> ScanEnvironment {
        ScanEnvironment(home: FileManager.default.homeDirectoryForCurrentUser)
    }
}
