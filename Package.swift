// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "bd-support-sdk-sampl",
    products: [
        // Explicitly define the library as static
        .library(
            name: "bd-support-sdk-sample",
            type: .static, 
            targets: ["BoldDeskSupportSDK"]
        ),
    ],
    targets: [
        .target(
            name: "BoldDeskSupportSDK",
            dependencies: []
        ),
    ]
)