// swift-tools-version:6.2
//
// This source file is part of the My Heart Counts Study Definitions open-source project
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
        .package(
            url: "https://github.com/SchmiedmayerLab/Grove.git",
            revision: "a49478e4f3170db307f13d08465e6fe242ee0c08"
        ),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.2")
    ],
    targets: [
        .target(
            name: "MHCStudyDefinition",
            dependencies: [
                .product(name: "GroveStudyDefinition", package: "Grove"),
                .product(name: "GroveLocalization", package: "Grove")
            ],
            resources: [.process("Resources")]
        ),
        .target(
            name: "MHCStudyDefinitionExporter",
            dependencies: [
                "MHCStudyDefinition",
                .product(name: "GroveStudyDefinition", package: "Grove"),
                .product(name: "GroveLocalization", package: "Grove")
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
                .product(name: "GroveStudyDefinition", package: "Grove"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "MHCStudyDefinitionExporterTests",
            dependencies: [
                "MHCStudyDefinition",
                "MHCStudyDefinitionExporter",
                .product(name: "GroveQuestionnaire", package: "Grove", condition: .when(platforms: [.macOS])),
                .product(name: "GroveQuestionnaireFHIR", package: "Grove", condition: .when(platforms: [.macOS])),
                .product(name: "GroveStudyDefinition", package: "Grove")
            ]
        )
    ]
)
