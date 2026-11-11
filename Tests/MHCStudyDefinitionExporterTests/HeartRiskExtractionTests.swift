//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
#if canImport(FHIRPathParser)
import FHIRPathParser
#endif
import Foundation
import GroveFHIRContract
import GroveQuestionnaireExtraction
#if canImport(GroveQuestionnaireFHIR)
import GroveQuestionnaireFHIR
#endif
@_spi(APISupport)
import GroveStudyDefinition
import ModelsR4
import Testing


/// Holds the HeartRisk instrument to the measurements it promises to extract.
///
/// The exported instrument meets a hand-written response conforming to the Grove QuestionnaireResponse
/// profile, and Grove projects the pair, so a dropped marking, a drifted LOINC, a renamed linkId, or a
/// missing category fails here rather than in a study's data.
@Suite
struct HeartRiskExtractionTests {
    private static let bloodPressurePanelLinkID = "blood-pressure-panel"
    private static let systolicLinkID = "7cec349c-495c-4ef6-834e-cc9708625736"
    private static let diastolicLinkID = "b25ac0aa-4528-47dc-951f-97f411ec5cc2"
    private static let glucoseLinkID = "7309938e-ea24-4e31-8427-82f3a1a44f83"
    /// The Imperial question the participant answers in mmol/L; `glucoseLinkID` is the hidden item calculated from it.
    private static let imperialGlucoseEntryLinkID = "30f4d33d-b4a1-4a56-9e89-717034b64efa"
    private static let calculatedExpressionURL = "http://hl7.org/fhir/uv/sdc/StructureDefinition/sdc-questionnaire-calculatedExpression"
    private static let observationCategorySystem = "http://terminology.hl7.org/CodeSystem/observation-category"

    @Test
    func heartRiskKeepsOneTopLevelGroup() throws {
        try StudyBundleFixture.withExportedStudyBundle { bundle in
            let questionnaire = try #require(bundle.questionnaire(named: "HeartRisk"))
            #expect(questionnaire.version?.value?.string == "0.2.0")
            let items = questionnaire.item ?? []
            // Grove renders every top-level group as its own section, so the wrapper keeps HeartRisk one page.
            #expect(items.count == 1, "HeartRisk must keep exactly one top-level group")
            #expect(items.first?.linkId.value?.string == "heart-risk")
            #expect(items.first?.type.value == .group)
        }
    }


