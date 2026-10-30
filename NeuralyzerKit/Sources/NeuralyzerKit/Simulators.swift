import Foundation

/// Simulator devices and runtimes, read from and removed through `xcrun simctl`.
public struct SimulatorRule: CategoryRule {
    public let id = CategoryID.simulators
    public init() {}

    static let xcrun = "/usr/bin/xcrun"

    private struct DeviceList: Decodable {
        struct Device: Decodable {
            let udid: String
            let name: String
            let dataPath: String?
            let isAvailable: Bool?
        }
        let devices: [String: [Device]]
    }

    private struct Runtime: Decodable {
        let identifier: String
        let runtimeIdentifier: String?
        let sizeBytes: Int64?
        let deletable: Bool?
    }

    public func scan(_ env: ScanEnvironment) async -> [Item] {
        await devices(env) + runtimes(env)
    }

    private func devices(_ env: ScanEnvironment) async -> [Item] {
        guard let data = try? await env.runner.run(Self.xcrun, ["simctl", "list", "devices", "-j"]),
              let list = try? JSONDecoder().decode(DeviceList.self, from: data) else { return [] }
        return list.devices.flatMap { runtime, devices in
            devices.compactMap { d -> Item? in
                guard let dataPath = d.dataPath else { return nil }
                let folder = URL(fileURLWithPath: dataPath).deletingLastPathComponent()
                let bytes = allocatedSize(of: folder)
                guard bytes > 0 else { return nil }
                return Item(id: "device:\(d.udid)", category: id, name: "\(d.name) \(Self.runtimeName(runtime))",
                            url: folder, root: nil, bytes: bytes, action: .simctlDeleteDevice(udid: d.udid),
                            preselected: d.isAvailable == false)
            }
        }
    }

    private func runtimes(_ env: ScanEnvironment) async -> [Item] {
        guard let data = try? await env.runner.run(Self.xcrun, ["simctl", "runtime", "list", "-j"]),
              let list = try? JSONDecoder().decode([String: Runtime].self, from: data) else { return [] }
        return list.values.compactMap { r -> Item? in
            guard r.deletable == true, let bytes = r.sizeBytes, bytes > 0 else { return nil }
            return Item(id: "runtime:\(r.identifier)", category: id,
                        name: "\(Self.runtimeName(r.runtimeIdentifier ?? r.identifier)) Runtime",
                        url: URL(fileURLWithPath: "/Library/Developer/CoreSimulator"), root: nil, bytes: bytes,
                        action: .simctlDeleteRuntime(id: r.identifier), preselected: false)
        }
    }

    /// `com.apple.CoreSimulator.SimRuntime.iOS-27-1` reads as `iOS 27.1`.
    static func runtimeName(_ identifier: String) -> String {
        let last = identifier.split(separator: ".").last.map(String.init) ?? identifier
        let parts = last.split(separator: "-")
        guard let platform = parts.first, parts.count > 1 else { return last }
        return "\(platform) \(parts.dropFirst().joined(separator: "."))"
    }
}
