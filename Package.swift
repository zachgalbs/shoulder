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
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.10.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "shoulder",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples")
            ]
        )
    ]
)