// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TinyHand",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .target(
            name: "ShapeKit",
            path: "Sources/ShapeKit"
        ),
        .executableTarget(
            name: "TinyHand",
            dependencies: ["ShapeKit", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/TinyHand",
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        )
    ]
)
