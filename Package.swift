// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UrenReconstructie",
    defaultLocalization: "nl",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "UrenReconstructie", targets: ["App"]),
        .library(name: "Models", targets: ["Models"]),
        .library(name: "Database", targets: ["Database"]),
        .library(name: "Services", targets: ["Services"]),
        .library(name: "Styling", targets: ["Styling"]),
        .library(name: "Features", targets: ["Features"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: ["Features", "Database", "Services", "Styling", "Models"],
            path: "Sources/App"
        ),
        .target(
            name: "Models",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/Models"
        ),
        .target(
            name: "Database",
            dependencies: ["Models", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Sources/Database"
        ),
        .target(
            name: "Services",
            dependencies: [
                "Models",
                "Database",
                .product(name: "CoreXLSX", package: "CoreXLSX"),
            ],
            path: "Sources/Services"
        ),
        .target(
            name: "Styling",
            path: "Sources/Styling"
        ),
        .target(
            name: "Features",
            dependencies: ["Models", "Database", "Services", "Styling"],
            path: "Sources/Features"
        ),
        .testTarget(
            name: "ModelsTests",
            dependencies: ["Models"],
            path: "Tests/ModelsTests"
        ),
        .testTarget(
            name: "DatabaseTests",
            dependencies: ["Database", "Models"],
            path: "Tests/DatabaseTests"
        ),
        .testTarget(
            name: "ServicesTests",
            dependencies: ["Services", "Models", "Database", "Styling"],
            path: "Tests/ServicesTests"
        ),
    ]
)
