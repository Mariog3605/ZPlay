// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "torrserver_flutter",
    platforms: [.tvOS(.v15)],
    products: [.library(name: "torrserver-flutter", targets: ["torrserver_flutter"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [
        .binaryTarget(name: "TorrServerKit", path: "TorrServerKit.xcframework"),
        .target(
            name: "torrserver_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                "TorrServerKit",
            ],
            path: "Classes",
            swiftSettings: [.define("TARGET_OS_TV")],
            linkerSettings: [
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("Foundation"),
                .linkedFramework("Security"),
            ]
        ),
    ]
)
