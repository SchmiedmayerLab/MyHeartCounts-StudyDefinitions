//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
@_spi(APISupport)
import GroveStudyDefinition
import MHCStudyDefinition
import MHCStudyDefinitionExporter
import Testing


@Suite
struct MHCStudyDefinitionExporterTests {
    @Test(arguments: StudyVariant.allCases, [StudyBundle.Format.package, .zstd])
    func export(variant: StudyVariant, format: StudyBundle.Format) throws {
        let fileManager = FileManager.default
        let destination = URL.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: destination)
        }

        let output = try MHCStudyDefinitionExporter.export(variant, to: destination, as: format)
        #expect(fileManager.fileExists(atPath: output.path()))
        let basename = variant == .stanford ? "mhcStudyBundle" : "mhcStudyBundle-imperial"
        let bundle: StudyBundle
        if format == .package {
            #expect(output.lastPathComponent == "\(basename).\(StudyBundle.fileExtension)")
            bundle = try StudyBundle(bundleUrl: output)
        } else {
            #expect(output.lastPathComponent == "\(basename).\(StudyBundle.archiveFileExtension)")
            let bundleURL = destination.appending(component: "roundtrip.studybundle", directoryHint: .isDirectory)
            bundle = try StudyBundle.unarchive(output, to: bundleURL)
        }
        #expect(bundle.studyDefinition.studyRevision == 45)
        try checkConsent(in: bundle, variant: variant)
        checkEligibility(in: bundle, variant: variant)

        let paths = try fileManager.subpathsOfDirectory(atPath: bundle.bundleUrl.path())
        #expect(!paths.contains { $0.contains("~") })
        for sharedPath in [
            "article/Welcome+en-US.md",
            "article/Welcome+es-US.md",
            "article/assets/SensorKit/Settings1.jpg",
            "questionnaire/GAD7+en-US.json",
            "questionnaire/GAD7+es-US.json",
            "hhdExplainer/Sleep+en-US.md",
            "hhdExplainer/Sleep+en-GB.md",
            "hhdExplainer/Sleep+es-US.md"
        ] {
            #expect(paths.contains(sharedPath))
        }
    }

    @Test
    func variantsCanShareAnExportDirectory() throws {
        let fileManager = FileManager.default
        let destination = URL.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: destination)
        }
        let stanfordURL = try MHCStudyDefinitionExporter.export(.stanford, to: destination, as: .package)
        let imperialURL = try MHCStudyDefinitionExporter.export(.imperial, to: destination, as: .package)
        #expect(stanfordURL != imperialURL)
        try checkConsent(in: StudyBundle(bundleUrl: stanfordURL), variant: .stanford)
        try checkConsent(in: StudyBundle(bundleUrl: imperialURL), variant: .imperial)
    }

    private func checkEligibility(in bundle: StudyBundle, variant: StudyVariant) {
        let criterion = bundle.studyDefinition.metadata.participationCriterion
        for region in [Locale.Region.unitedStates, .unitedKingdom] {
            let expectedRegion: Locale.Region = variant == .stanford ? .unitedStates : .unitedKingdom
            #expect(criterion.evaluate(.init(
                age: 18, region: region, language: .init(identifier: "en"), enabledCustomKeys: []
            )) == (region == expectedRegion))
            #expect(!criterion.evaluate(.init(
                age: 17, region: region, language: .init(identifier: "en"), enabledCustomKeys: []
            )))
        }
    }

    private func checkConsent(in bundle: StudyBundle, variant: StudyVariant) throws {
        let consentRef = try #require(bundle.studyDefinition.metadata.consentFileRef)
        let locales: [Locale] = [
            Locale(identifier: variant == .stanford ? "en-US" : "en-GB"),
            Locale(languageCode: .english, script: nil, languageRegion: variant == .stanford ? .unitedStates : .unitedKingdom)
        ]
        for locale in locales {
            let consent = try #require(bundle.consentText(
                for: consentRef, in: locale, using: .requirePerfectMatch, fallbackLocale: nil
            ))
            let expectedFiles: Set<String>
            switch variant {
            case .stanford:
                #expect(consent.contains("# STANFORD UNIVERSITY"))
                #expect(!consent.contains("INTERNAL TESTING ONLY"))
                expectedFiles = ["Consent+en-US.md", "Consent+es-US.md"]
            case .imperial:
                #expect(consent.contains("# IMPERIAL VARIANT — INTERNAL TESTING ONLY"))
                expectedFiles = ["Consent+en-GB.md"]
            }
            let consentDirectory = bundle.bundleUrl.appending(component: "consent", directoryHint: .isDirectory)
            let actualFiles = try FileManager.default.contentsOfDirectory(atPath: consentDirectory.path())
            #expect(Set(actualFiles) == expectedFiles)
        }
    }
}
