// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NeuralyzerPhoneKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "NeuralyzerPhoneKit", targets: ["NeuralyzerPhoneKit"])],
    targets: [
        .target(name: "NeuralyzerPhoneKit"),
        .testTarget(name: "NeuralyzerPhoneKitTests", dependencies: ["NeuralyzerPhoneKit"]),
    ]
)
