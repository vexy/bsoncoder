// swift-tools-version:5.1
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
        .package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.4.0")),
        .package(url: "https://github.com/swift-extras/swift-extras-json", .upToNextMinor(from: "0.6.0")),
        .package(url: "https://github.com/swift-extras/swift-extras-base64", .upToNextMinor(from: "0.5.0"))
    ],
    targets: [
        .target(name: "BSONCoder", dependencies: ["NIO", "ExtrasJSON", "ExtrasBase64"]),
        .testTarget(name: "BSONCoderTests", dependencies: ["BSONCoder", "ExtrasJSON"])
    ]
)
