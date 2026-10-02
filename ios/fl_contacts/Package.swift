// swift-tools-version: 5.9

// Swift Package Manager entry point, detected by the Flutter tool when SPM
// is enabled; CocoaPods remains available through fl_contacts.podspec.
import PackageDescription

let package = Package(
    name: "fl_contacts",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "flutter-contacts", targets: ["fl_contacts"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "fl_contacts",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
