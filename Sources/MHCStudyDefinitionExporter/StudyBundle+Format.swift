//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2026 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import GroveStudyDefinition


extension StudyBundle {
    public enum Format: String, Codable, CaseIterable, Sendable {
        /// A zstd-compressed tar archive, readable on every platform. The default.
        case zstd
        /// The uncompressed bundle directory.
        case package
        /// An Apple Archive, readable only on Apple platforms.
        @available(*, deprecated, message: "Use the cross-platform 'zstd' format instead.")
        case archive
        
        // Manual so the deprecated Apple Archive case neither breaks the synthesis nor
        // appears in the CLI's format suggestions.
        public static var allCases: [Format] {
            [.zstd, .package]
        }
    }
}
