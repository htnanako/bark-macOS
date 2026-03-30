// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "BarkMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "BarkMac",
            targets: ["BarkMac"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "BarkMac",
            dependencies: [
                .product(name: "CryptoSwift", package: "CryptoSwift"),
            ],
            path: "Sources/BarkMac",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "BarkMacTests",
            dependencies: [
                "BarkMac",
                .product(name: "CryptoSwift", package: "CryptoSwift"),
            ],
            path: "Tests/BarkMacTests"
        ),
    ]
)
