// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Sa7",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "Sa7Core"),
        .executableTarget(name: "Sa7", dependencies: ["Sa7Core"]),
        .testTarget(name: "Sa7CoreTests", dependencies: ["Sa7Core"]),
    ]
)
