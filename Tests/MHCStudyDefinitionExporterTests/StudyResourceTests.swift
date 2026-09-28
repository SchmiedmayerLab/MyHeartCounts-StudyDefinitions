//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
@_spi(APISupport)
import GroveStudyDefinition
import MHCStudyDefinition
@_spi(APISupport)
@testable import MHCStudyDefinitionExporter
import Testing


@Suite
struct StudyResourceTests {
    @Test
    func parsesVariantAndStripsItFromFileReference() throws {
        let resource = try #require(try StudyResource(
            url: URL(filePath: "/resources/Participant.Consent~imperial+en-GB.md"), category: .consent
        ))
        #expect(resource.variant == .imperial)
        #expect(resource.localization.description == "en-GB")
        #expect(resource.fileRef == .init(category: .consent, filename: "Participant.Consent", fileExtension: "md"))
        #expect(resource.url.lastPathComponent == "Participant.Consent~imperial+en-GB.md")
    }

    @Test(arguments: StudyVariant.allCases)
    func sharedResourcesRetainEveryLocale(variant: StudyVariant) throws {
        let resources = try resources(named: ["Sleep+en-US.md", "Sleep+en-GB.md", "Sleep+es-US.md"])
        #expect(resources.allSatisfy { $0.variant == nil })
        #expect(try StudyResource.select(resources, for: variant).map(\.url) == resources.map(\.url))
    }

    @Test(arguments: StudyVariant.allCases)
    func selectsMatchingVariantsAndSharedFiles(variant: StudyVariant) throws {
        let resources = try resources(named: [
            "Welcome+en-US.md",
            "Consent~stanford+en-US.md",
            "Consent~imperial+en-GB.md",
            "Consent~stanford+es-US.md",
            "ImperialOnly~imperial+en-GB.md"
        ])
        let selected = try StudyResource.select(resources, for: variant)
        let expected = variant == .stanford ? [resources[0], resources[1], resources[3]] : [resources[0], resources[2], resources[4]]
        #expect(selected.map(\.url) == expected.map(\.url))
    }

    @Test(arguments: [
        "Consent~unknown+en-US.md",
        "Consent~+en-US.md",
        "Consent~stanford~imperial+en-US.md"
    ])
    func rejectsInvalidVariants(filename: String) {
        #expect(throws: (any Error).self) {
            try StudyResource(url: URL(filePath: "/resources/\(filename)"), category: .consent)
        }
    }

    @Test(arguments: [".DS_Store", "assets", "Consent.md"])
    func skipsUnlocalizedFiles(filename: String) throws {
        let resource = try StudyResource(url: URL(filePath: "/resources/\(filename)"), category: .consent)
        #expect(resource == nil)
    }

    @Test(arguments: StudyVariant.allCases)
    func rejectsMixedSharedAndSpecializedLocales(variant: StudyVariant) throws {
        let resources = try resources(named: ["Consent+es-US.md", "Consent~imperial+en-GB.md"])
        #expect(throws: (any Error).self) {
            try StudyResource.select(resources, for: variant)
        }
    }

    @Test(arguments: ["Consent+en-US.md", "Consent~stanford+en-US.md", "Consent~imperial+en-GB.md"])
    func rejectsDuplicateVersions(filename: String) throws {
        let resources = try ["first", "second"].map { directory in
            try #require(try StudyResource(url: URL(filePath: "/\(directory)/\(filename)"), category: .consent))
        }
        #expect(throws: (any Error).self) {
            try StudyResource.select(resources, for: .stanford)
        }
    }

    @Test
    func categoriesAndExtensionsIdentifySeparateResources() throws {
        var resources = try resources(named: ["Consent~stanford+en-US.md", "Consent+en-US.txt"])
        resources += try self.resources(named: ["Consent+en-US.md"], category: .informationalArticle)
        #expect(try StudyResource.select(resources, for: .stanford).map(\.url) == resources.map(\.url))
    }

    private func resources(
        named filenames: [String],
        category: StudyBundle.FileReference.Category = .consent
    ) throws -> [StudyResource] {
        try filenames.map { filename in
            try #require(try StudyResource(url: URL(filePath: "/resources/\(filename)"), category: category))
        }
    }
}
