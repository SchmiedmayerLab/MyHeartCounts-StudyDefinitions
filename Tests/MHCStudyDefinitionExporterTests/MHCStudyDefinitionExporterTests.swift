//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
#if canImport(GroveQuestionnaire) && canImport(GroveQuestionnaireFHIR)
import GroveQuestionnaire
import GroveQuestionnaireFHIR
#endif
@_spi(APISupport)
import GroveStudyDefinition
import MHCStudyDefinitionExporter
import ModelsR4
import Testing


@Suite
struct MHCStudyDefinitionExporterTests {
    private static let questionnaireProfile =
        "https://grovealliance.org/fhir/questionnaire/StructureDefinition/grove-questionnaire"
    private static let itemControlURL = "http://hl7.org/fhir/StructureDefinition/questionnaire-itemControl"
    private static let usageContextSystem = "http://terminology.hl7.org/CodeSystem/usage-context-type"
    private static let versionAlgorithmURL =
        "http://hl7.org/fhir/StructureDefinition/artifact-versionAlgorithm"
    private static let versionAlgorithmSystem = "http://hl7.org/fhir/version-algorithm"
    private static let unitURL = "http://hl7.org/fhir/StructureDefinition/questionnaire-unit"
    private static let unitOptionURL = "http://hl7.org/fhir/StructureDefinition/questionnaire-unitOption"
    private static let minValueURL = "http://hl7.org/fhir/StructureDefinition/minValue"
    private static let maxValueURL = "http://hl7.org/fhir/StructureDefinition/maxValue"
    private static let minQuantityURL =
        "http://hl7.org/fhir/uv/sdc/StructureDefinition/sdc-questionnaire-minQuantity"
    private static let maxQuantityURL =
        "http://hl7.org/fhir/uv/sdc/StructureDefinition/sdc-questionnaire-maxQuantity"
    private static let observationExtractURL =
        "http://hl7.org/fhir/uv/sdc/StructureDefinition/sdc-questionnaire-observationExtract"
    private static let observationExtractCategoryURL =
        "http://hl7.org/fhir/uv/sdc/StructureDefinition/sdc-questionnaire-observation-extract-category"
    private static let languageTagSystem = "urn:ietf:bcp:47"
    /// The IG's `qg-version-1` invariant: Semantic Versioning 2.0.0.
    ///
    /// Computed rather than stored because `Regex` is not `Sendable`, which Swift 6 rejects in a `static let`.
    private static var semanticVersion: some RegexComponent {
        #/
        (?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)
        (?:-(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?
        (?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?
        /#
    }
    private static let localizedKeys: Set<String> = [
        "copyright", "description", "display", "language", "publisher", "purpose", "text", "title", "unit"
    ]

    @Test
    func export() throws {
        try StudyBundleFixture.withExportedStudyBundle {
            #expect($0.studyDefinition.studyRevision == 46)
        }
    }


    @Test
    func questionnaireCatalogUsesGroveFHIRContract() throws {
        try StudyBundleFixture.withExportedStudyBundle { bundle in
            let names = StudyBundleFixture.questionnaireNames(in: bundle)
            #expect(names.count == 14, "the study must declare 14 questionnaire components")
            var canonicalURLs: Set<String> = []
            for name in names {
                var projections: [Data] = []
                for (tag, locale) in StudyBundleFixture.locales {
                    let questionnaire = try #require(bundle.questionnaire(named: name, in: locale))
                    let json = try jsonObject(questionnaire)
                    validateQuestionnaire(json, named: "\(name)+\(tag)", locale: tag)
                    try validateGroveRoundTrip(questionnaire, original: json, named: "\(name)+\(tag)")
                    projections.append(try contractProjection(of: json))
                    if tag == "en-US", let canonicalURL = json["url"] as? String {
                        #expect(canonicalURLs.insert(canonicalURL).inserted, "\(name): canonical URL must be unique")
                    }
                }
                #expect(
                    projections.allSatisfy { $0 == projections[0] },
                    "\(name): the localized resources must be identical outside their localized text"
                )
            }
        }
    }
}


extension MHCStudyDefinitionExporterTests {
    /// Runs the Grove authoring diagnostics, native construction, and FHIR export, and holds the
    /// result to the shape it started from.
    private func validateGroveRoundTrip(
        _ questionnaire: ModelsR4.Questionnaire,
        original: [String: Any],
        named name: String
    ) throws {
        #if canImport(GroveQuestionnaire) && canImport(GroveQuestionnaireFHIR)
        let evaluationInstant = Date(timeIntervalSince1970: 1_700_000_000)
        let diagnostics = GroveQuestionnaire.Questionnaire.authoringDiagnostics(
            for: questionnaire,
            evaluationInstant: evaluationInstant
        )
        #expect(diagnostics.isEmpty, "\(name): Grove import diagnostics: \(diagnostics.joined(separator: "; "))")

        let nativeQuestionnaire = try GroveQuestionnaire.Questionnaire(
            questionnaire,
            evaluationInstant: evaluationInstant
        )
        let exported = try jsonObject(try ResourceBuilder().questionnaire(from: nativeQuestionnaire))
        for key in ["url", "version", "status"] {
            #expect(exported[key] as? String == original[key] as? String, "\(name): round trip changed \(key)")
        }
        let exportedStructure = try itemStructure(of: exported)
        let originalStructure = try itemStructure(of: original)
        #expect(
            exportedStructure == originalStructure,
            "\(name): round trip changed the ordered linkId/type item hierarchy"
        )
        #endif
    }


    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }


