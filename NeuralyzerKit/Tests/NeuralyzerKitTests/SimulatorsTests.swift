import XCTest
@testable import NeuralyzerKit

struct StubRunner: CommandRunner {
    var outputs: [String: Data] = [:]
    var fail = false

    func run(_ launchPath: String, _ args: [String]) async throws -> Data {
        if fail { throw CommandFailed(status: 1) }
        return outputs[args.joined(separator: " ")] ?? Data()
    }
}

final class SimulatorsTests: XCTestCase {
    let home = FakeHome()

    private func fixture(_ name: String) -> Data {
        let url = Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json")!
        let text = try! String(contentsOf: url, encoding: .utf8).replacingOccurrences(of: "HOME", with: home.url.path)
        return Data(text.utf8)
    }

    private func items() async -> [Item] {
        for udid in ["2C414BCA-4659-4ECB-8FDD-5916E9F125C1", "50B2166C-0A65-4920-A57E-09CF4EEFE6DA", "46CC7B35-89F6-4A27-97B8-5A09107977F7"] {
            home.file("Library/Developer/CoreSimulator/Devices/\(udid)/data/blob", bytes: 8192)
        }
        let runner = StubRunner(outputs: [
            "simctl list devices -j": fixture("devices"),
            "simctl runtime list -j": fixture("runtimes"),
        ])
        return await SimulatorRule().scan(ScanEnvironment(home: home.url, runner: runner))
    }

    func testParsesDevicesFromFixture() async {
        let devices = await items().filter { if case .simctlDeleteDevice = $0.action { true } else { false } }
        XCTAssertEqual(Set(devices.map(\.name)), ["iPhone Duo iOS 27.1", "Old Phone iOS 27.1", "Apple Watch watchOS 27.0"])
        XCTAssertTrue(devices.allSatisfy { $0.bytes >= 8192 && $0.root == nil })
    }

    func testUnavailableDevicePreselected() async {
        let all = await items()
        XCTAssertEqual(all.filter(\.preselected).map(\.name), ["Old Phone iOS 27.1"])
    }

    func testParsesRuntimeSizes() async {
        let runtimes = await items().filter { if case .simctlDeleteRuntime = $0.action { true } else { false } }
        XCTAssertEqual(Set(runtimes.map(\.name)), ["iOS 27.1 Runtime", "watchOS 27.0 Runtime"])
        XCTAssertEqual(runtimes.first { $0.name == "iOS 27.1 Runtime" }?.bytes, 7_874_596_193)
        XCTAssertEqual(runtimes.first { $0.name == "iOS 27.1 Runtime" }?.action,
                       .simctlDeleteRuntime(id: "2C7C6B59-8E74-49D0-AF03-53AFD13FBBB3"))
    }

    func testSkipsSimctlWhenNoSimulatorFolder() async {
        let runner = RecordingRunner()
        let items = await SimulatorRule().scan(ScanEnvironment(home: home.url, runner: runner))
        XCTAssertTrue(items.isEmpty)
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testMissingSimctlYieldsNoItems() async {
        home.dir("Library/Developer/CoreSimulator")
        let items = await SimulatorRule().scan(ScanEnvironment(home: home.url, runner: StubRunner(fail: true)))
        XCTAssertTrue(items.isEmpty)
    }
}
