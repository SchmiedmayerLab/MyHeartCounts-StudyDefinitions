//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// MHC Study Variant
public enum StudyVariant: String, CaseIterable, Hashable, Codable, Sendable {
    /// The Stanford study variant
    case stanford
    /// The Imperial study variant
    case imperial
}
