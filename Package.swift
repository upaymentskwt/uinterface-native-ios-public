// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "uInterfaceNative",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "uInterfaceNative",
            targets: ["uInterfaceNative"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "uInterfaceNative",
            path: "uInterfaceNative.xcframework"
        ),
    ]
)
