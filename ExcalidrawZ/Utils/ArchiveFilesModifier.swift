//
//  ArchiveFilesModifier.swift
//  ExcalidrawZ
//
//  Created by Claude on 2025/11/29.
//

import SwiftUI
import ChocofordUI
import CoreData
import UniformTypeIdentifiers
import Logging

private let archiveFilesLogger = Logger(label: "ArchiveFiles")

/// Information about a file that failed to archive
struct FailedFileInfo: Identifiable {
    let id = UUID()
    let fileName: String
    let error: String
}

/// Result of archiving operation
struct ArchiveResult {
    let url: URL
    let failedFiles: [FailedFileInfo]
}

/// ViewModifier for archiving all files with fileExporter
/// This is a SwiftUI-native implementation of archiveAllFiles() from Utils.swift
/// that supports both macOS and iOS using fileExporter
struct ArchiveFilesModifier: ViewModifier {
    @Binding var isPresented: Bool
    let context: NSManagedObjectContext
    let includeLockedFiles: Bool
    @Binding var recoveryKey: RecoveryKey?
    let onComplete: (Result<ArchiveResult, Error>) -> Void
    var onCancellation: () -> Void

    private let logger = Logger(label: "ArchiveFilesModifier")
    
    @State private var archiveDocument: ArchiveFolderDocument?
    @State private var isExporting = false
    @State private var failedFiles: [FailedFileInfo] = []
    
