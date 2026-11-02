// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SpatialHandGestures",
    platforms: [
        .visionOS(.v2),
        // macOS is supported so the pure gesture logic can be unit tested without a headset.
        .macOS(.v14),
    ],
    products: [
        .library(name: "SpatialHandGestures", targets: ["SpatialHandGestures"]),
    ],
    targets: [
        .target(name: "SpatialHandGestures"),
        .testTarget(name: "SpatialHandGesturesTests", dependencies: ["SpatialHandGestures"]),
    ]
)
