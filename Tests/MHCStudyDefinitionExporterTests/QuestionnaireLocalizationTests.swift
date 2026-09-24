//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
#if canImport(GroveQuestionnaireFHIR)
import GroveQuestionnaireFHIR
#endif
@_spi(APISupport)
import GroveStudyDefinition
import ModelsR4
import Testing


/// Holds the exported bundle to one multilingual Questionnaire per instrument, built from its per-locale sources.
@Suite
struct QuestionnaireLocalizationTests {
    /// The strings that are presentation text, at any depth, and so carry a translation wherever the sources differ.
    private static let presentationKeys: Set<String> = [
        "title", "description", "purpose", "copyright", "text", "prefix", "display", "unit", "valueString", "valueMarkdown"
    ]
    /// What describes each locale source rather than the instrument, so the export keeps the base's.
    private static let perSourceKeys: Set<String> = ["language", "meta"]

    @Test
    func bundleCarriesOneMultilingualQuestionnairePerInstrument() throws {
        try StudyBundleFixture.withExportedStudyBundle { bundle in
            let names = StudyBundleFixture.questionnaireNames(in: bundle)
            let files = try FileManager.default.contentsOfDirectory(
                at: bundle.bundleUrl.appending(component: StudyBundle.FileReference.Category.questionnaire.rawValue),
                includingPropertiesForKeys: nil
            )
            #expect(files.count == names.count, "the bundle must carry exactly one Questionnaire file per instrument")
            for name in names {
                #expect(files.count(where: { $0.lastPathComponent.hasPrefix("\(name)+") }) == 1, "\(name): one merged file")
                let merged = try jsonObject(try #require(bundle.questionnaire(named: name)))
                #expect(merged["language"] as? String == StudyBundleFixture.baseLocale, "\(name): base language")
                validateTranslations(
                    merged: merged,
                    base: try StudyBundleFixture.source(named: name, in: StudyBundleFixture.baseLocale)
                        .filter { !Self.perSourceKeys.contains($0.key) },
                    translation: try StudyBundleFixture.source(named: name, in: StudyBundleFixture.translationLocale),
                    path: name
                )
            }
        }
    }


    /// The strings beyond item text that HeartRisk presents: its purpose, the bound units and the extracted category.
    @Test
    func heartRiskCarriesItsPresentationStringsInSpanish() throws {
        try StudyBundleFixture.withExportedStudyBundle { bundle in
            let merged = try jsonObject(try #require(bundle.questionnaire(named: "HeartRisk")))
            let wrapper = try #require((merged["item"] as? [[String: Any]])?.first)
            let panel = try #require((wrapper["item"] as? [[String: Any]])?.first { $0["linkId"] as? String == "blood-pressure-panel" })
            let systolic = try #require((panel["item"] as? [[String: Any]])?.first)
            let category = Self.extensions(of: panel, url: "sdc-questionnaire-observation-extract-category")
                .compactMap { (($0["valueCodeableConcept"] as? [String: Any])?["coding"] as? [[String: Any]])?.first }
            let bounds = ["sdc-questionnaire-minQuantity", "sdc-questionnaire-maxQuantity"]
                .flatMap { Self.extensions(of: systolic, url: $0) }
                .compactMap { $0["valueQuantity"] as? [String: Any] }
            let spanish = { (value: String) in [StudyBundleFixture.translationLocale: value] }

            #expect(Translations.of(merged["_purpose"]) == spanish("Un vistazo rápido a su historial de salud y biomarcadores"))
            #expect(category.map { Translations.of($0["_display"]) } == [spanish("Signos vitales")])
            #expect(bounds.count == 2)
            #expect(bounds.allSatisfy { Translations.of($0["_unit"]) == spanish("milímetros de mercurio") })
        }
    }


    /// A participant answering GAD-7 in Spanish names `es-US` and carries neither item text nor coded displays,
    /// and the exported instrument accepts that response as is.
    @Test
    func spanishResponsePairsWithTheMultilingualInstrument() throws {
        try StudyBundleFixture.withExportedStudyBundle { bundle in
            let questionnaire = try #require(bundle.questionnaire(named: "GAD7"))
            let response = try ResponseFixture.completed(
                questionnaire,
                in: StudyBundleFixture.translationLocale.asFHIRStringPrimitive(),
                identifier: "gad7-localization-contract",
                items: Self.firstOptionAnswers(to: questionnaire.item ?? [])
            )
            let json = try jsonObject(response)
            #expect(Self.answerCount(in: json["item"]) == 7, "GAD-7 answers all seven items")
            #expect(Self.displayedStrings(in: json["item"]).isEmpty, "a translated response carries no item text or display")
            #if canImport(GroveQuestionnaireFHIR)
            let issues = PairValidator().issues(questionnaire: questionnaire, response: response)
            #expect(issues.isEmpty, "\(issues.map(\.message))")
            #endif

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            Attachment.record(try encoder.encode(questionnaire), named: "GAD7-questionnaire.json")
            Attachment.record(try encoder.encode(response), named: "GAD7-response-es-US.json")
        }
    }
}


extension QuestionnaireLocalizationTests {
    /// Answers every coded question with its first option, identified by system and code alone.
    private static func firstOptionAnswers(to items: [QuestionnaireItem]) -> [QuestionnaireResponseItem] {
        items.compactMap { item in
            let linkID = item.linkId.value?.string ?? ""
            if item.type.value == .group {
                let children = firstOptionAnswers(to: item.item ?? [])
                return children.isEmpty ? nil : ResponseFixture.item(linkID, children: children)
            }
            guard case .coding(let coding)? = item.answerOption?.first?.value else {
                return nil
            }
            let answer = QuestionnaireResponseItemAnswer(value: .coding(Coding(code: coding.code, system: coding.system)))
            return ResponseFixture.item(linkID, answer: answer)
        }
    }


    private static func answerCount(in value: Any?) -> Int {
        if let object = value as? [String: Any] {
            return ((object["answer"] as? [Any])?.count ?? 0) + answerCount(in: object["item"])
        }
        return (value as? [Any])?.reduce(0) { $0 + answerCount(in: $1) } ?? 0
    }


    /// The item text and coded displays a response carries.
    private static func displayedStrings(in value: Any?) -> [String] {
        if let object = value as? [String: Any] {
            return object.flatMap { key, child in
                ["text", "display"].contains(key) ? [child as? String ?? ""] : displayedStrings(in: child)
            }
        }
        return (value as? [Any])?.flatMap { displayedStrings(in: $0) } ?? []
    }


    private static func extensions(of element: [String: Any], url suffix: String) -> [[String: Any]] {
        (element["extension"] as? [[String: Any]] ?? []).filter { ($0["url"] as? String)?.hasSuffix("/\(suffix)") == true }
    }


    /// Holds every presentation string of the merged resource to its `en-US` source, carrying the `es-US` source's
    /// string as its only translation wherever the two differ.
    private func validateTranslations(merged: Any?, base: Any, translation: Any?, path: String) {
        if let base = base as? [String: Any] {
            let merged = merged as? [String: Any]
            let translation = translation as? [String: Any]
            for (key, value) in base {
                let keyPath = "\(path).\(key)"
                guard Self.presentationKeys.contains(key), let string = value as? String else {
                    validateTranslations(merged: merged?[key], base: value, translation: translation?[key], path: keyPath)
                    continue
                }
                #expect(merged?[key] as? String == string, "\(keyPath): the base must be the en-US source")
                let translated = translation?[key] as? String
                let expected = translated.flatMap { $0 == string ? nil : [StudyBundleFixture.translationLocale: $0] } ?? [:]
                #expect(Translations.of(merged?["_\(key)"]) == expected, "\(keyPath): translation must be the es-US source")
            }
        } else if let base = base as? [Any] {
            let merged = merged as? [Any] ?? []
            let translation = translation as? [Any] ?? []
            for (index, element) in base.enumerated() {
                validateTranslations(
                    merged: merged.indices.contains(index) ? merged[index] : nil,
                    base: element,
                    translation: translation.indices.contains(index) ? translation[index] : nil,
                    path: "\(path)[\(index)]"
                )
            }
        }
    }


    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: try JSONEncoder().encode(value)) as? [String: Any])
    }
}
