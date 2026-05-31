//
//  LockedContentUnlockSession.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/05/27.
//

import Foundation

actor LockedContentUnlockSession {
    static let shared = LockedContentUnlockSession()

    private var unlockedKeys: [String: UnlockedContentKey] = [:]

    func unlock(
        _ encryptedData: Data,
        recoveryKey: RecoveryKey,
        expectedContentType: String,
        expectedContentID: String
    ) throws -> Data {
        let unlockedKey = try EncryptedContentService.unlockContentKey(
            encryptedData,
            recoveryKey: recoveryKey,
            expectedContentType: expectedContentType,
            expectedContentID: expectedContentID
        )
        unlockedKeys[cacheKey(contentType: unlockedKey.contentType, contentID: unlockedKey.contentID)] = unlockedKey
        return try EncryptedContentService.decrypt(
            encryptedData,
            unlockedKey: unlockedKey,
            expectedContentType: expectedContentType,
            expectedContentID: expectedContentID
        )
    }

    func decrypt(
        _ encryptedData: Data,
        expectedContentType: String,
        expectedContentID: String
    ) async throws -> Data {
        let unlockedKey = try await unlockedKey(
            encryptedData,
            expectedContentType: expectedContentType,
            expectedContentID: expectedContentID
        )
        return try EncryptedContentService.decrypt(
            encryptedData,
            unlockedKey: unlockedKey,
            expectedContentType: expectedContentType,
            expectedContentID: expectedContentID
        )
    }

    func resealPayload(
        _ plaintext: Data,
        existingEnvelopeData: Data,
        expectedContentType: String,
        expectedContentID: String
    ) async throws -> Data {
        let unlockedKey = try await unlockedKey(
            existingEnvelopeData,
            expectedContentType: expectedContentType,
            expectedContentID: expectedContentID
        )
        return try EncryptedContentService.resealPayload(
            plaintext,
            existingEnvelopeData: existingEnvelopeData,
            unlockedKey: unlockedKey,
            expectedContentType: expectedContentType,
            expectedContentID: expectedContentID
        )
    }

    func rewrapRecoveryKey(
        existingEnvelopeData: Data,
        newRecoveryKey: RecoveryKey,
        expectedContentType: String,
        expectedContentID: String
    ) async throws -> Data {
        let unlockedKey = try await unlockedKey(
            existingEnvelopeData,
            expectedContentType: expectedContentType,
            expectedContentID: expectedContentID
        )
        return try EncryptedContentService.rewrapRecoveryKey(
            existingEnvelopeData: existingEnvelopeData,
            unlockedKey: unlockedKey,
            newRecoveryKey: newRecoveryKey,
            expectedContentType: expectedContentType,
            expectedContentID: expectedContentID
        )
    }

    func isUnlocked(contentType: String, contentID: String) -> Bool {
        unlockedKeys[cacheKey(contentType: contentType, contentID: contentID)] != nil
    }

    func isUnlockedOrCanUnlock(
        _ encryptedData: Data,
        expectedContentType: String,
        expectedContentID: String
    ) async -> Bool {
        do {
            _ = try await unlockedKey(
                encryptedData,
                expectedContentType: expectedContentType,
                expectedContentID: expectedContentID
            )
            return true
        } catch {
            return false
        }
    }

    func forget(contentType: String, contentID: String) {
        unlockedKeys.removeValue(forKey: cacheKey(contentType: contentType, contentID: contentID))
    }

    func forgetAll() {
        unlockedKeys.removeAll()
    }

    private func unlockedKey(
        _ encryptedData: Data,
        expectedContentType: String,
        expectedContentID: String
    ) async throws -> UnlockedContentKey {
        let key = cacheKey(contentType: expectedContentType, contentID: expectedContentID)
        if let unlockedKey = unlockedKeys[key] {
            return unlockedKey
        }

        guard let recoveryKey = await RecoveryKeyVault.shared.currentRecoveryKey() else {
            throw EncryptedContentError.contentLocked(contentType: expectedContentType, contentID: expectedContentID)
        }

        let unlockedKey = try EncryptedContentService.unlockContentKey(
            encryptedData,
            recoveryKey: recoveryKey,
            expectedContentType: expectedContentType,
            expectedContentID: expectedContentID
        )
        unlockedKeys[key] = unlockedKey
        return unlockedKey
    }

    private func cacheKey(contentType: String, contentID: String) -> String {
        "\(contentType)|\(contentID)"
    }
}
