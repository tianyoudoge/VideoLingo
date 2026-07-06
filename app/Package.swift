// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CaptionFlowApp",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CaptionFlowApp"
        )
    ]
)
