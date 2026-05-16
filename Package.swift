// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StuffieCrossing",
    platforms: [.macOS(.v13), .iOS(.v16)],
    targets: [
        // Pure-Foundation logic layer — no UIKit/SpriteKit, fully unit-testable via `swift test`
        .target(
            name: "StuffieCrossingCore",
            path: "StuffieCrossing",
            exclude: ["App", "Nodes", "Scenes", "Assets.xcassets", "Info.plist"],
            sources: [
                "Models/Stuffie.swift",
                "Models/Level.swift",
                "Models/GameStateManager.swift",
                "Data/Levels.swift",
            ]
        ),
        .testTarget(
            name: "StuffieCrossingCoreTests",
            dependencies: ["StuffieCrossingCore"],
            path: "Tests/StuffieCrossingCoreTests"
        ),
    ]
)
