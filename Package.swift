// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "BSONCoder",
    platforms: [
        .macOS(.v10_14),
        .iOS(.v11)
    ],
    products: [
        .library(name: "bsoncoder", targets: ["BSONCoder"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.5.0")),
        .package(url: "https://github.com/swift-extras/swift-extras-json", .upToNextMajor(from: "0.6.0")),
        .package(url: "https://github.com/swift-extras/swift-extras-base64", .upToNextMajor(from: "0.7.0"))
    ],
    targets: [
        .target(
            name: "BSONCoder",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
                .product(name: "ExtrasBase64", package: "swift-extras-base64")
            ]
        ),
        .testTarget(
            name: "BSONCoderTests",
            dependencies: [
                "BSONCoder",
                .product(name: "ExtrasJSON", package: "swift-extras-json")
            ]
        )
    ]
)
