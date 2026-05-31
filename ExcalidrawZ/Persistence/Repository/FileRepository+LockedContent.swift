//
//  FileRepository+LockedContent.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/5/31.
//

import Foundation
import CoreData
import Logging

enum FileContentLockState: Equatable, Hashable, Sendable {
    case plaintext
    case locked
    case temporarilyUnlocked
}

struct LockedFileSummary: Identifiable {
    var id: String { fileID.uuidString }
    let fileObjectID: NSManagedObjectID
    let fileID: UUID
    let name: String
    let updatedAt: Date?
    let lockState: FileContentLockState
}

private struct RawFileContentSnapshot {
    let objectID: NSManagedObjectID
    let fileID: UUID
    let filePath: String?
    let content: Data?
    let name: String?
    let updatedAt: Date?
}

private let fileRepositoryLockedContentLogger = Logger(label: "FileRepository.LockedContent")

extension FileRepository {
    // MARK: - Locked File Content

    func lockFileContent(
        fileObjectID: NSManagedObjectID,
        recoveryKey: RecoveryKey
    ) async throws {
        let snapshot = try await rawFileContentSnapshot(fileObjectID: fileObjectID)
        let rawContent = try await loadRawFileContent(from: snapshot)
        let contentID = snapshot.fileID.uuidString

        if EncryptedContentService.isEncryptedEnvelope(rawContent) {
            _ = try await LockedContentUnlockSession.shared.unlock(
                rawContent,
                recoveryKey: recoveryKey,
                expectedContentType: "file",
                expectedContentID: contentID
            )
            await RecoveryKeyVault.shared.activate(recoveryKey)
            rememberRecoveryKeyForSystemUnlock(recoveryKey)
            try await PersistenceController.shared.checkpointRepository.encryptCheckpoints(
                for: fileObjectID,
                recoveryKey: recoveryKey
            )
            return
        }

        let encryptedContent = try EncryptedContentService.encryptAndVerifyRecovery(
            rawContent,
            contentType: "file",
            contentID: contentID,
            recoveryKey: recoveryKey
        )

        try await saveFileContentToStorage(fileObjectID: fileObjectID, content: encryptedContent)
        _ = try await LockedContentUnlockSession.shared.unlock(
            encryptedContent,
            recoveryKey: recoveryKey,
            expectedContentType: "file",
            expectedContentID: contentID
        )
        await RecoveryKeyVault.shared.activate(recoveryKey)
        rememberRecoveryKeyForSystemUnlock(recoveryKey)
        try await PersistenceController.shared.checkpointRepository.encryptCheckpoints(
            for: fileObjectID,
            recoveryKey: recoveryKey
        )
    }

    @discardableResult
    func unlockFileContent(
        fileObjectID: NSManagedObjectID,
        recoveryKey: RecoveryKey
    ) async throws -> Data {
        let snapshot = try await rawFileContentSnapshot(fileObjectID: fileObjectID)
        let rawContent = try await loadRawFileContent(from: snapshot)
        let contentID = snapshot.fileID.uuidString

        guard EncryptedContentService.isEncryptedEnvelope(rawContent) else {
            return rawContent
        }

        let plaintext = try await LockedContentUnlockSession.shared.unlock(
            rawContent,
            recoveryKey: recoveryKey,
            expectedContentType: "file",
            expectedContentID: contentID
        )
        await RecoveryKeyVault.shared.activate(recoveryKey)
        rememberRecoveryKeyForSystemUnlock(recoveryKey)
        return plaintext
    }

    func forgetUnlockedFileContent(fileObjectID: NSManagedObjectID) async throws {
        let snapshot = try await rawFileContentSnapshot(fileObjectID: fileObjectID)
        await LockedContentUnlockSession.shared.forget(
            contentType: "file",
            contentID: snapshot.fileID.uuidString
        )
    }

    func isFileContentEncrypted(fileObjectID: NSManagedObjectID) async throws -> Bool {
        try await isFileContentProtected(fileObjectID: fileObjectID)
    }

