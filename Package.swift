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
        .macOS(.v15),
        .macCatalyst(.v18)
    ],
    products: [
        .library(name: "MHCStudyDefinition", targets: ["MHCStudyDefinition"]),
        .library(name: "MHCStudyDefinitionExporter", targets: ["MHCStudyDefinitionExporter"]),
        .executable(name: "MHCStudyDefinitionExporterCLI", targets: ["MHCStudyDefinitionExporterCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/SchmiedmayerLab/Spezi.git", branch: "monorepo-import"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.2")
    ],
    targets: [
        .target(
            name: "MHCStudyDefinition",
            dependencies: [
                .product(name: "SpeziStudyDefinition", package: "Spezi")
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "MHCStudyDefinitionExporter",
            dependencies: [
                "MHCStudyDefinition",
                .product(name: "SpeziStudyDefinition", package: "Spezi"),
                .product(name: "SpeziStudy", package: "Spezi"),
                .product(name: "SpeziLocalization", package: "Spezi")
            ],
            resources: [
                .copy("Resources/consent"),
                .copy("Resources/article"),
                .copy("Resources/questionnaire"),
                .copy("Resources/hhdExplainer")
            ]
        ),
        .executableTarget(
            name: "MHCStudyDefinitionExporterCLI",
            dependencies: [
                "MHCStudyDefinition",
                "MHCStudyDefinitionExporter",
                .product(name: "SpeziStudyDefinition", package: "Spezi"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "MHCStudyDefinitionExporterTests",
            dependencies: [
                "MHCStudyDefinition",
                "MHCStudyDefinitionExporter",
                .product(name: "SpeziStudyDefinition", package: "Spezi")
            ]
        )
    ]
)
