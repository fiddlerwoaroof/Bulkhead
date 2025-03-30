// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "Bulkhead",
  platforms: [
    .macOS(.v14),
    .iOS(.v16),
  ],
  products: [
    .library(name: "BulkheadUI", targets: ["BulkheadUI"]),
    .library(name: "BulkheadCore", targets: ["BulkheadCore"]),
  ],
  dependencies: [
    .package(url: "https://github.com/krzyzanowskim/SwiftTerm", branch: "master")
  ],
  targets: [
    // Main app target
    .target(
      name: "BulkheadUI",
      dependencies: [
        "BulkheadCore",
        .product(name: "SwiftTerm", package: "SwiftTerm")
      ],
      path: "Bulkhead/UI",
      resources: [
        .process("Resources")
      ]
    ),

    // Core module
    .target(
      name: "BulkheadCore",
      dependencies: [],
      path: "Bulkhead/Core",
      sources: ["Docker", "Models", "Logging", "Utilities.swift"]
    ),
  ]
)
