//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import GroveFHIRContract
import GroveQuestionnaireExtraction
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
    private static let observationCategorySystem = "http://terminology.hl7.org/CodeSystem/observation-category"

    @Test
    func heartRiskKeepsOneTopLevelGroup() throws {
        try StudyBundleFixture.withExportedStudyBundle { bundle in
            for (_, locale) in StudyBundleFixture.locales {
                let items = try #require(bundle.questionnaire(named: "HeartRisk", in: locale)).item ?? []
                // Grove renders every top-level group as its own section, so the wrapper keeps HeartRisk one page.
                #expect(items.count == 1, "HeartRisk must keep exactly one top-level group")
                #expect(items.first?.linkId.value?.string == "heart-risk")
                #expect(items.first?.type.value == .group)
            }
        }
    }


    @Test
    func markedMeasurementsProjectIntoConformingObservations() throws {
        try StudyBundleFixture.withExportedStudyBundle { bundle in
            let questionnaire = try #require(bundle.questionnaire(named: "HeartRisk", in: Locale(identifier: "en_US")))
            let graph = try QuestionnaireExchangeProjection.exchangeGraph(
                questionnaire: questionnaire,
                response: try Self.response(for: questionnaire),
                context: try Self.extractionContext()
            )
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
    }


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


    private func validateGlucose(_ observation: Observation) throws {
        #expect(observation.meta?.profile == [Profile.groveMobileBloodGlucoseUnspecifiedSpecimen])
        // The glucose profile fixes no category, so the instrument deliberately declares none.
        #expect(observation.category == nil)
        #expect(observation.component == nil)
        guard case .quantity(let quantity)? = observation.value else {
            Issue.record("the fasting glucose must extract as a Quantity")
            return
        }
        #expect(quantity.value?.value?.decimal == 95)
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
        #expect(observation.effective == .dateTime(Self.authored), "the response's authored instant is the effective time")
        #expect(observation.derivedFrom?.count == 1, "an extracted Observation derives from its response")
    }
}


// MARK: Fixtures

extension HeartRiskExtractionTests {
    private static let authored: FHIRPrimitive<DateTime> = "2026-08-28T08:32:00-07:00"
    private static let completionModeURL: FHIRPrimitive<FHIRURI> =
        "http://hl7.org/fhir/StructureDefinition/questionnaireresponse-completionMode"
    private static let participationModeSystem: FHIRPrimitive<FHIRURI> =
        "http://terminology.hl7.org/CodeSystem/v3-ParticipationMode"

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

    private static func item(
        _ linkID: String,
        answer: QuestionnaireResponseItemAnswer? = nil,
        children: [QuestionnaireResponseItem] = []
    ) -> QuestionnaireResponseItem {
        QuestionnaireResponseItem(
            answer: answer.map { [$0] },
            item: children.isEmpty ? nil : children,
            linkId: linkID.asFHIRStringPrimitive()
        )
    }

    /// A completed response answering exactly the marked items, mirroring the instrument's hierarchy.
    ///
    /// Written out here rather than converted from Grove's own response type, which is macOS-only and
    /// would take this suite off the Linux leg.
    private static func response(for questionnaire: ModelsR4.Questionnaire) throws -> ModelsR4.QuestionnaireResponse {
        let url = try #require(questionnaire.url?.value?.url.absoluteString)
        let version = try #require(questionnaire.version?.value?.string)
        let participant = Reference(reference: "Patient/MHCExtractionContractParticipant")
        return QuestionnaireResponse(
            author: participant,
            authored: authored,
            extension: [
                Extension(
                    url: completionModeURL,
                    value: .codeableConcept(CodeableConcept(coding: [
                        Coding(
                            code: "ELECTRONIC".asFHIRStringPrimitive(),
                            display: "electronic data".asFHIRStringPrimitive(),
                            system: participationModeSystem
                        )
                    ]))
                )
            ],
            identifier: Identifier(
                system: "https://myheartcounts.stanford.edu/fhir/NamingSystem/questionnaire-response",
                value: "heart-risk-extraction-contract".asFHIRStringPrimitive()
            ),
            item: [
                item("heart-risk", children: [
                    item(bloodPressurePanelLinkID, children: [
                        item(systolicLinkID, answer: answer(118, code: "mm[Hg]", unit: "mmHg")),
                        item(diastolicLinkID, answer: answer(76, code: "mm[Hg]", unit: "mmHg"))
                    ]),
                    item(glucoseLinkID, answer: answer(95, code: "mg/dL", unit: "mg/dL"))
                ])
            ],
            meta: Meta(profile: [Profile.groveQuestionnaireResponse]),
            questionnaire: FHIRPrimitive(Canonical(stringLiteral: "\(url)|\(version)")),
            status: FHIRPrimitive(.completed),
            subject: participant
        )
    }

    private static func extractionContext() throws -> QuestionnaireExtractionContext {
        var patient = ModelsR4.Patient()
        patient.id = "MHCExtractionContractParticipant"
        patient.identifier = [
            Identifier(
                system: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-participant",
                value: "participant-001".asFHIRStringPrimitive()
            )
        ]
        return QuestionnaireExtractionContext(
            patient: patient,
            eventIdentifier: try ExchangeEventIdentifier(
                system: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-event",
                producerInstance: try #require(UUID(uuidString: "6f9d1c4a-2b7e-4f18-9c33-5a1d0e7b2c48")),
                sequence: 1
            ),
            identityScope: try PseudonymousIdentityScope(
                systems: try identitySystems(),
                keyID: "mhc-contract-test",
                epoch: 1,
                key: Data(repeating: 0x2A, count: 32)
            ),
            repositoryScope: try BusinessIdentifier(
                system: "urn:uuid:1f5c58aa-6ec6-4e79-a682-829a9debd3f5",
                value: "default"
            ),
            entryNodeIdentifierSystem: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-entry-node",
            conversionInstant: Date(timeIntervalSince1970: 1_787_931_125),
            localWriter: try QuestionnaireWriterContext(
                applicationIdentifier: try BusinessIdentifier(
                    system: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-application",
                    value: "edu.stanford.myheartcounts"
                ),
                applicationName: "My Heart Counts",
                applicationVersion: "1.0.0"
            )
        )
    }

    private static func identitySystems() throws -> PseudonymousIdentitySystems {
        try PseudonymousIdentitySystems(
            sourceRecord: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-source-record",
            sourceOutput: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-source-output",
            writerRecord: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-writer-record",
            providerRecord: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-provider-record",
            providerOutput: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-provider-output",
            sourceArtifact: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-source-artifact",
            providerArtifact: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-provider-artifact",
            sourceContext: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-source-context",
            recordingDevice: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-recording-device",
            deviceSnapshot: "https://myheartcounts.stanford.edu/fhir/NamingSystem/test-device-snapshot"
        )
    }
}