    func isFileContentProtected(fileObjectID: NSManagedObjectID) async throws -> Bool {
        let snapshot = try await rawFileContentSnapshot(fileObjectID: fileObjectID)
        if let filePath = snapshot.filePath {
            do {
                let rawContent = try await FileStorageManager.shared.loadContent(
                    relativePath: filePath,
                    fileID: snapshot.fileID.uuidString
                )
                return EncryptedContentService.isEncryptedEnvelope(rawContent)
            } catch {
                fileRepositoryLockedContentLogger.warning("Failed to inspect file content protection state: \(error.localizedDescription). Treating file as protected.")
                return true
            }
        }

        guard let content = snapshot.content else {
            throw AppError.fileError(.contentNotAvailable(filename: snapshot.name ?? String(localizable: .generalUnknown)))
        }
        return EncryptedContentService.isEncryptedEnvelope(content)
    }

    func hasLockedFiles(includeTrash: Bool = false) async throws -> Bool {
        let lockedFiles = try await listLockedFiles(includeTrash: includeTrash)
        return !lockedFiles.isEmpty
    }

    func fileContentLockState(fileObjectID: NSManagedObjectID) async throws -> FileContentLockState {
        let snapshot = try await rawFileContentSnapshot(fileObjectID: fileObjectID)
        let rawContent = try await loadRawFileContent(from: snapshot)
        guard EncryptedContentService.isEncryptedEnvelope(rawContent) else {
            return .plaintext
        }

        let isUnlocked = await LockedContentUnlockSession.shared.isUnlockedOrCanUnlock(
            rawContent,
            expectedContentType: "file",
            expectedContentID: snapshot.fileID.uuidString
        )
        return isUnlocked ? .temporarilyUnlocked : .locked
    }

    func removeFileLock(fileObjectID: NSManagedObjectID) async throws {
        let snapshot = try await rawFileContentSnapshot(fileObjectID: fileObjectID)
        let rawContent = try await loadRawFileContent(from: snapshot)
        let contentID = snapshot.fileID.uuidString

        guard EncryptedContentService.isEncryptedEnvelope(rawContent) else {
            return
        }

        let plaintextContent = try await LockedContentUnlockSession.shared.decrypt(
            rawContent,
            expectedContentType: "file",
            expectedContentID: contentID
        )

        try await savePlainFileContentToStorage(
            fileObjectID: fileObjectID,
            content: plaintextContent
        )
        try await PersistenceController.shared.checkpointRepository.removeCheckpointLocks(
            for: fileObjectID
        )

        await LockedContentUnlockSession.shared.forget(
            contentType: "file",
            contentID: contentID
        )
        let stillHasLockedFiles = try await hasLockedFiles()
        if !stillHasLockedFiles {
            await RecoveryKeyVault.shared.forget()
        }
    }

    func unlockLockedFiles(
        recoveryKey: RecoveryKey,
        includeTrash: Bool = false
    ) async throws -> Int {
        let lockedFiles = try await listLockedFiles(includeTrash: includeTrash)
        var unlockedCount = 0

        for (index, file) in lockedFiles.enumerated() {
            try await lockedFileBatchCheckpoint(index)
            do {
                try await unlockFileContent(
                    fileObjectID: file.fileObjectID,
                    recoveryKey: recoveryKey
                )
                unlockedCount += 1
            } catch {
                continue
            }
        }

        if unlockedCount > 0 {
            await RecoveryKeyVault.shared.activate(recoveryKey)
        }
        return unlockedCount
    }

