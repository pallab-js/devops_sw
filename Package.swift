// swift-tools-version: 5.10
import PackageDescription

let frameworksPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let swiftLibPath = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

let package = Package(
    name: "DevForge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DevForge", targets: ["DevForge"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
        .package(url: "https://github.com/evgenyneu/keychain-swift", from: "20.0.0"),
    ],
    targets: [
        .target(
            name: "CSMC",
            path: "DevForge/SMC",
            publicHeadersPath: ".",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
        .executableTarget(
            name: "DevForge",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "KeychainSwift", package: "keychain-swift"),
                "CSMC",
            ],
            path: "DevForge",
            exclude: [
                "Info.plist",
                "DevForge.entitlements",
                "DevForge-Bridging-Header.h",
                "Tests",
                "SMC",
            ]
        ),
        .testTarget(
            name: "DevForgeTests",
            dependencies: [
                "DevForge",
            ],
            path: "DevForge/Tests/UnitTests",
            swiftSettings: [
                .unsafeFlags(["-F", frameworksPath]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", frameworksPath,
                    "-Xlinker", "-rpath", "-Xlinker", frameworksPath,
                    "-Xlinker", "-rpath", "-Xlinker", swiftLibPath,
                ]),
                .linkedFramework("Testing", .when(platforms: [.macOS])),
            ]
        ),
    ]
)
