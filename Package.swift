// swift-tools-version:6.2
//
// This source file is part of the My Heart Counts open source project
// 
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import class Foundation.ProcessInfo
import PackageDescription


let package = Package(
    name: "MHCStudyDefinition",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2),
        .macOS(.v15),
        .macCatalyst(.v18)
    ],
    products: [
        .library(name: "MHCStudyDefinition", targets: ["MHCStudyDefinition"]),
        .library(name: "MHCStudyDefinitionExporter", targets: ["MHCStudyDefinitionExporter"]),
        .executable(name: "MHCStudyDefinitionExporterCLI", targets: ["MHCStudyDefinitionExporterCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/StanfordSpezi/SpeziStudy.git", .upToNextMinor(from: "0.1.19")),
        .package(url: "https://github.com/StanfordSpezi/SpeziFoundation.git", from: "2.4.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.2"),
        // not used directly but we need to fix it below 0.9.0 for the time being
        .package(url: "https://github.com/apple/FHIRModels.git", .upToNextMinor(from: "0.8.0"))
    ],
    targets: [
        .target(
            name: "MHCStudyDefinition",
            dependencies: [
                .product(name: "SpeziStudyDefinition", package: "SpeziStudy")
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "MHCStudyDefinitionExporter",
            dependencies: [
                "MHCStudyDefinition",
                .product(name: "SpeziStudyDefinition", package: "SpeziStudy"),
                .product(name: "SpeziStudy", package: "SpeziStudy"),
                .product(name: "SpeziLocalization", package: "SpeziFoundation")
            ],
            resources: [
                .copy("Resources/consent"),
                .copy("Resources/article"),
                .copy("Resources/questionnaire"),
                .copy("Resources/hhdExplainer")
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .executableTarget(
            name: "MHCStudyDefinitionExporterCLI",
            dependencies: [
                "MHCStudyDefinition",
                "MHCStudyDefinitionExporter",
                .product(name: "SpeziStudyDefinition", package: "SpeziStudy"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "MHCStudyDefinitionExporterTests",
            dependencies: [
                "MHCStudyDefinition",
                "MHCStudyDefinitionExporter",
                .product(name: "SpeziStudyDefinition", package: "SpeziStudy")
            ]
        )
    ]
)