    func resetUnlockedFilesRecoveryKey(
        newRecoveryKey: RecoveryKey,
        includeTrash: Bool = false
    ) async throws -> Int {
        let snapshots = try await rawFileContentSnapshots(includeTrash: includeTrash)
        let previousRecoveryKey = await RecoveryKeyVault.shared.currentRecoveryKey()
        var resetCount = 0

        for (index, snapshot) in snapshots.enumerated() {
            try await lockedFileBatchCheckpoint(index)
            let contentID = snapshot.fileID.uuidString
            do {
                let rawContent = try await loadRawFileContent(from: snapshot)
                guard EncryptedContentService.isEncryptedEnvelope(rawContent) else {
                    continue
                }
                let isUnlocked = await LockedContentUnlockSession.shared.isUnlockedOrCanUnlock(
                    rawContent,
                    expectedContentType: "file",
                    expectedContentID: contentID
                )
                guard isUnlocked else { continue }

                let rewrappedContent = try await LockedContentUnlockSession.shared.rewrapRecoveryKey(
                    existingEnvelopeData: rawContent,
                    newRecoveryKey: newRecoveryKey,
                    expectedContentType: "file",
                    expectedContentID: contentID
                )
                try await saveFileContentToStorage(
                    fileObjectID: snapshot.objectID,
                    content: rewrappedContent
                )
                try await PersistenceController.shared.checkpointRepository.rewrapCheckpointsRecoveryKey(
                    for: snapshot.objectID,
                    newRecoveryKey: newRecoveryKey
                )
                resetCount += 1
            } catch {
                fileRepositoryLockedContentLogger.warning("Failed to reset Recovery Key for locked file: \(error.localizedDescription)")
            }
        }

        if resetCount > 0 {
#if canImport(AppKit)
            if let previousRecoveryKey {
                let backupResult = await rewrapEncryptedBackupFilesRecoveryKey(
                    oldRecoveryKey: previousRecoveryKey,
                    newRecoveryKey: newRecoveryKey
                )
                if backupResult.rewrappedCount > 0 {
                    fileRepositoryLockedContentLogger.info("Reset Recovery Key for \(backupResult.rewrappedCount) encrypted backup files")
                }
                if backupResult.failedCount > 0 {
                    fileRepositoryLockedContentLogger.warning("Failed to reset Recovery Key for \(backupResult.failedCount) encrypted backup files")
                }
            } else {
                fileRepositoryLockedContentLogger.warning("Skipped encrypted backup Recovery Key reset because the previous Recovery Key is not available in memory")
            }
#endif
            await RecoveryKeyVault.shared.activate(newRecoveryKey)
            rememberRecoveryKeyForSystemUnlock(newRecoveryKey)
        }
        return resetCount
    }

    func deleteLockedFilesPermanently(includeTrash: Bool = true) async throws -> Int {
        let lockedFiles = try await listLockedFiles(includeTrash: includeTrash)

        for (index, file) in lockedFiles.enumerated() {
            try await lockedFileBatchCheckpoint(index)
            try await delete(
                fileObjectID: file.fileObjectID,
                forcePermanently: true,
                save: true
            )
        }

        await RecoveryKeyVault.shared.forgetAll()
        await LockedContentUnlockSession.shared.forgetAll()
        return lockedFiles.count
    }

    func listLockedFiles(includeTrash: Bool = false) async throws -> [LockedFileSummary] {
        let snapshots = try await rawFileContentSnapshots(includeTrash: includeTrash)
        var lockedFiles: [LockedFileSummary] = []

        for (index, snapshot) in snapshots.enumerated() {
            try await lockedFileBatchCheckpoint(index)
            do {
                let rawContent = try await loadRawFileContent(from: snapshot)
                guard EncryptedContentService.isEncryptedEnvelope(rawContent) else {
                    continue
                }

                let isUnlocked = await LockedContentUnlockSession.shared.isUnlockedOrCanUnlock(
                    rawContent,
                    expectedContentType: "file",
                    expectedContentID: snapshot.fileID.uuidString
                )

                lockedFiles.append(
                    LockedFileSummary(
                        fileObjectID: snapshot.objectID,
                        fileID: snapshot.fileID,
                        name: snapshot.name ?? String(localizable: .generalUntitled),
                        updatedAt: snapshot.updatedAt,
                        lockState: isUnlocked ? .temporarilyUnlocked : .locked
                    )
                )
            } catch {
                fileRepositoryLockedContentLogger.warning("Failed to inspect locked file candidate: \(error.localizedDescription)")
            }
        }

        return lockedFiles.sorted {
            ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
        }
    }
}

