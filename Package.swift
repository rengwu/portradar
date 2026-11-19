// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "portradar",
    platforms: [.macOS(.v13)],
    targets: [
        // Core library: no AppKit. Socket scan, project resolution, classification, presentation.
        .target(name: "PortRadarCore", path: "Sources/PortRadarCore"),
        // The app: status item, menu rows, settings.
        .executableTarget(name: "PortRadar", dependencies: ["PortRadarCore"], path: "Sources/PortRadar"),
        // Tests are a plain executable run with `swift run PortRadarCoreTests`:
        // this machine has Command Line Tools only, and XCTest ships with Xcode.
        .executableTarget(
            name: "PortRadarCoreTests",
            dependencies: ["PortRadarCore"],
            path: "Tests/PortRadarCoreTests"
        ),
    ]
)
