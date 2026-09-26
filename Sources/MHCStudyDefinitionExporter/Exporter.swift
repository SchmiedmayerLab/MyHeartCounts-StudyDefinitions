//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import GroveFoundation
@_spi(APISupport)
import GroveStudyDefinition
import MHCStudyDefinition


/// Exports the My Heart Counts study bundle to the specified `outputDir`, in the given ``Format``.
///
/// - returns: The `URL` of the exported study bundle.
public func export(_ variant: StudyVariant, to outputDir: URL, as format: StudyBundle.Format) throws -> URL {
    let fileManager = FileManager.default
    guard fileManager.itemExists(at: outputDir) && fileManager.isDirectory(at: outputDir) else {
        throw NSError(domain: "edu.stanford.MHCStudyDefinitionExporter", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Output directory '\(outputDir.path())' does not exist."
        ])
    }
    let filename = switch variant {
    case .stanford:
        "mhcStudyBundle"
    case .imperial:
        "mhcStudyBundle-imperial"
    }
    let bundleUrl = outputDir.appending(path: "\(filename).\(StudyBundle.fileExtension)", directoryHint: .isDirectory)
    let definition = mhcStudyDefinition(for: variant)
    let inputFiles = try resourceInputs(for: variant, consentFileRef: definition.metadata.consentFileRef)
    let bundle = try StudyBundle.writeToDisk(
        at: bundleUrl,
        definition: definition,
        files: inputFiles
    )
    
    switch format {
    case .package:
        return bundleUrl
    case .zstd:
        let archiveUrl = outputDir.appending(path: "\(filename).\(StudyBundle.archiveFileExtension)")
        try? fileManager.removeItem(at: archiveUrl)
        try bundle.archive(to: archiveUrl, compressionLevel: .maxRegular)
        try? fileManager.removeItem(at: bundleUrl)
        return archiveUrl
    case .archive:
        return try appleArchive(bundleAt: bundleUrl)
    }
}


private func resourceInputs(
    for variant: StudyVariant,
    consentFileRef: StudyBundle.FileReference?
) throws -> [StudyBundle.FileResourceInput] {
    let bundleResourceUrl = try tryUnwrap(Bundle.module.resourceURL, "Unable to find Bundle /Resources URL")
    /// key: category; value: folder in which that category's files are stored.
    let categories: [StudyBundle.FileReference.Category: URL] = [
        .consent: bundleResourceUrl.appending(path: "consent"),
        .questionnaire: bundleResourceUrl.appending(path: "questionnaire"),
        .informationalArticle: bundleResourceUrl.appending(path: "article"),
        .hhdExplainer: bundleResourceUrl.appending(path: "hhdExplainer")
    ]
    let resources = try categories.flatMap { category, dirUrl in
        try FileManager.default.contents(of: dirUrl).compactMap { try StudyResource(url: $0, category: category) }
    }
    let selectedResources = try StudyResource.select(resources, for: variant)
    if let consentRef = consentFileRef, !selectedResources.contains(where: { $0.fileRef == consentRef }) {
        throw StudyBundle.CreateBundleError.failedValidation([.general(.noFilesMatchingFileRef(consentRef))])
    }
    var inputs = selectedResources.map { resource in
        StudyBundle.FileResourceInput(
            fileRef: resource.fileRef,
            localization: resource.localization,
            contentsOf: resource.url
        )
    }
    inputs.append(StudyBundle.FileResourceInput(
        pathInBundle: "\(StudyBundle.FileReference.Category.informationalArticle.rawValue)/assets",
        contentsOf: try tryUnwrap(Bundle.module.url(forResource: "article/assets", withExtension: nil), "Unable to find assets dir in bundle")
    ))
    return inputs
}


/// Packages an exported bundle into an `.aar` file, replacing the bundle directory.
///
/// Apple Archive is only available on Apple platforms; everywhere else `.zstd` is the archive format.
private func appleArchive(bundleAt bundleUrl: URL) throws -> URL {
    #if canImport(AppleArchive)
    let fileManager = FileManager.default
    let archiveUrl = bundleUrl.appendingPathExtension(for: .appleArchive)
    try? fileManager.removeItem(at: archiveUrl)
    try fileManager.archiveDirectory(at: bundleUrl, to: archiveUrl)
    try? fileManager.removeItem(at: bundleUrl)
    return archiveUrl
    #else
    throw NSError(domain: "edu.stanford.MHCStudyDefinitionExporter", code: 0, userInfo: [
        NSLocalizedDescriptionKey: "The Apple Archive format requires AppleArchive. Export with --format \(Format.zstd.rawValue)."
    ])
    #endif
}
