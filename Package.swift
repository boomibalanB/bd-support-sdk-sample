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
    dependencies: [
        .package(
            url: "https://github.com/getsentry/sentry-cocoa.git",
            from: "8.57.0"
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
                "BoldDeskSupportSDKBinary",
                .product(name: "Sentry", package: "sentry-cocoa")
            ]
        )
    ]
)
