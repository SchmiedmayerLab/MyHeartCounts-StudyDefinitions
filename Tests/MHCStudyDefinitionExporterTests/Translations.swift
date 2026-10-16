//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Reads the standard `translation` extensions of FHIR JSON.
enum Translations {
    private static let url = "http://hl7.org/fhir/StructureDefinition/translation"

    /// The translations a primitive's `_element` carries, by language.
    static func of(_ element: Any?) -> [String: String] {
        let extensions = (element as? [String: Any])?["extension"] as? [[String: Any]] ?? []
        return extensions.filter { $0["url"] as? String == url }.reduce(into: [:]) { translations, translation in
            let parts = translation["extension"] as? [[String: Any]] ?? []
            let language = parts.first { $0["url"] as? String == "lang" }?["valueCode"] as? String
            let content = parts.first { $0["url"] as? String == "content" }
            if let language, let content = content?["valueString"] as? String ?? content?["valueMarkdown"] as? String {
                translations[language] = content
            }
        }
    }

    /// Every translation in `value`, as `path lang content` lines in a stable order.
    ///
    /// Extensions are addressed by url rather than position, so a reordered extension array reads the same.
    static func all(in value: Any, path: String = "") -> [String] {
        if let object = value as? [String: Any] {
            let lines = object.flatMap { key, child in
                let childPath = "\(path).\(key)"
                let own = key.hasPrefix("_") ? of(child).map { "\(childPath) \($0.key) \($0.value)" } : []
                return own + all(in: child, path: childPath)
            }
            return lines.sorted()
        }
        guard let array = value as? [Any] else {
            return []
        }
        let lines = array.enumerated().flatMap { index, element in
            let url = (element as? [String: Any])?["url"] as? String
            return all(in: element, path: "\(path)[\(url ?? String(index))]")
        }
        return lines.sorted()
    }
}
