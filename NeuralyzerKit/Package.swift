// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NeuralyzerKit",
    platforms: [.macOS(.v15)],
    products: [.library(name: "NeuralyzerKit", targets: ["NeuralyzerKit"])],
    targets: [
        .target(name: "NeuralyzerKit"),
        .testTarget(name: "NeuralyzerKitTests", dependencies: ["NeuralyzerKit"], resources: [.copy("Fixtures")]),
    ]
)
