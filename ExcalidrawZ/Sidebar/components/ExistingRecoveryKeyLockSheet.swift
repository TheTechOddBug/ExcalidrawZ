//
//  ExistingRecoveryKeyLockSheet.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/05/28.
//

import SwiftUI

struct ExistingRecoveryKeyLockSheet: View {
    let request: LockedFileAccessRequest
    var onComplete: (() -> Void)?

    var body: some View {
        RecoveryKeyInputSheet(
            title: "Use Existing Recovery Key",
            subtitle: request.fileName,
            message: "Enter the Recovery Key that unlocks your existing locked files. This file will use the same key.",
            primaryButtonTitle: "Lock File",
            headerLayout: .compact
        ) { recoveryKey in
            let unlockedCount = try await PersistenceController.shared.fileRepository
                .unlockLockedFiles(recoveryKey: recoveryKey, includeTrash: true)
            let didValidateBackupRecoveryKey: Bool
#if canImport(AppKit)
            if unlockedCount == 0 {
                didValidateBackupRecoveryKey = await canUnlockEncryptedBackupExcalidrawFile(with: recoveryKey)
            } else {
                didValidateBackupRecoveryKey = false
            }
#else
            didValidateBackupRecoveryKey = false
#endif
            guard unlockedCount > 0 || didValidateBackupRecoveryKey else {
                throw EncryptedContentError.decryptionFailed
            }
            try await PersistenceController.shared.fileRepository.lockFileContent(
                fileObjectID: request.fileObjectID,
                recoveryKey: recoveryKey
            )
            onComplete?()
        }
    }
}
