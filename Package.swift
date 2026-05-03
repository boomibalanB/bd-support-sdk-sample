// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "bd-support-sdk-sample",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "BoldDeskSupportSDK",
            type: .static,
            targets: []
        )
    ],
    targets: [
        .binaryTarget(
            name: "BoldDeskSupportSDK",
            path: "./BoldDeskSupportSDK.xcframework"
        )
    ]
)