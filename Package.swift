// swift-tools-version: 5.9
//
// Headless SlothCore package. Builds with `swift build`; tests with
// `swift test`. No UIKit / no SwiftUI in this target — SwiftUI views
// live in the App/ folder and depend on this package via xcodegen
// (project.yml).

import PackageDescription

let package = Package(
    name: "SlothCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SlothCore",
            targets: ["SlothCore"]
        ),
    ],
    targets: [
        .target(
            name: "SlothCore",
            path: "Sources/SlothCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "SlothCoreTests",
            dependencies: ["SlothCore"],
            path: "Tests/SlothCoreTests"
        ),
    ]
)
