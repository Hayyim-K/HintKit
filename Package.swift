// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HintKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [.library(name: "HintKit", targets: ["HintKit"])],
    targets: [
        .target(name: "HintKit", path: "HintKit",
                exclude: ["HintKit.h"],
                resources: [.process("Main.storyboard"), .process("Resources")]),
        .testTarget(name: "HintKitTests", dependencies: ["HintKit"],
                    path: "Tests/HintKitTests")
    ]
)
