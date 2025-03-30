// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Bulkhead",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Bulkhead", targets: ["Bulkhead"]),
        .library(name: "BulkheadCore", targets: ["BulkheadCore"]),
        .library(name: "BulkheadFeatures", targets: ["BulkheadFeatures"]),
        .library(name: "BulkheadUI", targets: ["BulkheadUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/SwiftTerm", branch: "master")
    ],
    targets: [
        // Main executable target
        .executableTarget(
            name: "Bulkhead",
            dependencies: [
                "BulkheadCore",
                "BulkheadFeatures",
                "BulkheadUI"
            ],
            path: "Bulkhead/Core/App",
            exclude: ["App.swift"]
        ),
        
        // Core module
        .target(
            name: "BulkheadCore",
            dependencies: [],
            path: "Bulkhead/Core",
            exclude: ["App"],
            sources: ["Docker", "Models", "Logging", "Utilities.swift"]
        ),
        
        // Features module
        .target(
            name: "BulkheadFeatures",
            dependencies: [
                "BulkheadCore",
                "BulkheadUI",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Bulkhead/Features",
            exclude: ["Features.swift"]
        ),
        
        // UI module
        .target(
            name: "BulkheadUI",
            dependencies: ["BulkheadCore"],
            path: "Bulkhead/UI",
            exclude: ["UI.swift"]
        )
    ]
) 