    func body(content: Content) -> some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            content
                .fileExporter(
                    isPresented: $isExporting,
                    document: archiveDocument,
                    contentTypes: [.folder],
                    defaultFilename: "ExcalidrawZ exported at \(Date.now.formatted(date: .abbreviated, time: .shortened))"
                ) { result in
                    handleExportResult(result)
                } onCancellation: {
                    onCancellation()
                }
                .watch(value: isPresented) { newValue in
                    if newValue {
                        Task {
                            await prepareArchive()
                        }
                    }
                }
        } else {
            content
                .fileExporter(
                    isPresented: $isExporting,
                    document: archiveDocument,
                    contentType: .folder,
                    defaultFilename: "ExcalidrawZ exported at \(Date.now.formatted(date: .abbreviated, time: .shortened))"
                ) { result in
                    handleExportResult(result)
                }
                .watch(value: isPresented) { newValue in
                    if newValue {
                        Task {
                            await prepareArchive()
                        }
                    }
                }
        }
    }
    
    private func prepareArchive() async {
        let folderName = sanitizedFilename(
            "ExcalidrawZ exported at \(Date.now.formatted(date: .abbreviated, time: .shortened))",
            fallback: "ExcalidrawZ export"
        )
        let archiveResult = await archiveAllCloudFilesWithErrorCollection(
            folderName: folderName,
            context: context,
            includeLockedFiles: includeLockedFiles,
            recoveryKey: recoveryKey
        )

        await MainActor.run {
            self.failedFiles = archiveResult.failedFiles
            self.archiveDocument = archiveResult.document
            self.isExporting = true
            self.isPresented = false
        }
    }
    
    /// Internal implementation of archiveAllCloudFiles that collects failed files instead of throwing
    private func archiveAllCloudFilesWithErrorCollection(
        folderName: String,
        context: NSManagedObjectContext,
        includeLockedFiles: Bool,
        recoveryKey: RecoveryKey?
    ) async -> (document: ArchiveFolderDocument, failedFiles: [FailedFileInfo]) {
        var failedFiles: [FailedFileInfo] = []
        let rootWrapper = FileWrapper(directoryWithFileWrappers: [:])
        rootWrapper.preferredFilename = folderName
        
        do {
            let allFiles: [PersistenceController.ExcalidrawGroup: [File]] = try PersistenceController.shared.listAllFiles(context: context)
            
            for groupFiles in allFiles {
                let group = groupFiles.key
                let files = groupFiles.value
                let folderPathComponents = group.ancestors.map { sanitizedFilename($0.name ?? "Untitled") }
                    + [sanitizedFilename(group.group.name ?? "Untitled")]
                let groupWrapper = archiveFolderWrapper(
                    for: folderPathComponents,
                    in: rootWrapper
                )
                
                for file in files {
                    do {
                        guard let archiveData = try await archivedFileData(
                            for: file,
                            context: context,
                            includeLockedFiles: includeLockedFiles,
                            recoveryKey: recoveryKey
                        ) else {
                            continue
                        }
                        var index = 1
                        var filename = sanitizedFilename(
                            archiveData.name
                        )
                        var retryCount = 0
                        var fileWrapperName = "\(filename).excalidraw"
                        while groupWrapper.fileWrappers?[fileWrapperName] != nil, retryCount < 100 {
                            if filename.hasSuffix(" (\(index))") {
                                filename = filename.replacingOccurrences(of: " (\(index))", with: "")
                                index += 1
                            }
                            filename = "\(filename) (\(index))"
                            fileWrapperName = "\(filename).excalidraw"
                            retryCount += 1
                        }
                        if groupWrapper.fileWrappers?[fileWrapperName] != nil {
                            let fileName = file.name ?? "Untitled"
                            failedFiles.append(FailedFileInfo(
                                fileName: fileName,
                                error: "Duplicate filename after retries: \(fileWrapperName)"
                            ))
                            logger.error("Duplicate filename after retries: \(fileWrapperName)")
                            continue
                        }
                        let fileWrapper = FileWrapper(regularFileWithContents: archiveData.content)
                        fileWrapper.preferredFilename = fileWrapperName
                        groupWrapper.addFileWrapper(fileWrapper)
                    } catch {
                        // Record failed file instead of throwing
                        let fileName = file.name ?? "Untitled"
                        failedFiles.append(FailedFileInfo(
                            fileName: fileName,
                            error: error.localizedDescription
                        ))
                        logger.error("Failed to archive file '\(fileName)': \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            // If we fail to list files, record a general error
            failedFiles.append(FailedFileInfo(
                fileName: "Archive",
                error: "Failed to list files: \(error.localizedDescription)"
            ))
            logger.error("Failed to list files for archive: \(error.localizedDescription)")
        }
        
        return (ArchiveFolderDocument(rootWrapper: rootWrapper), failedFiles)
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
            case .success(let url):
                // Create ArchiveResult with failed files info
                let archiveResult = ArchiveResult(url: url, failedFiles: failedFiles)
                onComplete(.success(archiveResult))
                
            case .failure(let error):
                logger.error("Archive export failed: \(error.localizedDescription)")
                onComplete(.failure(error))
        }
        
        // Reset state
        archiveDocument = nil
        failedFiles = []
    }
}

/// Document wrapper for folder export
struct ArchiveFolderDocument: FileDocument, @unchecked Sendable {
    static var readableContentTypes: [UTType] { [.folder] }
    
    let rootWrapper: FileWrapper
    
    init(rootWrapper: FileWrapper) {
        self.rootWrapper = rootWrapper
    }
    
    init(configuration: ReadConfiguration) throws {
        // Not used for export-only document
        throw CocoaError(.fileReadUnsupportedScheme)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return rootWrapper
    }
}

private func archiveFolderWrapper(
    for pathComponents: [String],
    in root: FileWrapper
) -> FileWrapper {
    var currentWrapper = root
    for component in pathComponents {
        if let existing = currentWrapper.fileWrappers?[component] {
            currentWrapper = existing
            continue
        }
        let newWrapper = FileWrapper(directoryWithFileWrappers: [:])
        newWrapper.preferredFilename = component
        currentWrapper.addFileWrapper(newWrapper)
        currentWrapper = newWrapper
    }
    return currentWrapper
}

private func sanitizedFilename(_ name: String, fallback: String = "Untitled") -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let replaced = trimmed
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: ":", with: "_")
        .replacingOccurrences(of: "\0", with: "_")
    return replaced.isEmpty ? fallback : replaced
}

extension View {
    /// Present a file exporter to archive all files
    /// - Parameters:
    ///   - isPresented: Binding to control presentation
    ///   - context: NSManagedObjectContext for fetching files
    ///   - onComplete: Completion handler with result (includes failed files info)
    func archiveFilesExporter(
        isPresented: Binding<Bool>,
        context: NSManagedObjectContext,
        includeLockedFiles: Bool = false,
        recoveryKey: Binding<RecoveryKey?> = .constant(nil),
        onComplete: @escaping (Result<ArchiveResult, Error>) -> Void,
        onCancellation: @escaping () -> Void = {}
    ) -> some View {
        modifier(
            ArchiveFilesModifier(
                isPresented: isPresented,
                context: context,
                includeLockedFiles: includeLockedFiles,
                recoveryKey: recoveryKey,
                onComplete: onComplete,
                onCancellation: onCancellation
            )
        )
    }
}

#if canImport(AppKit)

