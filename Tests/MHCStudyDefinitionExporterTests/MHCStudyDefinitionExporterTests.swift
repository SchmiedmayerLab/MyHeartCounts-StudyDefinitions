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
import Testing


@Suite
struct MHCStudyDefinitionExporterTests {
    private static let questionnaireNames = [
        "ActivityFitness",
        "Chronotype",
        "Diet",
        "DiseaseQOL",
        "ExerciseAdequacy",
        "ExerciseProcessMindset",
        "Fatigue",
        "GAD7",
        "HeartRisk",
        "Info",
        "NicotineExposure",
        "ParQ",
        "SUS",
        "WHO5"
    ]
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

    @Test
    func export() throws {
        let fileManager = FileManager.default
        let dstDir = URL.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: dstDir, withIntermediateDirectories: true)
        defer {
            // let's clean up after ourselves
            try? fileManager.removeItem(at: dstDir)
        }
        let archiveUrl: URL
        do {
            archiveUrl = try MHCStudyDefinitionExporter.export(to: dstDir, as: .zstd)
            let bundleUrl = dstDir.appending(
                path: "mhcStudyBundle.\(StudyBundle.fileExtension)",
                directoryHint: .isDirectory
            )
            let bundle = try StudyBundle.unarchive(archiveUrl, to: bundleUrl)
            #expect(bundle.studyDefinition.studyRevision == 45)
        } catch StudyBundle.CreateBundleError.failedValidation(let issues) {
            let desc = issues.enumerated().reduce(into: "Failed Validation:\n") { desc, element in
                let (idx, issue) = element
                desc += "\n[\(String(format: "%02li", idx + 1))] \(issue)"
                if idx < issues.endIndex - 1 {
                    desc += "\n"
                }
            }
            Issue.record("\(desc)")
            return
        }
        #expect(fileManager.itemExists(at: archiveUrl))
    }


    @Test
    func questionnaireCatalogUsesGroveFHIRContract() throws {
        try withExportedStudyBundle { bundle in
            var canonicalURLs: Set<String> = []
            for name in Self.questionnaireNames {
                let english = try questionnaireJSON(named: name, locale: Locale(identifier: "en_US"), in: bundle)
                let spanish = try questionnaireJSON(named: name, locale: Locale(identifier: "es_US"), in: bundle)

                validateQuestionnaire(english, named: "\(name)+en-US")
                validateQuestionnaire(spanish, named: "\(name)+es-US")

                let englishContract = try contractProjection(of: english)
                let spanishContract = try contractProjection(of: spanish)
                expect(
                    englishContract == spanishContract,
                    "\(name): localized resources must have the same canonical, item hierarchy, and answer contract"
                )
                if let canonicalURL = english["url"] as? String {
                    expect(canonicalURLs.insert(canonicalURL).inserted, "\(name): canonical URL must be unique")
                }
            }
        }
    }
}


extension MHCStudyDefinitionExporterTests {
    private func withExportedStudyBundle(_ operation: (StudyBundle) throws -> Void) throws {
        let fileManager = FileManager.default
        let destination = URL.temporaryDirectory.appending(component: UUID().uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: destination)
        }

