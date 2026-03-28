// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UsageIndicator",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "UsageIndicator",
            path: "Sources/UsageIndicator",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/UsageIndicator/Info.plist"])
            ]
        )
    ]
)
