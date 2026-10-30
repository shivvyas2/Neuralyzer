#if DEBUG
import AppKit

/// Debug builds only: with NEURALYZER_SNAPSHOT=/path.png set, the app saves its own window
/// a few seconds after launch, so screens can be checked without screen recording access.
enum Snapshot {
    static func scheduleIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["NEURALYZER_SNAPSHOT"] else { return }
        let delay = Double(ProcessInfo.processInfo.environment["NEURALYZER_SNAPSHOT_DELAY"] ?? "") ?? 4
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let view = NSApp.windows.first(where: \.isVisible)?.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
    }

    /// NEURALYZER_ASSUME_ACCESS=1 skips the Full Disk Access gate for layout checks.
    static var assumeAccess: Bool { ProcessInfo.processInfo.environment["NEURALYZER_ASSUME_ACCESS"] == "1" }
}
#endif
