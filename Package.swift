// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "EaseCallUIKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "EaseCallUIKit", targets: ["EaseCallUIKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/easemob/HyphenateChat_iOS.git", exact: "4.26.0"),
        .package(url: "https://github.com/Shengwang-Lab/ShengwangRtcEngine_iOS.git", exact: "4.6.2")
    ],
    targets: [
        .target(
            name: "EaseCallUIKit",
            dependencies: [
                .product(name: "HyphenateChat", package: "HyphenateChat_iOS"),
                .product(name: "RtcBasic", package: "ShengwangRtcEngine_iOS")
            ],
            path: "Sources/EaseCallUIKit/Classes",
            resources: [.copy("Resources/CallResource.bundle")]
        ),
        .testTarget(
            name: "EaseCallUIKitTests",
            dependencies: ["EaseCallUIKit"],
            path: "Tests/EaseCallUIKitTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
