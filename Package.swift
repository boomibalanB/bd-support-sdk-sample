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
            targets: ["BoldDeskSupportSDK"] // 💡 Expose the wrapper as your main library product
        )
    ],
    dependencies: [
        .package(url: "https://github.com/PhoneNumberKit/PhoneNumberKit.git", from: "5.0.3")
    ],
    targets: [
        .binaryTarget(
            name: "BoldDeskSupportSDK",
            path: "./BoldDeskSupportSDK.xcframework"
        ),
        .target(
            name: "BoldDeskSupportSDKWrapper",
            dependencies: [
                "BoldDeskSupportSDK",
                .product(name: "PhoneNumberKit", package: "PhoneNumberKit") // 💡 Changed from "PhoneNumberKit-Static"
            ]
        )
    ]
)
