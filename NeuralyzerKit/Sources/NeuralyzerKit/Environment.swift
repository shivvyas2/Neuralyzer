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

/// Everything a scan or clean depends on, so tests can swap in a fake home and commands.
public struct ScanEnvironment: Sendable {
    public let home: URL
    public let now: Date
    public let runner: any CommandRunner

    public init(home: URL, now: Date = Date(), runner: any CommandRunner = ProcessRunner()) {
        self.home = home
        self.now = now
        self.runner = runner
    }

    public static func live() -> ScanEnvironment {
        ScanEnvironment(home: FileManager.default.homeDirectoryForCurrentUser)
    }
}
