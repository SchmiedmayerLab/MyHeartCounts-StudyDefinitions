//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation
import GroveFHIRContract
import ModelsR4
import Testing


/// Grove QuestionnaireResponses written out by hand.
///
/// Grove's own response type is macOS-only, so building them here keeps the suites that use them on the Linux leg.
enum ResponseFixture {
    static let participantID = "MHCContractParticipant"
    static let authored: FHIRPrimitive<DateTime> = "2026-08-28T08:32:00-07:00"

    /// A completed, electronically captured response to the exact version of `questionnaire`, rendered in `language`.
    static func completed(
        _ questionnaire: ModelsR4.Questionnaire,
        in language: FHIRPrimitive<FHIRString>,
        identifier: String,
        items: [QuestionnaireResponseItem]
    ) throws -> ModelsR4.QuestionnaireResponse {
        let url = try #require(questionnaire.url?.value?.url.absoluteString)
        let version = try #require(questionnaire.version?.value?.string)
        let participant = Reference(reference: "Patient/\(participantID)".asFHIRStringPrimitive())
        return QuestionnaireResponse(
            author: participant,
            authored: authored,
            extension: [
                Extension(
                    url: "http://hl7.org/fhir/StructureDefinition/questionnaireresponse-completionMode",
                    value: .codeableConcept(CodeableConcept(coding: [
                        Coding(
                            code: "ELECTRONIC".asFHIRStringPrimitive(),
                            display: "electronic data".asFHIRStringPrimitive(),
                            system: "http://terminology.hl7.org/CodeSystem/v3-ParticipationMode"
                        )
                    ]))
                )
            ],
            identifier: Identifier(
                system: "https://myheartcounts.stanford.edu/fhir/NamingSystem/questionnaire-response",
                value: identifier.asFHIRStringPrimitive()
            ),
            item: items,
            language: language,
            meta: Meta(profile: [Profile.groveQuestionnaireResponse]),
            questionnaire: FHIRPrimitive(Canonical(stringLiteral: "\(url)|\(version)")),
            status: FHIRPrimitive(.completed),
            subject: participant
        )
    }

    static func item(
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
}
