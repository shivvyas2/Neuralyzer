import Foundation

public enum Access {
    public static let fullDiskAccessURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!

    /// Full Disk Access is on when a folder macOS protects can be read.
    public static func hasFullDiskAccess(home: URL) -> Bool {
        let fm = FileManager.default
        for path in ["Library/Safari", "Library/Mail"] {
            if (try? fm.contentsOfDirectory(atPath: home.appendingPathComponent(path).path)) != nil { return true }
        }
        let tcc = home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        return (try? FileHandle(forReadingFrom: tcc))?.readData(ofLength: 1).isEmpty == false
    }
}

/// Apps that should be quit before cleaning these items, by display name.
public func runningBlockers(for items: [Item], isRunning: (String) -> Bool) -> [String] {
    let categories = Set(items.map(\.category))
    var apps: [(name: String, bundle: String)] = []
    if categories.contains(.xcode) || categories.contains(.simulators) { apps.append(("Xcode", "com.apple.dt.Xcode")) }
    if categories.contains(.simulators) { apps.append(("Simulator", "com.apple.iphonesimulator")) }
    return apps.filter { isRunning($0.bundle) }.map(\.name)
}
