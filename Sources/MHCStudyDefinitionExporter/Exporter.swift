//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziFoundation
import SpeziLocalization
@_spi(APISupport)
import SpeziStudyDefinition


public enum Format: String, Codable, CaseIterable {
    case archive
    case package
}


/// Exports a `mhcStudyDefinition.spezistudybundle.aar` file to the specified `outputDir`.
@discardableResult
public func export(to outputDir: URL, as format: Format) throws -> URL {
    let fileManager = FileManager.default
    guard fileManager.itemExists(at: outputDir) && fileManager.isDirectory(at: outputDir) else {
        throw NSError(domain: "edu.stanford.MHCStudyDefinitionExporter", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Output directory '\(outputDir.path())' does not exist."
        ])
    }
    let filename = "mhcStudyBundle"
    let bundleUrl = outputDir.appendingPathComponent(filename, conformingTo: .speziStudyBundle)
    
    let inputFiles: [StudyBundle.FileResourceInput] = try Array {
        let bundleResourceUrl = try tryUnwrap(Bundle.module.resourceURL, "Unable to find Bundle /Resources URL")
        /// key: category; value: folder in which that category's files are stored.
        let categories: [StudyBundle.FileReference.Category: URL] = [
            .consent: bundleResourceUrl.appending(path: "consent"),
            .questionnaire: bundleResourceUrl.appending(path: "questionnaire"),
            .informationalArticle: bundleResourceUrl.appending(path: "article"),
            .hhdExplainer: bundleResourceUrl.appending(path: "hhdExplainer")
        ]
        for (category, dirUrl) in categories {
            for url in try fileManager.contents(of: dirUrl) {
                if let (unlocalizedUrl, localizationInfo) = LocalizedFileResolution.parse(url) {
                    let (filename, fileExt) = (
                        unlocalizedUrl.deletingPathExtension().lastPathComponent,
                        url.pathExtension
                    )
                    StudyBundle.FileResourceInput(
                        fileRef: .init(category: category, filename: filename, fileExtension: fileExt),
                        localization: localizationInfo,
                        contentsOf: url
                    )
                }
            }
        }
        StudyBundle.FileResourceInput(
            pathInBundle: "\(StudyBundle.FileReference.Category.informationalArticle.rawValue)/assets",
            contentsOf: try tryUnwrap(Bundle.module.url(forResource: "article/assets", withExtension: nil), "Unable to find assets dir in bundle")
        )
    }
    
    _ = try StudyBundle.writeToDisk(at: bundleUrl, definition: mhcStudyDefinition, files: inputFiles)
    
    switch format {
    case .package:
        return bundleUrl
    case .archive:
        // Archive into .aar file
        let archiveUrl = bundleUrl.appendingPathExtension(for: .appleArchive)
        try? fileManager.removeItem(at: archiveUrl)
        try fileManager.archiveDirectory(at: bundleUrl, to: archiveUrl)
        try? fileManager.removeItem(at: bundleUrl)
        return archiveUrl
    }
}
