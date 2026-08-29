// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CubeScrambler",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CubeScrambler",
            path: "Sources/CubeScrambler"
        ),
        .testTarget(
            name: "CubeScramblerTests",
            dependencies: ["CubeScrambler"],
            path: "Tests/CubeScramblerTests"
        )
    ]
)
