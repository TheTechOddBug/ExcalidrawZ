//
//  EncryptedContentEnvelopeTests.swift
//  ExcalidrawZTests
//
//  Created by Codex on 2026/05/27.
//

import XCTest
@testable import ExcalidrawZ

final class EncryptedContentEnvelopeTests: XCTestCase {
    func testRecoveryKeyGenerationRoundTripsFromDisplayString() throws {
        let recoveryKey = try RecoveryKeyService.generate()

        let parsed = try RecoveryKey(displayString: recoveryKey.displayString)

        XCTAssertEqual(parsed, recoveryKey)
        XCTAssertTrue(recoveryKey.displayString.hasPrefix("EDZ2-"))
    }

    func testRecoveryKeyParserAcceptsLowercaseAndWhitespace() throws {
        let recoveryKey = try RecoveryKeyService.generate()
        let noisyInput = recoveryKey.displayString
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")

        let parsed = try RecoveryKey(displayString: noisyInput)

        XCTAssertEqual(parsed, recoveryKey)
    }

    func testEncryptAndDecryptRoundTripWithRecoveryKey() throws {
        let recoveryKey = try RecoveryKeyService.generate()
        let plaintext = Data(#"{"type":"excalidraw","elements":[{"id":"secret-element"}]}"#.utf8)

        let encrypted = try EncryptedContentService.encryptAndVerifyRecovery(
            plaintext,
            contentType: "file",
            contentID: "file-1",
            recoveryKey: recoveryKey
        )
        let decrypted = try EncryptedContentService.decrypt(encrypted, recoveryKey: recoveryKey)

        XCTAssertEqual(decrypted, plaintext)
        XCTAssertTrue(EncryptedContentService.isEncryptedEnvelope(encrypted))
    }

    func testEncryptedEnvelopeIsSelfContainedAndDoesNotContainPlaintext() throws {
        let recoveryKey = try RecoveryKeyService.generate()
        let secret = "secret-text-that-should-not-appear"
        let plaintext = Data(#"{"text":"\#(secret)"}"#.utf8)

        let encrypted = try EncryptedContentService.encryptAndVerifyRecovery(
            plaintext,
            contentType: "file",
            contentID: "file-2",
            recoveryKey: recoveryKey
        )
        let envelope = try EncryptedContentService.decodeEnvelope(encrypted)
        let encodedText = String(data: encrypted, encoding: .utf8)

        XCTAssertEqual(envelope.magic, EncryptedContentEnvelope.magicValue)
        XCTAssertEqual(envelope.version, EncryptedContentEnvelope.currentVersion)
        XCTAssertEqual(envelope.contentType, "file")
        XCTAssertEqual(envelope.contentID, "file-2")
        XCTAssertEqual(envelope.algorithm, EncryptedContentEnvelope.contentAlgorithm)
        XCTAssertEqual(envelope.recoveryKeyDerivation.algorithm, EncryptedContentEnvelope.recoveryKDFAlgorithm)
        XCTAssertFalse(encodedText?.contains(secret) ?? true)
    }

    func testWrongRecoveryKeyCannotDecrypt() throws {
        let recoveryKey = try RecoveryKeyService.generate()
        let wrongRecoveryKey = try RecoveryKeyService.generate()
        let plaintext = Data("locked content".utf8)

        let encrypted = try EncryptedContentService.encryptAndVerifyRecovery(
            plaintext,
            contentType: "file",
            contentID: "file-3",
            recoveryKey: recoveryKey
        )

        XCTAssertThrowsError(
            try EncryptedContentService.decrypt(encrypted, recoveryKey: wrongRecoveryKey)
        )
    }

    func testTamperedCiphertextCannotDecrypt() throws {
        let recoveryKey = try RecoveryKeyService.generate()
        let plaintext = Data("locked content".utf8)
        let encrypted = try EncryptedContentService.encryptAndVerifyRecovery(
            plaintext,
            contentType: "file",
            contentID: "file-4",
            recoveryKey: recoveryKey
        )
        var envelope = try EncryptedContentService.decodeEnvelope(encrypted)
        var ciphertext = try XCTUnwrap(Data(base64Encoded: envelope.payload.ciphertext))
        ciphertext[0] ^= 0x01
        envelope.payload.ciphertext = ciphertext.base64EncodedString()

        let tampered = try JSONEncoder().encode(envelope)

        XCTAssertThrowsError(
            try EncryptedContentService.decrypt(tampered, recoveryKey: recoveryKey)
        )
    }

    func testUnlockSessionCachesFileKeyForSubsequentDecrypt() async throws {
        let session = LockedContentUnlockSession.shared
        await resetSharedEncryptionState()

        let recoveryKey = try RecoveryKeyService.generate()
        let plaintext = Data("session locked content".utf8)
        let encrypted = try EncryptedContentService.encryptAndVerifyRecovery(
            plaintext,
            contentType: "file",
            contentID: "file-session-1",
            recoveryKey: recoveryKey
        )

        do {
            _ = try await session.decrypt(
                encrypted,
                expectedContentType: "file",
                expectedContentID: "file-session-1"
            )
            XCTFail("Decrypting before unlock should fail")
        } catch EncryptedContentError.contentLocked(_, _) {
            // Expected.
        }

        let unlocked = try await session.unlock(
            encrypted,
            recoveryKey: recoveryKey,
            expectedContentType: "file",
            expectedContentID: "file-session-1"
        )
        let decryptedAfterUnlock = try await session.decrypt(
            encrypted,
            expectedContentType: "file",
            expectedContentID: "file-session-1"
        )

        XCTAssertEqual(unlocked, plaintext)
        XCTAssertEqual(decryptedAfterUnlock, plaintext)
        let isUnlocked = await session.isUnlocked(contentType: "file", contentID: "file-session-1")
        XCTAssertTrue(isUnlocked)
    }

    func testUnlockSessionResealsPayloadWithoutChangingRecoveryPath() async throws {
        let session = LockedContentUnlockSession.shared
        await resetSharedEncryptionState()

        let recoveryKey = try RecoveryKeyService.generate()
        let originalPlaintext = Data("original content".utf8)
        let updatedPlaintext = Data("updated locked content".utf8)
        let encrypted = try EncryptedContentService.encryptAndVerifyRecovery(
            originalPlaintext,
            contentType: "file",
            contentID: "file-session-2",
            recoveryKey: recoveryKey
        )

        _ = try await session.unlock(
            encrypted,
            recoveryKey: recoveryKey,
            expectedContentType: "file",
            expectedContentID: "file-session-2"
        )
        let resealed = try await session.resealPayload(
            updatedPlaintext,
            existingEnvelopeData: encrypted,
            expectedContentType: "file",
            expectedContentID: "file-session-2"
        )

        let sessionDecrypted = try await session.decrypt(
            resealed,
            expectedContentType: "file",
            expectedContentID: "file-session-2"
        )
        let recoveryDecrypted = try EncryptedContentService.decrypt(resealed, recoveryKey: recoveryKey)

        XCTAssertEqual(sessionDecrypted, updatedPlaintext)
        XCTAssertEqual(recoveryDecrypted, updatedPlaintext)
        XCTAssertFalse(String(data: resealed, encoding: .utf8)?.contains("updated locked content") ?? true)
    }

    func testRecoveryKeyVaultUnlocksMatchingContentForSession() async throws {
        let session = LockedContentUnlockSession.shared
        await resetSharedEncryptionState()

        let recoveryKey = try RecoveryKeyService.generate()
        let firstPlaintext = Data("first unified key content".utf8)
        let secondPlaintext = Data("second unified key content".utf8)
        let firstEncrypted = try EncryptedContentService.encryptAndVerifyRecovery(
            firstPlaintext,
            contentType: "file",
            contentID: "file-session-vault-1",
            recoveryKey: recoveryKey
        )
        let secondEncrypted = try EncryptedContentService.encryptAndVerifyRecovery(
            secondPlaintext,
            contentType: "file",
            contentID: "file-session-vault-2",
            recoveryKey: recoveryKey
        )

        let canUnlockBeforeVault = await session.isUnlockedOrCanUnlock(
            firstEncrypted,
            expectedContentType: "file",
            expectedContentID: "file-session-vault-1"
        )
        XCTAssertFalse(canUnlockBeforeVault)

        await RecoveryKeyVault.shared.activate(recoveryKey)

        let firstDecrypted = try await session.decrypt(
            firstEncrypted,
            expectedContentType: "file",
            expectedContentID: "file-session-vault-1"
        )
        let secondCanUnlock = await session.isUnlockedOrCanUnlock(
            secondEncrypted,
            expectedContentType: "file",
            expectedContentID: "file-session-vault-2"
        )
        let secondDecrypted = try await session.decrypt(
            secondEncrypted,
            expectedContentType: "file",
            expectedContentID: "file-session-vault-2"
        )

        XCTAssertEqual(firstDecrypted, firstPlaintext)
        XCTAssertTrue(secondCanUnlock)
        XCTAssertEqual(secondDecrypted, secondPlaintext)

        await resetSharedEncryptionState()
    }

    func testUnlockSessionRewrapsRecoveryKeyWithoutChangingPayload() async throws {
        let session = LockedContentUnlockSession.shared
        await resetSharedEncryptionState()

        let oldRecoveryKey = try RecoveryKeyService.generate()
        let newRecoveryKey = try RecoveryKeyService.generate()
        let plaintext = Data("recovery key reset content".utf8)
        let encrypted = try EncryptedContentService.encryptAndVerifyRecovery(
            plaintext,
            contentType: "file",
            contentID: "file-session-3",
            recoveryKey: oldRecoveryKey
        )
        let originalEnvelope = try EncryptedContentService.decodeEnvelope(encrypted)

        _ = try await session.unlock(
            encrypted,
            recoveryKey: oldRecoveryKey,
            expectedContentType: "file",
            expectedContentID: "file-session-3"
        )
        let rewrapped = try await session.rewrapRecoveryKey(
            existingEnvelopeData: encrypted,
            newRecoveryKey: newRecoveryKey,
            expectedContentType: "file",
            expectedContentID: "file-session-3"
        )
        let rewrappedEnvelope = try EncryptedContentService.decodeEnvelope(rewrapped)

        XCTAssertEqual(rewrappedEnvelope.payload, originalEnvelope.payload)
        XCTAssertNotEqual(
            rewrappedEnvelope.recoveryKeyDerivation.salt,
            originalEnvelope.recoveryKeyDerivation.salt
        )
        XCTAssertThrowsError(
            try EncryptedContentService.decrypt(rewrapped, recoveryKey: oldRecoveryKey)
        )
        XCTAssertEqual(
            try EncryptedContentService.decrypt(rewrapped, recoveryKey: newRecoveryKey),
            plaintext
        )
    }

    private func resetSharedEncryptionState() async {
        await LockedContentUnlockSession.shared.forgetAll()
        await RecoveryKeyVault.shared.forget()
    }
}
