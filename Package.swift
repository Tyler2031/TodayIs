// swift-tools-version: 5.9
import PackageDescription

// Lets you run the pure-logic tests from the command line on macOS:
//
//     swift test
//
// This compiles ONLY the Foundation-only model layer (Models/) plus the tests.
// The SwiftUI app (App/, Views/, Notifications/) is built from the Xcode project,
// not from here.
let package = Package(
    name: "TodayIs",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "TodayIsCore",
            path: "TodayIs",
            exclude: ["App", "Views", "Notifications", "README.md"],
            sources: ["Models"],
            resources: [.process("Resources/observances.json")]
        ),
        .testTarget(
            name: "TodayIsCoreTests",
            dependencies: ["TodayIsCore"],
            path: "TodayIsTests"
        ),
    ]
)
