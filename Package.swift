// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "typester",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "typester",
            path: "Sources",
            exclude: ["Info.plist", "typester.entitlements"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/Info.plist"])
            ]
        )
    ]
)
