// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ConstellationTests",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "ConstellationGestureEngine",
            path: "Sources/ConstellationGestureEngine"
        ),
        .testTarget(
            name: "ConstellationGestureEngineTests",
            dependencies: ["ConstellationGestureEngine"],
            path: "Tests/ConstellationGestureEngineTests"
        )
    ]
)
