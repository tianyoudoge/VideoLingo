// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CaptionFlowApp",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/amosavian/AMSMB2.git", exact: "4.0.3")
    ],
    targets: [
        .executableTarget(
            name: "CaptionFlowApp",
            dependencies: [
                .product(name: "AMSMB2", package: "AMSMB2")
            ],
            swiftSettings: [.unsafeFlags(["-parse-as-library"])],
            linkerSettings: [
                .linkedFramework("NetFS"),
                .linkedFramework("Security")
            ]
        )
    ]
)
