// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BalanceSimulator",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "BalanceSimulator",
            path: "Sources/BalanceSimulator"
        )
    ]
)
