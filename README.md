<!--
                  
This source file is part of the My Heart Counts open source project

SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)

SPDX-License-Identifier: MIT
             
-->

# MyHeartCounts-StudyDefinitions
[![Publish Study Definition](https://github.com/SchmiedmayerLab/MyHeartCounts-StudyDefinitions/actions/workflows/publish-study-definition.yml/badge.svg)](https://github.com/SchmiedmayerLab/MyHeartCounts-StudyDefinitions/actions/workflows/publish-study-definition.yml)
[![Build and Test](https://github.com/SchmiedmayerLab/MyHeartCounts-StudyDefinitions/actions/workflows/verify-study-bundle.yml/badge.svg)](https://github.com/SchmiedmayerLab/MyHeartCounts-StudyDefinitions/actions/workflows/verify-study-bundle.yml)
[![DOI](https://zenodo.org/badge/573230182.svg)](https://zenodo.org/badge/latestdoi/573230182)


## Overview
Study Definitions and supporting code for the [My Heart Counts](https://github.com/SchmiedmayerLab/MyHeartCounts-iOS) iOS application.

This package consists of 3 (three) targets:
- `MHCStudyDefinition` contains supporting code that is shared between the MHC app and the study definition, e.g., static properties defining custom active tasks;
- `MHCStudyDefinitionExporter` implements an `export(to:)` function that writes a study bundle archive to the file system;
- `MHCStudyDefinitionExporterCLI` is a CLI tool that calls `export(to:)` to export a study bundle archive.

Note that the package does not make the actual study definition available as an SPM package; this is intentional.
Instead, the package only implements the code that exports the study bundle, in a format the MHC app can then download from a server and consume.

## Testing and Study Defitition Integrity Validation
The `swift test` command may be used to run a dry-run export of the study definition, which will fail if the integrity verification step performed as part of the export finds any issues with the study definition (e.g., invalid references, invalid questionnaire definitions, etc).

The repo's CI setup performs this check on every push, to ensure that only valid study definitions can be merged.

## License
This project is licensed under the MIT License. See [Licenses](https://github.com/SchmiedmayerLab/MyHeartCounts-StudyDefinitions/tree/main/LICENSES) for more information.


## Our Research

For more information, visit the [Schmiedmayer Lab GitHub organization](https://github.com/SchmiedmayerLab).

![Stanford and Stanford Medicine logos](https://raw.githubusercontent.com/SchmiedmayerLab/.github/main/assets/stanford-footer-light.png#gh-light-mode-only)
![Stanford and Stanford Medicine logos](https://raw.githubusercontent.com/SchmiedmayerLab/.github/main/assets/stanford-footer-dark.png#gh-dark-mode-only)