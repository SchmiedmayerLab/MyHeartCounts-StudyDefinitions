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
import MHCStudyDefinitionExporter
import Testing


@Suite
struct MHCStudyDefinitionExporterTests {
    @Test
    func export() throws {
        let fileManager = FileManager.default
        let dstDir = URL.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: dstDir, withIntermediateDirectories: true)
        defer {
            // let's clean up after ourselves
            try? fileManager.removeItem(at: dstDir)
        }
        let archiveUrl: URL
        do {
            archiveUrl = try MHCStudyDefinitionExporter.export(to: dstDir, as: .zstd)
            let bundleUrl = dstDir.appending(
                path: "mhcStudyBundle.\(StudyBundle.fileExtension)",
                directoryHint: .isDirectory
            )
            let bundle = try StudyBundle.unarchive(archiveUrl, to: bundleUrl)
            #expect(bundle.studyDefinition.studyRevision == 45)

            let consentRef = try #require(bundle.studyDefinition.metadata.consentFileRef)
            let stanfordConsent = try #require(bundle.consentText(
                for: consentRef, in: Locale(identifier: "en-US"), using: .requirePerfectMatch, fallbackLocale: .enUS
            ))
            #expect(stanfordConsent.contains("# STANFORD UNIVERSITY"))
            #expect(!stanfordConsent.contains("INTERNAL TESTING ONLY"))

            let imperialConsent = try #require(bundle.consentText(
                for: consentRef, in: Locale(identifier: "en-GB"), using: .requirePerfectMatch, fallbackLocale: nil
            ))
            #expect(imperialConsent.contains("# IMPERIAL VARIANT — INTERNAL TESTING ONLY"))
        } catch StudyBundle.CreateBundleError.failedValidation(let issues) {
            let desc = issues.enumerated().reduce(into: "Failed Validation:\n") { desc, element in
                let (idx, issue) = element
                desc += "\n[\(String(format: "%02li", idx + 1))] \(issue)"
                if idx < issues.endIndex - 1 {
                    desc += "\n"
                }
            }
            Issue.record("\(desc)")
            return
        }
        #expect(fileManager.itemExists(at: archiveUrl))
    }
}