    private func itemStructure(of questionnaire: [String: Any]) throws -> Data {
        let items = questionnaire["item"] as? [[String: Any]] ?? []
        return try JSONSerialization.data(withJSONObject: itemStructure(of: items), options: [.sortedKeys])
    }


    private func itemStructure(of items: [[String: Any]]) -> [[String: Any]] {
        items.map { item in
            var structure: [String: Any] = [
                "linkId": item["linkId"] as? String ?? "",
                "type": item["type"] as? String ?? ""
            ]
            let children = item["item"] as? [[String: Any]] ?? []
            if !children.isEmpty {
                structure["item"] = itemStructure(of: children)
            }
            return structure
        }
    }


    private func validateQuestionnaire(_ questionnaire: [String: Any], named name: String, locale: String) {
        #expect(questionnaire["resourceType"] as? String == "Questionnaire", "\(name): resourceType must be Questionnaire")
        #expect(questionnaire["status"] as? String == "active", "\(name): status must be active")
        #expect(
            (questionnaire["version"] as? String)?.wholeMatch(of: Self.semanticVersion) != nil,
            "\(name): version must be a Semantic Versioning 2.0.0 version"
        )
        #expect(questionnaire["subjectType"] as? [String] == ["Patient"], "\(name): subjectType must be Patient")

