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
            targets: ["BoldDeskSupportSDKWrapper"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "BoldDeskSupportSDKBinary",
            path: "./BoldDeskSupportSDK.xcframework"
        ),
        .target(
            name: "BoldDeskSupportSDKWrapper",
            dependencies: [
                "BoldDeskSupportSDKBinary"
            ]
        )
    ]
)
