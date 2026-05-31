//
//  RecoveryKeyVault.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/05/27.
//

actor RecoveryKeyVault {
    static let shared = RecoveryKeyVault()

    private var activeRecoveryKey: RecoveryKey?
    private var retainedRecoveryKeyForLocking: RecoveryKey?

    func currentRecoveryKey() -> RecoveryKey? {
        activeRecoveryKey
    }

    func currentRecoveryKeyForLocking() -> RecoveryKey? {
        retainedRecoveryKeyForLocking ?? activeRecoveryKey
    }

    func generateAndActivate() throws -> RecoveryKey {
        let recoveryKey = try RecoveryKeyService.generate()
        activate(recoveryKey)
        return recoveryKey
    }

    func activate(_ recoveryKey: RecoveryKey) {
        activeRecoveryKey = recoveryKey
        retainedRecoveryKeyForLocking = recoveryKey
    }

    func forget() {
        activeRecoveryKey = nil
    }

    func forgetAll() {
        activeRecoveryKey = nil
        retainedRecoveryKeyForLocking = nil
    }
}
