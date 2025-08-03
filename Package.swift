// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "shoulder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "shoulder", targets: ["shoulder"])
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "shoulder",
            dependencies: [
            ]
        )
    ]
)