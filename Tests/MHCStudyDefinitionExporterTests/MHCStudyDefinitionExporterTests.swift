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
            #expect(bundle.studyDefinition.studyRevision == 44)
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