@MainActor
func archiveAllFiles(context: NSManagedObjectContext, completionHandler: (() -> Void)? = nil) async throws {
    let panel = ExcalidrawOpenPanel.exportPanel
    if panel.runModal() == .OK {
        if let url = panel.url {
            let filemanager = FileManager.default
            do {
                let exportURL = url.appendingPathComponent("ExcalidrawZ exported at \(Date.now.formatted(date: .abbreviated, time: .shortened))", conformingTo: .directory)
                try filemanager.createDirectory(at: exportURL, withIntermediateDirectories: false)
                try await archiveAllCloudFiles(to: exportURL, context: context)
                completionHandler?()
            } catch {
                archiveFilesLogger.error("Failed to archive all files: \(error)")
                throw error
            }
        } else {
            throw AppError.fileError(.invalidURL)
        }
    }
}
#endif

func archiveAllCloudFiles(
    to url: URL,
    context: NSManagedObjectContext,
    includeLockedFiles: Bool = false,
    recoveryKey: RecoveryKey? = nil
) async throws {
    let filemanager = FileManager.default
    let allFiles:  [PersistenceController.ExcalidrawGroup : [File]] = try PersistenceController.shared.listAllFiles(context: context)

    var errorDuringArchive: Error?

    for groupFiles in allFiles {
        let group = groupFiles.key
        let files = groupFiles.value
        var groupURL = url
        for ancestor in group.ancestors {
            groupURL = groupURL.appendingPathComponent(ancestor.name ?? "Untitled", conformingTo: .directory)
        }
        groupURL = groupURL.appendingPathComponent(group.group.name ?? "Untitled", conformingTo: .directory)
        if !filemanager.fileExists(at: groupURL) {
            try filemanager.createDirectory(at: groupURL, withIntermediateDirectories: true)
        }

        for file in files {
            do {
                guard let archiveData = try await archivedFileData(
                    for: file,
                    context: context,
                    includeLockedFiles: includeLockedFiles,
                    recoveryKey: recoveryKey
                ) else {
                    continue
                }
                var index = 1
                var filename = archiveData.name
                var fileURL: URL = groupURL.appendingPathComponent(filename, conformingTo: .fileURL).appendingPathExtension("excalidraw")
                var retryCount = 0
                while filemanager.fileExists(at: fileURL), retryCount < 100 {
                    if filename.hasSuffix(" (\(index))") {
                        filename = filename.replacingOccurrences(of: " (\(index))", with: "")
                        index += 1
                    }
                    filename = "\(filename) (\(index))"
                    fileURL = fileURL
                        .deletingLastPathComponent()
                        .appendingPathComponent(filename, conformingTo: .excalidrawFile)
                    retryCount += 1
                }
                let filePath: String = fileURL.filePath
                if !filemanager.createFile(atPath: filePath, contents: archiveData.content) {
                    archiveFilesLogger.error("Failed to export file to \(filePath)")
                }
            } catch {
                errorDuringArchive = error
            }
        }
    }

    if let errorDuringArchive {
        throw errorDuringArchive
    }
}

private struct ArchivedFileData: Sendable {
    let name: String
    let content: Data
}

private struct ArchiveFileSnapshot: Sendable {
    let name: String?
    let filePath: String?
    let fileID: UUID?
    let fallbackContent: Data?
}

private func archivedFileData(
    for file: File,
    context: NSManagedObjectContext,
    includeLockedFiles: Bool = true,
    recoveryKey: RecoveryKey? = nil
) async throws -> ArchivedFileData? {
    let snapshot = try await archiveFileSnapshot(for: file)
    let fallbackName = snapshot.name ?? String(localizable: .newFileNamePlaceholder)

    if let encryptedContent = try await storedEncryptedContentIfPresent(from: snapshot) {
        guard includeLockedFiles else { return nil }
        let plaintext: Data
        if let recoveryKey {
            let unlockedKey = try EncryptedContentService.unlockContentKey(
                encryptedContent,
                recoveryKey: recoveryKey,
                expectedContentType: "file",
                expectedContentID: snapshot.fileID?.uuidString
            )
            plaintext = try EncryptedContentService.decrypt(
                encryptedContent,
                unlockedKey: unlockedKey,
                expectedContentType: "file",
                expectedContentID: snapshot.fileID?.uuidString
            )
        } else if let fileID = snapshot.fileID {
            plaintext = try await LockedContentUnlockSession.shared.decrypt(
                encryptedContent,
                expectedContentType: "file",
                expectedContentID: fileID.uuidString
            )
        } else {
            throw LockedContentSystemUnlockError.noSavedRecoveryKey
        }

        var excalidrawFile = try ExcalidrawFile(
            data: plaintext,
            id: snapshot.fileID?.uuidString
        )
        excalidrawFile.name = fallbackName
        try await excalidrawFile.syncFiles(context: context)

        return ArchivedFileData(
            name: excalidrawFile.name ?? fallbackName,
            content: excalidrawFile.content ?? Data()
        )
    }

    var excalidrawFile = try await ExcalidrawFile(from: file)
    try await excalidrawFile.syncFiles(context: context)

    return ArchivedFileData(
        name: excalidrawFile.name ?? file.name ?? String(localizable: .newFileNamePlaceholder),
        content: excalidrawFile.content ?? Data()
    )
}

