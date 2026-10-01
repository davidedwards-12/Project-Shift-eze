// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "RotationEngine",
    platforms: [.iOS(.v26), .macOS(.v14)],  // macOS only for running tests
    products: [
        .library(name: "RotationEngine", targets: ["RotationEngine"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "TMDB", targets: ["TMDB"]),
    ],
    targets: [
        .target(
            name: "RotationEngine",
            resources: [.copy("Resources/management_links.json")]
        ),
        .testTarget(
            name: "RotationEngineTests",
            dependencies: ["RotationEngine"],
            resources: [.copy("Fixtures")]
        ),
        .target(name: "Persistence", dependencies: ["RotationEngine"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
        .target(name: "TMDB", dependencies: ["RotationEngine"]),
        .testTarget(name: "TMDBTests", dependencies: ["TMDB"]),
    ]
)