private extension FileRepository {
    func savePlainFileContentToStorage(
        fileObjectID: NSManagedObjectID,
        content: Data
    ) async throws {
        let context = PersistenceController.shared.newTaskContext()

        let (fileID, updatedAt) = try await context.perform {
            guard let file = context.object(with: fileObjectID) as? File else {
                throw AppError.fileError(.notFound)
            }
            guard let fileID = file.id else {
                throw AppError.fileError(.contentNotAvailable(filename: file.name ?? String(localizable: .generalUnknown)))
            }
            return (fileID, file.updatedAt)
        }

        let relativePath = try await FileStorageManager.shared.saveContent(
            content,
            fileID: fileID.uuidString,
            type: .file,
            updatedAt: updatedAt
        )

        try await context.perform {
            guard let file = context.object(with: fileObjectID) as? File else { return }
            file.updateAfterSavingToStorage(filePath: relativePath)
            try context.save()
        }
        fileRepositoryLockedContentLogger.info("Removed file lock and saved plaintext content: \(relativePath)")
    }

    func rawFileContentSnapshot(fileObjectID: NSManagedObjectID) async throws -> RawFileContentSnapshot {
        let context = PersistenceController.shared.newTaskContext()
        return try await context.perform {
            guard let file = context.object(with: fileObjectID) as? File else {
                throw AppError.fileError(.notFound)
            }
            guard let fileID = file.id else {
                throw AppError.fileError(.contentNotAvailable(filename: file.name ?? String(localizable: .generalUnknown)))
            }
            return RawFileContentSnapshot(
                objectID: file.objectID,
                fileID: fileID,
                filePath: file.filePath,
                content: file.content,
                name: file.name,
                updatedAt: file.updatedAt
            )
        }
    }

    func rawFileContentSnapshots(includeTrash: Bool) async throws -> [RawFileContentSnapshot] {
        let context = PersistenceController.shared.newTaskContext()
        return try await context.perform {
            let fetchRequest = NSFetchRequest<File>(entityName: "File")
            if !includeTrash {
                fetchRequest.predicate = NSPredicate(format: "inTrash == NO")
            }
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]

            return try context.fetch(fetchRequest).compactMap { file in
                guard let fileID = file.id else { return nil }
                return RawFileContentSnapshot(
                    objectID: file.objectID,
                    fileID: fileID,
                    filePath: file.filePath,
                    content: file.content,
                    name: file.name,
                    updatedAt: file.updatedAt
                )
            }
        }
    }

    func loadRawFileContent(from snapshot: RawFileContentSnapshot) async throws -> Data {
        if let filePath = snapshot.filePath {
            do {
                return try await FileStorageManager.shared.loadContent(
                    relativePath: filePath,
                    fileID: snapshot.fileID.uuidString
                )
            } catch {
                fileRepositoryLockedContentLogger.warning("Failed to load file content from storage before lock/unlock: \(error.localizedDescription). Falling back to CoreData.")
            }
        }

        if let content = snapshot.content {
            return content
        }

        throw AppError.fileError(.contentNotAvailable(filename: snapshot.name ?? String(localizable: .generalUnknown)))
    }

    func lockedFileBatchCheckpoint(_ index: Int) async throws {
        try Task.checkCancellation()
        if index > 0, index.isMultiple(of: 10) {
            await Task.yield()
        }
    }

    func rememberRecoveryKeyForSystemUnlock(_ recoveryKey: RecoveryKey) {
        do {
            try LockedContentSystemUnlockStore.save(recoveryKey)
        } catch {
            if (try? LockedContentSystemUnlockStore.savedRecoveryKeyState()) != .available {
                LockedContentSystemUnlockStore.deleteSavedRecoveryKey()
            }
            fileRepositoryLockedContentLogger.warning("Failed to save locked content Recovery Key for system unlock: \(error.localizedDescription)")
        }
    }
}
