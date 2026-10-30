//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import GroveLocalization
import GroveStudyDefinition
import MHCStudyDefinition


/// An exporter resource named `<filename>[~variant]+<locale>.<ext>`.
struct StudyResource {
    private enum ValidationError: LocalizedError {
        case invalidFilename(URL)
        case mixedVariants(StudyBundle.FileReference)
        case duplicateResource(URL)

        var errorDescription: String? {
            switch self {
            case .invalidFilename(let url):
                "Invalid resource filename '\(url.lastPathComponent)'; expected <filename>[~stanford|~imperial]+<locale>.<ext>."
            case .mixedVariants(let fileRef):
                "All versions of '\(fileRef.category.rawValue)/\(fileRef.filename).\(fileRef.fileExtension)' must either specify a variant or be shared."
            case .duplicateResource(let url):
                "Duplicate resource variant and localization: '\(url.lastPathComponent)'."
            }
        }
    }

    let url: URL
    let fileRef: StudyBundle.FileReference
    let localization: LocalizationKey
    let variant: StudyVariant?

    init?(url: URL, category: StudyBundle.FileReference.Category) throws {
        guard let (unlocalizedUrl, localization) = LocalizedFileResolution.parse(url) else {
            if url.lastPathComponent.contains("~") {
                throw ValidationError.invalidFilename(url)
            }
            return nil
        }
        let components = unlocalizedUrl.deletingPathExtension().lastPathComponent.split(separator: "~", omittingEmptySubsequences: false)
        guard let filename = components.first, !filename.isEmpty else {
            throw ValidationError.invalidFilename(url)
        }
        if components.count == 1 {
            variant = nil
        } else {
            guard components.count == 2, let variant = StudyVariant(rawValue: String(components[1])) else {
                throw ValidationError.invalidFilename(url)
            }
            self.variant = variant
        }
        self.url = url
        self.localization = localization
        fileRef = .init(category: category, filename: String(filename), fileExtension: url.pathExtension)
    }

    /// Validates every resource group before selecting the requested variant and all shared resources.
    static func select(_ resources: [Self], for variant: StudyVariant) throws -> [Self] {
        for (fileRef, versions) in Dictionary(grouping: resources, by: \.fileRef) {
            if versions.contains(where: { $0.variant != nil }) && versions.contains(where: { $0.variant == nil }) {
                throw ValidationError.mixedVariants(fileRef)
            }
            for localizations in Dictionary(grouping: versions, by: \.variant).values {
                var seen = Set<LocalizationKey>()
                for resource in localizations where !seen.insert(resource.localization).inserted {
                    throw ValidationError.duplicateResource(resource.url)
                }
            }
        }
        return resources.filter { $0.variant == nil || $0.variant == variant }
    }
}
