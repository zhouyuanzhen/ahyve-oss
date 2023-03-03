// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ahyve-oss",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.2"),
    ],
    targets: [
        .executableTarget(
            name: "ahyve-oss",
            dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser"),]),
    ]
)
