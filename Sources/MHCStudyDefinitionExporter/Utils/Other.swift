//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziStudyDefinition


func tryUnwrap<T>(_ value: T?, _ message: @autoclosure () -> String) throws -> T {
    if let value {
        return value
    } else {
        throw NSError(domain: "edu.stanford.MHCStudyDefinitionExporter", code: 0, userInfo: [
            NSLocalizedDescriptionKey: message()
        ])
    }
}


extension Locale.Language {
    static let english = Locale.Language(identifier: "en")
    static let spanish = Locale.Language(identifier: "es")
}
