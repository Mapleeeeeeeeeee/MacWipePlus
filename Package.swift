// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacWipePlus",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacWipePlus", targets: ["MacWipePlus"])
    ],
    targets: [
        .target(name: "MacWipePlusCore"),
        .executableTarget(name: "MacWipePlus", dependencies: ["MacWipePlusCore"]),
        .executableTarget(name: "MacWipePlusRegressionTests", dependencies: ["MacWipePlusCore"], path: "Tests/RegressionTests")
    ]
)