func backupAllCloudFiles(
    to url: URL,
    context: NSManagedObjectContext,
    includeLockedFiles: Bool = true
) async throws {
    let filemanager = FileManager.default
    let allFiles: [PersistenceController.ExcalidrawGroup : [File]] = try PersistenceController.shared.listAllFiles(context: context)

    var errorDuringBackup: Error?

    for groupFiles in allFiles {
        let group = groupFiles.key
        let files = groupFiles.value
        var groupURL = url
        for ancestor in group.ancestors {
            groupURL = groupURL.appendingPathComponent(ancestor.name ?? "Untitled", conformingTo: .directory)
        }
        groupURL = groupURL.appendingPathComponent(group.group.name ?? "Untitled", conformingTo: .directory)
        if !filemanager.fileExists(at: groupURL) {
            try filemanager.createDirectory(at: groupURL, withIntermediateDirectories: true)
        }

        for file in files {
            do {
                guard let archiveData = try await archivedFileData(
                    for: file,
                    context: context,
                    includeLockedFiles: includeLockedFiles
                ) else {
                    continue
                }
                var index = 1
                var filename = archiveData.name
                var fileURL: URL = groupURL.appendingPathComponent(filename, conformingTo: .fileURL).appendingPathExtension("excalidraw")
                var retryCount = 0
                while filemanager.fileExists(at: fileURL), retryCount < 100 {
                    if filename.hasSuffix(" (\(index))") {
                        filename = filename.replacingOccurrences(of: " (\(index))", with: "")
                        index += 1
                    }
                    filename = "\(filename) (\(index))"
                    fileURL = fileURL
                        .deletingLastPathComponent()
                        .appendingPathComponent(filename, conformingTo: .excalidrawFile)
                    retryCount += 1
                }
                let filePath: String = fileURL.filePath
                let backupContent = try EncryptedBackupService.encrypt(archiveData.content)
                if !filemanager.createFile(atPath: filePath, contents: backupContent) {
                    archiveFilesLogger.error("Failed to write backup file to \(filePath)")
                }
            } catch let error as EncryptedContentError {
                if error.isContentLocked {
                    archiveFilesLogger.debug("Skipping locked file during backup")
                    continue
                }
                errorDuringBackup = error
            } catch {
                errorDuringBackup = error
            }
        }
    }

    if let errorDuringBackup {
        throw errorDuringBackup
    }
}

private func archiveFileSnapshot(for file: File) async throws -> ArchiveFileSnapshot {
    guard let context = file.managedObjectContext else {
        struct MissingContextError: LocalizedError {
            var errorDescription: String? { "File object has no managed object context." }
        }
        throw MissingContextError()
    }

    let objectID = file.objectID
    return try await context.perform {
        guard let file = context.object(with: objectID) as? File else {
            throw AppError.fileError(.notFound)
        }

        return ArchiveFileSnapshot(
            name: file.name,
            filePath: file.filePath,
            fileID: file.id,
            fallbackContent: file.content
        )
    }
}

private func storedEncryptedContentIfPresent(from snapshot: ArchiveFileSnapshot) async throws -> Data? {
    if let filePath = snapshot.filePath, let fileID = snapshot.fileID {
        do {
            let content = try await FileStorageManager.shared.loadContent(
                relativePath: filePath,
                fileID: fileID.uuidString
            )
            return EncryptedContentService.isEncryptedEnvelope(content) ? content : nil
        } catch {
            if let fallbackContent = snapshot.fallbackContent,
               EncryptedContentService.isEncryptedEnvelope(fallbackContent) {
                return fallbackContent
            }

            if snapshot.fallbackContent != nil {
                return nil
            }

            throw error
        }
    }

    guard let fallbackContent = snapshot.fallbackContent else {
        return nil
    }
    return EncryptedContentService.isEncryptedEnvelope(fallbackContent) ? fallbackContent : nil
}
