// swift-tools-version: 6.0
import PackageDescription

// Plattformunabhängiger Kern der App: Inhaltsmodell, Evaluator, Einstufung,
// Score und Wissensanalyse. Enthält keine UI und keine Persistenz und ist
// deshalb vollständig mit `swift test` prüfbar.
let package = Package(
    name: "JavaQuestKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "JavaQuestKit", targets: ["JavaQuestKit"])
    ],
    targets: [
        .target(
            name: "JavaQuestKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "JavaQuestKitTests",
            dependencies: ["JavaQuestKit"]
        )
    ]
)
