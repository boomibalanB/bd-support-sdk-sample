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
            targets: ["BoldDeskSupportSDK"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/marmelroy/PhoneNumberKit.git",
            from: "3.7.0" // or latest stable
        )
    ],
    targets: [
        .binaryTarget(
            name: "BoldDeskSupportSDK",
            path: "./BoldDeskSupportSDK.xcframework"
        ),
        .target(
            name: "BoldDeskSupportSDKWrapper", // 👈 wrapper target
            dependencies: [
                "BoldDeskSupportSDK",
                .product(name: "PhoneNumberKit-Static", package: "PhoneNumberKit")
            ]
        )
    ]
)