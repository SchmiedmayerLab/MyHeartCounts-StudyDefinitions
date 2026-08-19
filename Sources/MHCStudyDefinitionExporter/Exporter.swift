//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import GroveFoundation
import GroveLocalization
@_spi(APISupport)
import GroveStudyDefinition


public enum Format: String, Codable, CaseIterable {
    /// A zstd-compressed tar archive, readable on every platform. The default.
    case zstd
    /// The uncompressed bundle directory.
    case package
    /// An Apple Archive, readable only on Apple platforms.
    @available(*, deprecated, message: "Use the cross-platform 'zstd' format instead.")
    case archive

    // Manual so the deprecated Apple Archive case neither breaks the synthesis nor
    // appears in the CLI's format suggestions.
    public static var allCases: [Format] {
        [.zstd, .package]
    }
}


/// Exports the My Heart Counts study bundle to the specified `outputDir`, in the given ``Format``.
@discardableResult
public func export(to outputDir: URL, as format: Format) throws -> URL {
    let fileManager = FileManager.default
    guard fileManager.itemExists(at: outputDir) && fileManager.isDirectory(at: outputDir) else {
        throw NSError(domain: "edu.stanford.MHCStudyDefinitionExporter", code: 0, userInfo: [
            NSLocalizedDescriptionKey: "Output directory '\(outputDir.path())' does not exist."
        ])
    }
    let filename = "mhcStudyBundle"
    let bundleUrl = outputDir.appending(path: "\(filename).\(StudyBundle.fileExtension)", directoryHint: .isDirectory)
    
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
    
    let bundle = try StudyBundle.writeToDisk(at: bundleUrl, definition: mhcStudyDefinition, files: inputFiles)

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
