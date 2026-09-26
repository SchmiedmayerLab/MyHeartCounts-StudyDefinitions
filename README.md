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
- `MHCStudyDefinitionExporter` implements `export(_:to:as:)` to write a study bundle for a selected `StudyVariant` to the file system;
- `MHCStudyDefinitionExporterCLI` is a CLI tool that exports and validates study bundles.

Note that the package does not make the actual study definition available as an SPM package; this is intentional.
Instead, the package only implements the code that exports the study bundle, in a format the MHC app can then download from a server and consume.

## Study variants

The exporter produces separate Stanford and Imperial bundles. The CLI defaults to Stanford; select Imperial explicitly:

```sh
swift run MHCStudyDefinitionExporterCLI export --variant stanford .
swift run MHCStudyDefinitionExporterCLI export --variant imperial .
swift run MHCStudyDefinitionExporterCLI validate
```

Stanford exports use the `mhcStudyBundle` filename; Imperial exports use `mhcStudyBundle-imperial`. The `validate` command checks both variants.

CI exports both variants and uploads them to the selected development/staging bucket, or to the US bucket for production. UK production publishing remains disabled.

Both variants share components and schedules. Their definitions require participants to be at least 18 and from the US (Stanford) or UK (Imperial).

Resource filenames follow `<filename>[~variant]+<locale>.<ext>`, where `~variant` is optional. For example:

```text
Consent~stanford+en-US.md
Consent~stanford+es-US.md
Consent~imperial+en-GB.md
Welcome+en-US.md
```

Each resource, identified by its category, base filename, and extension, must have either entirely shared versions or entirely variant-specific versions. An export includes all localizations of shared resources, or only those tagged with its selected variant. Variant tags are removed in the exported bundle: `Consent~imperial+en-GB.md` becomes `Consent+en-GB.md`. The app continues to resolve resources using their usual filenames and localizations.

## UK consent for internal testing

The Imperial consent, `Consent~imperial+en-GB.md`, remains a clearly labelled placeholder for testing onboarding and signatures. It uses the existing consent response identifiers and must be replaced with an approved document before public UK enrollment. The app controls access to the test variant; exported bundles do not distinguish TestFlight from App Store builds.

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
