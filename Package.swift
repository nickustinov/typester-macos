// swift-tools-version:5.9
import PackageDescription
import Foundation

// Get the package directory to use for absolute path
let packageDir = URL(fileURLWithPath: #file).deletingLastPathComponent().path

let package = Package(
    name: "typester",
    platforms: [.macOS(.v13)],
    targets: [
        // Library target containing all the testable code
        .target(
            name: "TypesterCore",
            path: "Sources/TypesterCore"
        ),
        // Executable that imports the library
        .executableTarget(
            name: "typester",
            dependencies: ["TypesterCore"],
            path: "Sources",
            exclude: ["TypesterCore", "Info.plist", "typester.entitlements"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "\(packageDir)/Sources/Info.plist"])
            ]
        ),
        .testTarget(
            name: "TypesterTests",
            dependencies: ["TypesterCore"],
            path: "Tests"
        )
    ]
)
