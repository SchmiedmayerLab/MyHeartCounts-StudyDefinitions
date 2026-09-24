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
    /// The language of every exported Questionnaire's base strings.
    static let baseLocale = "en-US"
    /// The language every exported Questionnaire carries as translations.
    static let translationLocale = "es-US"
    /// The locales every instrument is authored in, as the source filenames spell them.
    static let locales = [baseLocale, translationLocale]

    private static let sourceDirectory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../Sources/MHCStudyDefinitionExporter/Resources/questionnaire", directoryHint: .isDirectory)
        .standardized

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


    /// The per-locale source an instrument is authored in, before the export merges it.
    static func source(named name: String, in locale: String) throws -> [String: Any] {
        let data = try Data(contentsOf: sourceDirectory.appending(component: "\(name)+\(locale).json"))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
