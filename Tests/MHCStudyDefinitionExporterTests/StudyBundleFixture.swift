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


/// Exports the study into a temporary directory and hands the unarchived bundle to `operation`.
enum StudyBundleFixture {
    /// The locales every instrument ships, tagged as the resource filenames spell them.
    static let locales: [(tag: String, locale: Locale)] = [
        (tag: "en-US", locale: Locale(identifier: "en_US")),
        (tag: "es-US", locale: Locale(identifier: "es_US"))
    ]

    static func withExportedStudyBundle(_ operation: (StudyBundle) throws -> Void) throws {
        let fileManager = FileManager.default
        let destination = URL.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: destination)
        }

        do {
            let archive = try MHCStudyDefinitionExporter.export(to: destination, as: .zstd)
            let bundleURL = destination.appending(
                path: "mhcStudyBundle.\(StudyBundle.fileExtension)",
                directoryHint: .isDirectory
            )
            try operation(try StudyBundle.unarchive(archive, to: bundleURL))
        } catch StudyBundle.CreateBundleError.failedValidation(let issues) {
            let report = issues.enumerated().reduce(into: "Failed Validation:") { report, element in
                report += "\n[\(String(format: "%02li", element.offset + 1))] \(element.element)"
            }
            Issue.record("\(report)")
        }
    }


    /// The catalog as the study itself declares it, so a new instrument cannot skip the contract checks.
    static func questionnaireNames(in bundle: StudyBundle) -> [String] {
        bundle.studyDefinition.components.compactMap { component in
            guard case .questionnaire(let questionnaire) = component else {
                return nil
            }
            return questionnaire.fileRef.filename
        }
    }
}
