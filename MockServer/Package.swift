// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MockServer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MockServer",
            path: "Sources/MockServer"
        )
    ]
)
