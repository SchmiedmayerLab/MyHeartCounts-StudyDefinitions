//
// This source file is part of the My Heart Counts Study Definitions open-source project
//
// SPDX-FileCopyrightText: 2025 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import AppleArchive
import Foundation
import System


extension FileManager {
    struct ArchiveOperationError: Error {
        let message: String
        let underlyingError: (any Error)?
        
        init(_ message: String, underlyingError: (any Error)? = nil) {
            self.message = message
            self.underlyingError = underlyingError
        }
    }
    
    func archiveDirectory(at srcUrl: URL, to dstUrl: URL) throws(ArchiveOperationError) {
        let srcPath = FilePath(srcUrl.path)
        let dstPath = FilePath(dstUrl.path)
        
        guard let writeFileStream = ArchiveByteStream.fileStream(
            path: dstPath,
            mode: .writeOnly,
            options: [.create],
            permissions: FilePermissions(rawValue: 0o644)
        ) else {
            throw ArchiveOperationError("Unable to create writeFileStream")
        }
        defer {
            try? writeFileStream.close()
        }
        
        guard let compressionStream = ArchiveByteStream.compressionStream(
            using: .lzfse,
            writingTo: writeFileStream
        ) else {
            throw ArchiveOperationError("Unable to create compressionStream")
        }
        defer {
            try? compressionStream.close()
        }
        
        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressionStream) else {
            throw ArchiveOperationError("Unable to create encodeStream")
        }
        defer {
            try? encodeStream.close()
        }
        
        guard let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM") else {
            throw ArchiveOperationError("Unable to create keySet")
        }
        
        do {
            try encodeStream.writeDirectoryContents(
                archiveFrom: srcPath,
                keySet: keySet
            )
        } catch {
            throw ArchiveOperationError("Unable to write directory contents to file", underlyingError: error)
        }
    }
    
    
    /// Unarchives a directory archive that was created with `-lk_archiveDirectory`.
    /// - returns: the URL of the unarchived directory.
    /// - Note: this function unarchives to a temporary directory.
    func unarchiveDirectory(at archiveUrl: URL, to dstUrl: URL) throws(ArchiveOperationError) {
        // See: https://developer.apple.com/documentation/accelerate/decompressing_and_extracting_an_archived_directory
        guard archiveUrl.pathExtension == "aar" else {
            throw ArchiveOperationError("Invalid path extension ('\(archiveUrl.pathExtension)')")
        }
        guard let dstFilePath = FilePath(dstUrl) else {
            throw ArchiveOperationError("Unable to create dstFilePath")
        }
        
        guard let archiveFilePath = FilePath(archiveUrl) else {
            throw ArchiveOperationError("Unable to create FilePath for archive file")
        }
        
        guard let readFileStream = ArchiveByteStream.fileStream(
            path: archiveFilePath,
            mode: .readOnly,
            options: [],
            permissions: FilePermissions(rawValue: 0o644)
        ) else {
            throw ArchiveOperationError("Unable to create readFileStream")
        }
        defer {
            try? readFileStream.close()
        }
        
        guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: readFileStream) else {
            throw ArchiveOperationError("Unable to create decompressStream")
        }
        defer {
            try? decompressStream.close()
        }
        
        guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressStream) else {
            throw ArchiveOperationError("Unable to create decodeStream")
        }
        defer {
            try? decodeStream.close()
        }
        
        guard let extractStream = ArchiveStream.extractStream(
            extractingTo: dstFilePath,
            flags: [.ignoreOperationNotPermitted]
        ) else {
            throw ArchiveOperationError("Unable to create extractStream")
        }
        defer {
            try? extractStream.close()
        }
        
        do {
            _ = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
        } catch {
            throw ArchiveOperationError("Unarchiving failed", underlyingError: error)
        }
    }
}