    @Test
    func markedMeasurementsProjectIntoConformingObservations() async throws {
        var record: QuestionnaireFHIRExporter.Record?
        try StudyBundleFixture.withExportedStudyBundle { bundle in
            let questionnaire = try #require(bundle.questionnaire(named: "HeartRisk"))
            let response = try Self.response(for: questionnaire)
            #if canImport(GroveQuestionnaireFHIR)
            let evaluator = try PairExpressionEvaluator.fhirPath(questionnaire: questionnaire, response: response)
            let issues = PairValidator(expressionEvaluator: evaluator).issues(questionnaire: questionnaire, response: response)
            #expect(issues.isEmpty, "\(issues.map(\.message))")
            #endif
            record = QuestionnaireFHIRExporter.Record(questionnaire: questionnaire, response: response)
        }
        let graph = try await Self.exchangeGraph(of: try #require(record))
        let observations = (graph.bundle.entry ?? []).compactMap { entry -> Observation? in
            guard case .observation(let observation) = entry.resource else {
                return nil
            }
            return observation
        }
        #expect(observations.count == 2, "HeartRisk extracts the blood-pressure panel and the fasting glucose")
        try validateBloodPressure(try #require(observations.first { Self.code(of: $0) == "85354-9" }))
        try validateGlucose(try #require(observations.first { Self.code(of: $0) == "2339-0" }))
    }


    #if canImport(GroveQuestionnaireFHIR)
    @Test(arguments: [false, true], [false, true])
    func bloodPressureAnswersMustBePaired(systolic: Bool, diastolic: Bool) throws {
        try StudyBundleFixture.withExportedStudyBundle { bundle in
            let questionnaire = try #require(bundle.questionnaire(named: "HeartRisk"))
            for locale in StudyBundleFixture.locales {
                var response = try Self.response(for: questionnaire, systolic: systolic, diastolic: diastolic)
                response.language = locale.asFHIRStringPrimitive()
                let evaluator = try PairExpressionEvaluator.fhirPath(questionnaire: questionnaire, response: response)
                let issues = PairValidator(expressionEvaluator: evaluator).issues(questionnaire: questionnaire, response: response)
                if systolic == diastolic {
                    #expect(issues.isEmpty, "\(locale): \(issues.map(\.message))")
                } else {
                    #expect(issues.count == 1, "\(locale): \(issues.map(\.message))")
                    #expect(issues.first?.code == .targetConstraint)
                    #expect(issues.first?.severity == .error)
                }
            }
        }
    }
    #endif


    @Test
    func unansweredBloodPressureStillExtractsGlucose() async throws {
        var record: QuestionnaireFHIRExporter.Record?
        try StudyBundleFixture.withExportedStudyBundle { bundle in
            let questionnaire = try #require(bundle.questionnaire(named: "HeartRisk"))
            record = QuestionnaireFHIRExporter.Record(
                questionnaire: questionnaire,
                response: try Self.response(for: questionnaire, systolic: false, diastolic: false)
            )
        }
        let graph = try await Self.exchangeGraph(of: try #require(record))
        let observations = (graph.bundle.entry ?? []).compactMap { entry -> Observation? in
            guard case .observation(let observation) = entry.resource else {
                return nil
            }
            return observation
        }
        #expect(observations.count == 1)
        try validateGlucose(try #require(observations.first))
    }


    #if canImport(FHIRPathParser)
    /// Imperial asks for fasting glucose in mmol/L, which the IG does not extract as 2339-0. A hidden item
    /// under the shared glucose linkId calculates the mg/dL value, and only that item extracts.
    @Test
    func imperialGlucoseExtractsInMilligramsPerDeciliter() async throws {
        var record: QuestionnaireFHIRExporter.Record?
        var converted: Decimal?
        try StudyBundleFixture.withExportedStudyBundle(variant: .imperial) { bundle in
            let questionnaire = try #require(bundle.questionnaire(named: "HeartRisk"))
            let entry = ResponseFixture.item(
                Self.imperialGlucoseEntryLinkID,
                answer: Self.answer(5.5, code: "mmol/L", unit: "millimole per litre")
            )
            // The participant's answer alone, as the form holds it before the hidden item is calculated.
            let milligrams = try Self.calculatedGlucose(
                in: questionnaire,
                from: try Self.response(for: questionnaire, glucose: [entry])
            )
            #expect((milligrams - 99.0858).magnitude < 0.0001, "5.5 mmol/L × 18.0156 is 99.0858 mg/dL")
            converted = milligrams
            let response = try Self.response(for: questionnaire, glucose: [
                entry,
                ResponseFixture.item(Self.glucoseLinkID, answer: Self.answer(milligrams, code: "mg/dL", unit: "milligram per deciliter"))
            ])
            #if canImport(GroveQuestionnaireFHIR)
            let evaluator = try PairExpressionEvaluator.fhirPath(questionnaire: questionnaire, response: response)
            let issues = PairValidator(expressionEvaluator: evaluator).issues(questionnaire: questionnaire, response: response)
            #expect(issues.isEmpty, "\(issues.map(\.message))")
            #endif
            record = QuestionnaireFHIRExporter.Record(questionnaire: questionnaire, response: response)
        }
        let graph = try await Self.exchangeGraph(of: try #require(record))
        let observations = (graph.bundle.entry ?? []).compactMap { entry -> Observation? in
            guard case .observation(let observation) = entry.resource else {
                return nil
            }
            return observation
        }
        #expect(observations.count == 2, "the mmol/L answer itself must not extract")
        try validateGlucose(
            try #require(observations.first { Self.code(of: $0) == "2339-0" }),
            value: try #require(converted)
        )
    }
    #endif


    private func validateBloodPressure(_ observation: Observation) throws {
        #expect(observation.meta?.profile == [Profile.groveMobileBloodPressure])
        #expect(
            observation.category?.count == 1,
            "the blood-pressure panel must extract into the one category its profile requires"
        )
        let category = try #require(observation.category?.first)
        #expect(category.coding?.count == 1, "the vital-signs category carries exactly one coding")
        #expect(category.coding?.first?.system?.value?.url.absoluteString == Self.observationCategorySystem)
        #expect(category.coding?.first?.code?.value?.string == "vital-signs")
        let components = observation.component ?? []
        #expect(components.count == 2)
        #expect(Self.quantity(of: components.first { Self.code(of: $0) == "8480-6" }) == (118, "mm[Hg]"))
        #expect(Self.quantity(of: components.first { Self.code(of: $0) == "8462-4" }) == (76, "mm[Hg]"))
        #expect(observation.value == nil, "a panel carries its readings as components")
        validateProvenanceContract(observation)
    }


    private func validateGlucose(_ observation: Observation, value: Decimal = 95) throws {
        #expect(observation.meta?.profile == [Profile.groveMobileBloodGlucoseUnspecifiedSpecimen])
        // The glucose profile fixes no category, so the instrument deliberately declares none.
        #expect(observation.category == nil)
        #expect(observation.component == nil)
        guard case .quantity(let quantity)? = observation.value else {
            Issue.record("the fasting glucose must extract as a Quantity")
            return
        }
        #expect(quantity.value?.value?.decimal == value)
        #expect(quantity.code?.value?.string == "mg/dL")
        validateProvenanceContract(observation)
    }


    /// Every extracted Observation states report-time semantics and manual entry, which is what the
    /// IG's recall relaxation requires of a self-reported measurement.
    private func validateProvenanceContract(_ observation: Observation) {
        let recordingMethods = (observation.extension ?? []).filter { $0.url == Canonicals.recordingMethod }
        #expect(recordingMethods.count == 1, "an extracted Observation must state its recording method")
        // GroveRecordingMethod fixes `value[x] only Coding`, so a CodeableConcept here is off-profile.
        guard case .coding(let coding)? = recordingMethods.first?.value else {
            Issue.record("the recording method must be a Coding")
            return
        }
        #expect(coding.code?.value?.string == "manual-entry")
        #expect(coding.system == Canonicals.recordingMethodCodeSystem)
        #expect(observation.effective == .dateTime(ResponseFixture.authored), "the response's authored instant is the effective time")
        #expect(observation.derivedFrom?.count == 1, "an extracted Observation derives from its response")
    }
}


// MARK: Fixtures

extension HeartRiskExtractionTests {
    /// The Stanford fasting glucose answer: asked in mg/dL, under the linkId that extracts.
    private static var stanfordGlucose: [QuestionnaireResponseItem] {
        [ResponseFixture.item(glucoseLinkID, answer: answer(95, code: "mg/dL", unit: "mg/dL"))]
    }

    private static func code(of observation: Observation) -> String? {
        observation.code.coding?.first?.code?.value?.string
    }

    private static func code(of component: ObservationComponent) -> String? {
        component.code.coding?.first?.code?.value?.string
    }

    private static func quantity(of component: ObservationComponent?) -> (value: Decimal?, code: String?) {
        guard case .quantity(let quantity)? = component?.value else {
            return (nil, nil)
        }
        return (quantity.value?.value?.decimal, quantity.code?.value?.string)
    }

    private static func answer(_ value: Decimal, code: String, unit: String) -> QuestionnaireResponseItemAnswer {
        QuestionnaireResponseItemAnswer(value: .quantity(Quantity(
            code: code.asFHIRStringPrimitive(),
            system: "http://unitsofmeasure.org",
            unit: unit.asFHIRStringPrimitive(),
            value: FHIRPrimitive(FHIRDecimal(value))
        )))
    }

    /// A completed response in the instrument's base language, answering exactly the marked items and
    /// mirroring the instrument's hierarchy, with the writer context Grove requires of every response it exports.
    private static func response(
        for questionnaire: ModelsR4.Questionnaire,
        systolic: Bool = true,
        diastolic: Bool = true,
        glucose: [QuestionnaireResponseItem] = stanfordGlucose
    ) throws -> ModelsR4.QuestionnaireResponse {
        var pressureItems: [QuestionnaireResponseItem] = []
        if systolic {
            pressureItems.append(ResponseFixture.item(systolicLinkID, answer: answer(118, code: "mm[Hg]", unit: "mmHg")))
        }
        if diastolic {
            pressureItems.append(ResponseFixture.item(diastolicLinkID, answer: answer(76, code: "mm[Hg]", unit: "mmHg")))
        }
        let pressurePanel = pressureItems.isEmpty ? [] : [ResponseFixture.item(bloodPressurePanelLinkID, children: pressureItems)]
        var response = try ResponseFixture.completed(
            questionnaire,
            in: try #require(questionnaire.language),
            identifier: "heart-risk-extraction-contract",
            items: [
                ResponseFixture.item("heart-risk", children: pressurePanel + glucose)
            ]
        )
        response.apply(writerContext: try QuestionnaireWriterContext(
            applicationIdentifier: try BusinessIdentifier(
                system: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-application",
                value: "edu.stanford.myheartcounts"
            ),
            applicationName: "My Heart Counts",
            applicationVersion: "1.0.0"
        ))
        return response
    }

    #if canImport(FHIRPathParser)
    /// The value the hidden glucose item's `calculatedExpression` yields for `response`, bound as SDC binds it:
    /// `%resource` and the starting focus are the whole response.
    private static func calculatedGlucose(
        in questionnaire: ModelsR4.Questionnaire,
        from response: ModelsR4.QuestionnaireResponse
    ) throws -> Decimal {
        let group = try #require(questionnaire.item?.first { $0.linkId.value?.string == "heart-risk" })
        let item = try #require(group.item?.first { $0.linkId.value?.string == glucoseLinkID })
        let calculated = try #require(item.extension?.first { $0.url.value?.url.absoluteString == calculatedExpressionURL })
        guard case .expression(let expression)? = calculated.value,
              let fhirPath = expression.expression?.value?.string else {
            Issue.record("the hidden glucose item must carry its calculatedExpression as an Expression")
            return 0
        }
        let node = try FHIRPathNode.encoding(response)
        let result = try FHIRPathExpression.evaluate(
            expression: fhirPath,
            context: FHIRPathEvaluationContext(
                focus: [.object(node)],
                constants: ["resource": [.object(node)]],
                clock: FHIRPathClock(instant: .now, timeZone: .gmt)
            )
        )
        guard result.count == 1, case .decimal(let value)? = result.first else {
            Issue.record("the glucose expression must yield one decimal, got \(result)")
            return 0
        }
        return value
    }
    #endif

    /// The one-record Bundle Grove exports for `record`.
    private static func exchangeGraph(of record: QuestionnaireFHIRExporter.Record) async throws -> ExchangeGraph {
        var patient = ModelsR4.Patient()
        patient.id = ResponseFixture.participantID.asFHIRStringPrimitive()
        let keyID = "mhc-contract-test"
        let epoch = KeyEpoch(1)
        let producer = try ExchangeProducer(
            identityScope: try OpaqueIdentityScope(
                systems: try DeploymentIdentifierSystems.derived(
                    root: "https://myheartcounts.stanford.edu/fhir",
                    keyID: keyID,
                    epoch: epoch
                ),
                keyID: keyID,
                epoch: epoch,
                key: SymmetricKey(data: Data(repeating: 0x2A, count: 32))
            ),
            subject: .bundled(
                try BusinessIdentifier(
                    system: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-participant",
                    value: "participant-001"
                ),
                patient
            ),
            application: try ApplicationDevice(
                name: "My Heart Counts",
                bundleIdentifier: "edu.stanford.myheartcounts",
                version: "1.0.0"
            ),
            host: try HostDevice(operatingSystemVersion: "26.0", productType: "iPhone17,1")
        )
        let exporter = QuestionnaireFHIRExporter(
            producer: producer,
            repositoryScope: try BusinessIdentifier(system: "urn:uuid:1f5c58aa-6ec6-4e79-a682-829a9debd3f5", value: "default")
        )
        var exports: [QuestionnaireFHIRExporter.Export] = []
        let instant = Date(timeIntervalSince1970: 1_787_931_125)
        try await exporter.export([record], at: instant) { exports.append($0) }
        #expect(exports.count == 1)
        if case .refused(let error)? = exports.first?.outcome {
            throw error
        }
        var packer = ExchangeBundlePacker(kind: .active)
        #expect(try packer.insert(try #require(exports.first?.record)) == .inserted)
        return try packer.bundle(packedAt: instant)
    }
}