        let canonical = questionnaire["url"] as? String
        #expect(
            canonical?.hasPrefix("https://myheartcounts.stanford.edu/fhir/survey/") == true
                && canonical?.contains("|") == false
                && canonical?.contains("#") == false,
            "\(name): url must be a My Heart Counts HTTP(S) canonical without a version separator or fragment"
        )

        validateLocaleMetadata(questionnaire, named: name, locale: locale)
        validateUseContext(questionnaire, named: name)
        validateVersionAlgorithm(questionnaire, named: name)

        let items = questionnaire["item"] as? [[String: Any]] ?? []
        #expect(!items.isEmpty, "\(name): at least one item is required")
        var linkIDs: Set<String> = []
        validateItems(items, questionnaire: name, linkIDs: &linkIDs)

        var elementIDs: [String] = []
        collectElementIDs(in: questionnaire, into: &elementIDs)
        #expect(elementIDs.count == Set(elementIDs).count, "\(name): FHIR element ids must be unique within a resource")
    }


    private func validateLocaleMetadata(_ questionnaire: [String: Any], named name: String, locale: String) {
        #expect(questionnaire["language"] as? String == locale, "\(name): language must be \(locale)")

        let meta = questionnaire["meta"] as? [String: Any]
        #expect(
            meta?["profile"] as? [String] == [Self.questionnaireProfile],
            "\(name): meta.profile must declare the Grove Questionnaire profile"
        )
        let tags = meta?["tag"] as? [[String: Any]] ?? []
        #expect(tags.count == 1, "\(name): exactly one meta.tag is required")
        #expect(
            tags.first?["system"] as? String == Self.languageTagSystem
                && tags.first?["code"] as? String == locale,
            "\(name): meta.tag must be the BCP-47 coding for \(locale)"
        )
        let display = tags.first?["display"] as? String
        #expect(!(display ?? "").isEmpty, "\(name): meta.tag requires a display name")
    }


    private func validateUseContext(_ questionnaire: [String: Any], named name: String) {
        let useContexts = questionnaire["useContext"] as? [[String: Any]] ?? []
        #expect(useContexts.count == 1, "\(name): exactly one clinical-focus useContext is required")
        for useContext in useContexts {
            let code = useContext["code"] as? [String: Any]
            let value = useContext["valueCodeableConcept"] as? [String: Any]
            #expect(
                code?["system"] as? String == Self.usageContextSystem && code?["code"] as? String == "focus",
                "\(name): useContext must use the standard clinical-focus code"
            )
            let focus = value?["text"] as? String
            #expect(!(focus ?? "").isEmpty, "\(name): clinical focus requires text")
            #expect(value?["coding"] == nil, "\(name): clinical focus must be text-only (no coding)")
        }
    }


    private func validateVersionAlgorithm(_ questionnaire: [String: Any], named name: String) {
        let extensions = questionnaire["extension"] as? [[String: Any]] ?? []
        let algorithms = extensions.filter { $0["url"] as? String == Self.versionAlgorithmURL }
        let algorithm = algorithms.first?["valueCoding"] as? [String: Any]
        #expect(algorithms.count == 1, "\(name): exactly one artifact-versionAlgorithm is required")
        #expect(
            algorithm?["system"] as? String == Self.versionAlgorithmSystem
                && algorithm?["code"] as? String == "semver",
            "\(name): artifact-versionAlgorithm must be the standard semver Coding"
        )
    }


    private func collectElementIDs(in value: Any, into elementIDs: inout [String]) {
        if let object = value as? [String: Any] {
            if let id = object["id"] as? String {
                elementIDs.append(id)
            }
            for child in object.values {
                collectElementIDs(in: child, into: &elementIDs)
            }
        } else if let array = value as? [Any] {
            for child in array {
                collectElementIDs(in: child, into: &elementIDs)
            }
        }
    }


    private func validateItems(
        _ items: [[String: Any]],
        questionnaire name: String,
        linkIDs: inout Set<String>
    ) {
        for item in items {
            let linkID = item["linkId"] as? String ?? ""
            let type = item["type"] as? String ?? ""
            let path = "\(name)/\(linkID)"
            #expect(!linkID.isEmpty, "\(name): every item requires linkId")
            #expect(linkIDs.insert(linkID).inserted, "\(name): duplicate linkId '\(linkID)'")
            #expect(type == "group" || !(item["text"] as? String ?? "").isEmpty, "\(path): text is required")

            let extensions = item["extension"] as? [[String: Any]] ?? []
            let extensionsByURL = Dictionary(grouping: extensions) { $0["url"] as? String ?? "" }

            if type == "display" {
                #expect(item["required"] == nil && item["repeats"] == nil, "\(path): display flags are invalid")
            }
            #expect(
                !(extensionsByURL[Self.itemControlURL] ?? []).contains { itemControl in
                    let value = itemControl["valueCodeableConcept"] as? [String: Any]
                    let codings = value?["coding"] as? [[String: Any]] ?? []
                    return codings.contains { $0["code"] as? String == "page" }
                },
                "\(path): R4 itemControl does not define the page code"
            )

            if type == "quantity" {
                validateQuantityContract(extensionsByURL, path: path)
            } else {
                for url in [Self.unitOptionURL, Self.minQuantityURL, Self.maxQuantityURL] {
                    #expect(extensionsByURL[url] == nil, "\(path): \(url) is only valid on quantity")
                }
            }
            validateExtractionContract(item, type: type, extensionsByURL: extensionsByURL, path: path)

            validateItems(
                item["item"] as? [[String: Any]] ?? [],
                questionnaire: name,
                linkIDs: &linkIDs
            )
        }
    }


    /// The SDC extraction contract every marked item owes, whatever the instrument.
    ///
    /// Extraction keys off `item.code`, so a marking without one produces nothing; a marked group
    /// produces an Observation whose components are exactly its marked, coded question children.
    private func validateExtractionContract(
        _ item: [String: Any],
        type: String,
        extensionsByURL: [String: [[String: Any]]],
        path: String
    ) {
        let markings = extensionsByURL[Self.observationExtractURL] ?? []
        let categories = extensionsByURL[Self.observationExtractCategoryURL] ?? []
        #expect(markings.count <= 1, "\(path): at most one observationExtract marking is allowed")
        guard let marking = markings.first else {
            #expect(categories.isEmpty, "\(path): observationExtractCategory requires an observationExtract marking")
            return
        }
        let extractsObservation = marking["valueBoolean"] as? Bool == true
        #expect(
            extractsObservation || marking["valueCode"] as? String == "component",
            "\(path): observationExtract must be true or the component code"
        )
        #expect(carriesOneCode(item), "\(path): an extract-marked item must carry one coded item.code")
        #expect(categories.count <= 1, "\(path): at most one observationExtractCategory is allowed")
        #expect(extractsObservation || categories.isEmpty, "\(path): only an extracted Observation carries a category")
        for category in categories {
            let concept = category["valueCodeableConcept"] as? [String: Any]
            let codings = concept?["coding"] as? [[String: Any]] ?? []
            #expect(
                codings.count == 1 && isCoded(codings.first ?? [:]),
                "\(path): observationExtractCategory must carry one coded category"
            )
        }
        guard extractsObservation, type == "group" else {
            return
        }
        let children = (item["item"] as? [[String: Any]] ?? []).filter { $0["type"] as? String != "display" }
        #expect(!children.isEmpty, "\(path): a marked group needs the questions its components come from")
        for child in children {
            let childPath = "\(path)/\(child["linkId"] as? String ?? "")"
            let childExtensions = child["extension"] as? [[String: Any]] ?? []
            #expect(
                childExtensions.contains {
                    $0["url"] as? String == Self.observationExtractURL && $0["valueCode"] as? String == "component"
                },
                "\(childPath): every question under a marked group must be marked component"
            )
            #expect(carriesOneCode(child), "\(childPath): a component question must carry one coded item.code")
        }
    }


    private func isCoded(_ coding: [String: Any]) -> Bool {
        !(coding["system"] as? String ?? "").isEmpty && !(coding["code"] as? String ?? "").isEmpty
    }


    private func carriesOneCode(_ item: [String: Any]) -> Bool {
        let codings = item["code"] as? [[String: Any]] ?? []
        return codings.count == 1 && isCoded(codings[0])
    }


    private func validateQuantityContract(_ extensionsByURL: [String: [[String: Any]]], path: String) {
        #expect(extensionsByURL[Self.unitURL] == nil, "\(path): quantity must not use questionnaire-unit")
        #expect(extensionsByURL[Self.minValueURL] == nil, "\(path): quantity must not use minValue")
        #expect(extensionsByURL[Self.maxValueURL] == nil, "\(path): quantity must not use maxValue")

        let unitOptions = extensionsByURL[Self.unitOptionURL] ?? []
        let minimumQuantities = extensionsByURL[Self.minQuantityURL] ?? []
        let maximumQuantities = extensionsByURL[Self.maxQuantityURL] ?? []
        #expect(unitOptions.count == 1, "\(path): fixed quantity requires one unitOption")

        let unit = unitOptions.first?["valueCoding"] as? [String: Any]
        let unitSystem = unit?["system"] as? String
        let unitCode = unit?["code"] as? String
        #expect(unitSystem == "http://unitsofmeasure.org", "\(path): unit must use UCUM")
        #expect(!(unitCode ?? "").isEmpty, "\(path): unit must carry a UCUM code")
        #expect(minimumQuantities.count <= 1, "\(path): at most one minimum quantity is allowed")
        #expect(maximumQuantities.count <= 1, "\(path): at most one maximum quantity is allowed")

        let minimum = minimumQuantities.first.flatMap {
            validateQuantityBound($0, unitSystem: unitSystem, unitCode: unitCode, path: "\(path)/minimum")
        }
        let maximum = maximumQuantities.first.flatMap {
            validateQuantityBound($0, unitSystem: unitSystem, unitCode: unitCode, path: "\(path)/maximum")
        }
        if let minimum, let maximum {
            #expect(minimum <= maximum, "\(path): minimum exceeds maximum")
        }
    }


    private func validateQuantityBound(
        _ bound: [String: Any],
        unitSystem: String?,
        unitCode: String?,
        path: String
    ) -> Decimal? {
        let quantity = bound["valueQuantity"] as? [String: Any]
        let value = quantity?["value"] as? NSNumber
        #expect(value != nil, "\(path): valueQuantity.value is required")
        #expect(quantity?["system"] as? String == unitSystem, "\(path): system must match unitOption")
        #expect(quantity?["code"] as? String == unitCode, "\(path): code must match unitOption")
        return value?.decimalValue
    }


    private func contractProjection(of questionnaire: [String: Any]) throws -> Data {
        let projected = projectContract(questionnaire, key: nil)
        return try JSONSerialization.data(withJSONObject: projected as Any, options: [.sortedKeys])
    }


    /// Everything outside the localized text and the per-locale metadata, which is pinned separately.
    private func projectContract(_ value: Any, key: String?) -> Any? {
        if let key, Self.localizedKeys.contains(key) {
            return nil
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, element in
                if key == "meta", element.key == "tag" {
                    return
                }
                if let projected = projectContract(element.value, key: element.key) {
                    result[element.key] = projected
                }
            }
        }
        if let array = value as? [Any] {
            return array.compactMap { projectContract($0, key: key) }
        }
        return value
    }
}
