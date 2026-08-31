<!--

This source file is part of the My Heart Counts Study Definitions open-source project

SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT

-->

# MyHeartCounts-StudyDefinitions

[![Build and Test](https://github.com/SchmiedmayerLab/MyHeartCounts-StudyDefinitions/actions/workflows/verify-study-bundle.yml/badge.svg)](https://github.com/SchmiedmayerLab/MyHeartCounts-StudyDefinitions/actions/workflows/verify-study-bundle.yml)
[![Deployment](https://github.com/SchmiedmayerLab/MyHeartCounts-StudyDefinitions/actions/workflows/publish-study-definition.yml/badge.svg)](https://github.com/SchmiedmayerLab/MyHeartCounts-StudyDefinitions/actions/workflows/publish-study-definition.yml)
[![REUSE status](https://api.reuse.software/badge/github.com/SchmiedmayerLab/MyHeartCounts-StudyDefinitions)](https://api.reuse.software/info/github.com/SchmiedmayerLab/MyHeartCounts-StudyDefinitions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)

## Overview
Study Definitions and supporting code for the [My Heart Counts](https://github.com/SchmiedmayerLab/MyHeartCounts-iOS) iOS application.

This package consists of 3 (three) targets:
- `MHCStudyDefinition` contains supporting code that is shared between the MHC app and the study definition, e.g., static properties defining custom active tasks;
- `MHCStudyDefinitionExporter` implements an `export(to:)` function that writes a study bundle archive to the file system;
- `MHCStudyDefinitionExporterCLI` is a CLI tool that calls `export(to:)` to export a study bundle archive.

Note that the package does not make the actual study definition available as an SPM package; this is intentional.
Instead, the package only implements the code that exports the study bundle, in a format the MHC app can then download from a server and consume.

## Questionnaire Conventions

The instruments live under `Sources/MHCStudyDefinitionExporter/Resources/questionnaire/` as `en-US`/`es-US` pairs.
The pair must stay structurally identical: only the display text and the locale metadata differ, and the contract suite compares the two projections to enforce it.
Any change to instrument content bumps `studyRevision` in `Study.swift` together with the pinned expectation in the tests.
A change that alters how a response is interpreted — item meaning, datatype, answer choices, required state, a constraint, the hierarchy, or an extraction marking — also increments that instrument's `Questionnaire.version`, because `url|version` names one immutable definition.

`linkId`s are persisted identifiers.
Submitted `QuestionnaireResponse`s reference them, so a `linkId` is renamed only with a migration, never for tidiness.
Question items use UUIDs; structural anchors that other layers reason about — the HeartRisk wrapper group and its blood-pressure panel — use readable kebab-case names instead.
HeartRisk keeps exactly one top-level group because Grove renders every top-level group as its own section, so flattening the wrapper would split the instrument across three pages.

### Marking Measurements for Extraction

A marked item is extracted into a profiled Observation, following [Grove's measurement extraction guide](https://grovealliance.org/fhir/questionnaire/measurements.html).
Marking one takes an `sdc-questionnaire-observationExtract` extension, a single coded `item.code` naming the measurement, and a UCUM `questionnaire-unitOption` for quantities.
A panel is a group carrying the panel LOINC and `valueBoolean: true`; each of its question children carries its own component LOINC and `valueCode: "component"`.
When the target profile fixes a category — the blood-pressure panel's `vital-signs`, for instance — the item must also carry `sdc-questionnaire-observation-extract-category`, or the extracted Observation does not conform.
Measurements whose profile fixes no category, such as blood glucose, deliberately declare none.

An unmarked quantity item is intentionally not extracted; in HeartRisk that covers the second blood-pressure reading, HbA1C, and the cholesterol values, which are collected for the study's own scoring rather than for the measurement exchange.

## Testing and Study Defitition Integrity Validation
The `swift test` command may be used to run a dry-run export of the study definition, which will fail if the integrity verification step performed as part of the export finds any issues with the study definition (e.g., invalid references, invalid questionnaire definitions, etc).

The repo's CI setup performs this check on every push, to ensure that only valid study definitions can be merged.

## Contributing

Contributions to this project are welcome. Please make sure to read the [contribution guidelines](https://github.com/SchmiedmayerLab/.github/blob/main/CONTRIBUTING.md) and the [contributor covenant code of conduct](https://github.com/SchmiedmayerLab/.github/blob/main/CODE_OF_CONDUCT.md) first. You can find a list of contributors in the [CONTRIBUTORS.md](CONTRIBUTORS.md) file.

## License

This project is licensed under the MIT License. See [LICENSE.md](LICENSE.md) for more information.

## Citation

If you use this software, please cite it using the metadata in [CITATION.cff](CITATION.cff), which GitHub surfaces through the [*Cite this repository*](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-citation-files) button.

## Our Research

For more information, visit the [Schmiedmayer Lab GitHub organization](https://github.com/SchmiedmayerLab).

![Schmiedmayer Lab](https://raw.githubusercontent.com/SchmiedmayerLab/.github/main/assets/footer-light.png#gh-light-mode-only)
![Schmiedmayer Lab](https://raw.githubusercontent.com/SchmiedmayerLab/.github/main/assets/footer-dark.png#gh-dark-mode-only)
