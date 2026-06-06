// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ShellGuardUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ShellGuardUIApp", targets: ["ShellGuardUIApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        .executableTarget(
            name: "ShellGuardUIApp",
            dependencies: ["Yams"],
            path: "Sources/ShellGuardUIApp",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
