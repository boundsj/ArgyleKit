// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArgyleKit",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "ArgyleKit",
            targets: ["ArgyleKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/boundsj/websocket.git", .revision("834511bcb0f39b571918853e05b77587c93a2c0c"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "ArgyleKit",
            dependencies: ["WebSocket"]),
        .testTarget(
            name: "ArgyleKitTests",
            dependencies: ["ArgyleKit"]),
    ]
)