        let archive = try MHCStudyDefinitionExporter.export(to: destination, as: .zstd)
        let bundleURL = destination.appending(
            path: "mhcStudyBundle.\(StudyBundle.fileExtension)",
            directoryHint: .isDirectory
        )
        let bundle = try StudyBundle.unarchive(archive, to: bundleURL)
        try operation(bundle)
    }


    private func questionnaireJSON(named name: String, locale: Locale, in bundle: StudyBundle) throws -> [String: Any] {
        let questionnaire = try #require(bundle.questionnaire(named: name, in: locale))
        let originalJSON = try jsonObject(questionnaire)
        #if canImport(GroveQuestionnaire) && canImport(GroveQuestionnaireFHIR)
        let label = "\(name)+\(locale.identifier)"
        let evaluationInstant = Date(timeIntervalSince1970: 1_700_000_000)
        let diagnostics = GroveQuestionnaire.Questionnaire.authoringDiagnostics(
            for: questionnaire,
            evaluationInstant: evaluationInstant
        )
        expect(diagnostics.isEmpty, "\(label): Grove import diagnostics: \(diagnostics.joined(separator: "; "))")

        let nativeQuestionnaire = try GroveQuestionnaire.Questionnaire(
            questionnaire,
            evaluationInstant: evaluationInstant
        )
        let exportedQuestionnaire = try ResourceBuilder().questionnaire(from: nativeQuestionnaire)
        let exportedJSON = try jsonObject(exportedQuestionnaire)

        for key in ["url", "version", "status"] {
            expect(exportedJSON[key] as? String == originalJSON[key] as? String, "\(label): round trip changed \(key)")
        }
        let originalStructure = try itemStructure(of: originalJSON)
        let exportedStructure = try itemStructure(of: exportedJSON)
        expect(
            exportedStructure == originalStructure,
            "\(label): round trip changed the ordered linkId/type item hierarchy"
        )
        #endif
        return originalJSON
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


    private func validateQuestionnaire(_ questionnaire: [String: Any], named name: String) {
        expect(questionnaire["resourceType"] as? String == "Questionnaire", "\(name): resourceType must be Questionnaire")
        expect(questionnaire["status"] as? String == "active", "\(name): status must be active")
        expect(questionnaire["version"] as? String == "0.0.0", "\(name): version must be 0.0.0")
        expect(questionnaire["subjectType"] as? [String] == ["Patient"], "\(name): subjectType must be Patient")

        let canonical = questionnaire["url"] as? String
        expect(
            canonical?.hasPrefix("https://myheartcounts.stanford.edu/fhir/survey/") == true
                && canonical?.contains("|") == false
                && canonical?.contains("#") == false,
            "\(name): url must be the exact My Heart Counts HTTP(S) canonical"
        )

        let meta = questionnaire["meta"] as? [String: Any]
        expect(
            meta?["profile"] as? [String] == [Self.questionnaireProfile],
            "\(name): meta.profile must declare the Grove Questionnaire profile"
        )

        let contacts = questionnaire["contact"] as? [[String: Any]] ?? []
        expect(contacts.allSatisfy { !$0.isEmpty }, "\(name): contact entries must not be empty")
        let useContexts = questionnaire["useContext"] as? [[String: Any]] ?? []
        expect(useContexts.count == 1, "\(name): exactly one clinical-focus useContext is required")
        for useContext in useContexts {
            let code = useContext["code"] as? [String: Any]
            let value = useContext["valueCodeableConcept"] as? [String: Any]
            expect(
                code?["system"] as? String == Self.usageContextSystem && code?["code"] as? String == "focus",
                "\(name): useContext must use the standard clinical-focus code"
            )
            expect(!(value?["text"] as? String ?? "").isEmpty, "\(name): clinical focus requires text")
            expect(value?["coding"] == nil, "\(name): clinical focus must not claim an uncoded terminology system")
        }

        let extensions = questionnaire["extension"] as? [[String: Any]] ?? []
        let algorithms = extensions.filter { $0["url"] as? String == Self.versionAlgorithmURL }
        let algorithm = algorithms.first?["valueCoding"] as? [String: Any]
        expect(algorithms.count == 1, "\(name): exactly one artifact-versionAlgorithm is required")
        expect(
            algorithm?["system"] as? String == Self.versionAlgorithmSystem
                && algorithm?["code"] as? String == "semver",
            "\(name): artifact-versionAlgorithm must be the standard semver Coding"
        )

        let items = questionnaire["item"] as? [[String: Any]] ?? []
        expect(!items.isEmpty, "\(name): at least one item is required")
        var linkIDs: Set<String> = []
        validateItems(items, questionnaire: name, linkIDs: &linkIDs)

        var elementIDs: [String] = []
        collectElementIDs(in: questionnaire, into: &elementIDs)
        expect(elementIDs.count == Set(elementIDs).count, "\(name): FHIR element ids must be unique within a resource")
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
            expect(!linkID.isEmpty, "\(name): every item requires linkId")
            expect(linkIDs.insert(linkID).inserted, "\(name): duplicate linkId '\(linkID)'")
            expect(type == "group" || !(item["text"] as? String ?? "").isEmpty, "\(name)/\(linkID): text is required")

            let extensions = item["extension"] as? [[String: Any]] ?? []
            let extensionsByURL = Dictionary(grouping: extensions) { $0["url"] as? String ?? "" }
            let unitOptions = extensionsByURL[Self.unitOptionURL] ?? []
            let minimumQuantities = extensionsByURL[Self.minQuantityURL] ?? []
            let maximumQuantities = extensionsByURL[Self.maxQuantityURL] ?? []
            let itemControls = extensionsByURL[Self.itemControlURL] ?? []

            if type == "display" {
                expect(item["required"] == nil && item["repeats"] == nil, "\(name)/\(linkID): display flags are invalid")
            }
            expect(
                !itemControls.contains { itemControl in
                    let value = itemControl["valueCodeableConcept"] as? [String: Any]
                    let codings = value?["coding"] as? [[String: Any]] ?? []
                    return codings.contains { $0["code"] as? String == "page" }
                },
                "\(name)/\(linkID): R4 itemControl does not define the page code"
            )

            if type == "quantity" {
                validateQuantityContract(
                    extensionsByURL,
                    unitOptions: unitOptions,
                    minimumQuantities: minimumQuantities,
                    maximumQuantities: maximumQuantities,
                    path: "\(name)/\(linkID)"
                )
            } else {
                expect(unitOptions.isEmpty, "\(name)/\(linkID): unitOption is only valid on quantity")
                expect(minimumQuantities.isEmpty, "\(name)/\(linkID): minQuantity is only valid on quantity")
                expect(maximumQuantities.isEmpty, "\(name)/\(linkID): maxQuantity is only valid on quantity")
            }

            validateItems(
                item["item"] as? [[String: Any]] ?? [],
                questionnaire: name,
                linkIDs: &linkIDs
            )
        }
    }


    private func validateQuantityContract(
        _ extensionsByURL: [String: [[String: Any]]],
        unitOptions: [[String: Any]],
        minimumQuantities: [[String: Any]],
        maximumQuantities: [[String: Any]],
        path: String
    ) {
        expect(extensionsByURL[Self.unitURL] == nil, "\(path): quantity must not use questionnaire-unit")
        expect(extensionsByURL[Self.minValueURL] == nil, "\(path): quantity must not use minValue")
        expect(extensionsByURL[Self.maxValueURL] == nil, "\(path): quantity must not use maxValue")
        expect(unitOptions.count == 1, "\(path): fixed quantity requires one unitOption")

        let unit = unitOptions.first?["valueCoding"] as? [String: Any]
        let unitSystem = unit?["system"] as? String
        let unitCode = unit?["code"] as? String
        expect(unitSystem == "http://unitsofmeasure.org", "\(path): unit must use UCUM")
        expect(!(unitCode ?? "").isEmpty, "\(path): unit must carry a UCUM code")
        expect(minimumQuantities.count <= 1, "\(path): at most one minimum quantity is allowed")
        expect(maximumQuantities.count <= 1, "\(path): at most one maximum quantity is allowed")
        if let minimum = minimumQuantities.first {
            validateQuantityBound(minimum, unitSystem: unitSystem, unitCode: unitCode, path: "\(path)/minimum")
        }
        if let maximum = maximumQuantities.first {
            validateQuantityBound(maximum, unitSystem: unitSystem, unitCode: unitCode, path: "\(path)/maximum")
        }
        if let minimum = minimumQuantities.first.flatMap(quantityValue),
           let maximum = maximumQuantities.first.flatMap(quantityValue) {
            expect(minimum <= maximum, "\(path): minimum exceeds maximum")
        }
    }


    private func validateQuantityBound(
        _ bound: [String: Any],
        unitSystem: String?,
        unitCode: String?,
        path: String
    ) {
        let quantity = bound["valueQuantity"] as? [String: Any]
        expect(quantity?["value"] as? NSNumber != nil, "\(path): valueQuantity.value is required")
        expect(quantity?["system"] as? String == unitSystem, "\(path): system must match unitOption")
        expect(quantity?["code"] as? String == unitCode, "\(path): code must match unitOption")
    }


    private func quantityValue(_ bound: [String: Any]) -> Decimal? {
        guard let number = (bound["valueQuantity"] as? [String: Any])?["value"] as? NSNumber else {
            return nil
        }
        return number.decimalValue
    }


    private func contractProjection(of questionnaire: [String: Any]) throws -> Data {
        let projected = projectContract(questionnaire, key: nil)
        return try JSONSerialization.data(withJSONObject: projected as Any, options: [.sortedKeys])
    }


    private func projectContract(_ value: Any, key: String?) -> Any? {
        let localizedKeys: Set<String> = [
            "contact", "copyright", "description", "display", "language", "publisher", "purpose", "text", "title", "unit"
        ]
        if let key, localizedKeys.contains(key) {
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


    private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            Issue.record("\(message)")
        }
    }
}
