//
//  LockedContentUnlockSupport.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/05/27.
//

import Foundation
import LocalAuthentication
import Security

enum LockedContentErrorPresenter {
    static func message(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

enum LockedContentSecurityDelay {
    private static let failedAttemptMinimumDuration: TimeInterval = 1

    static func waitBeforeShowingFailure(startedAt: Date) async {
        let remaining = failedAttemptMinimumDuration - Date().timeIntervalSince(startedAt)
        guard remaining > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }
}

enum LockedContentSymbols {
    static let lockShield = "lock.shield"
    static let removeLock = "shield.slash"

    static var keyShield: String {
        if #available(macOS 26.0, iOS 26.0, *) {
            return "key.shield"
        } else {
            return "key"
        }
    }
}

struct LockedContentSystemUnlockAvailability: Equatable {
    let isAvailable: Bool
    let buttonTitle: String
    let systemImage: String

    static var unavailable: Self {
        .init(
            isAvailable: false,
            buttonTitle: "Unlock with Mac Password",
            systemImage: LockedContentSymbols.keyShield
        )
    }
}

enum LockedContentSystemUnlockError: LocalizedError, Equatable {
    case unavailable
    case noSavedRecoveryKey
    case canceled
    case authenticationFailed
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
            case .unavailable:
                "System authentication is not available on this device."
            case .noSavedRecoveryKey:
                "No saved Recovery Key is available on this device."
            case .canceled:
                "System authentication was canceled."
            case .authenticationFailed:
                "System authentication failed."
            case .keychainError:
                "The saved Recovery Key could not be read from Keychain."
        }
    }

    var recoverySuggestion: String? {
        switch self {
            case .unavailable, .noSavedRecoveryKey, .authenticationFailed, .keychainError:
                "Enter your Recovery Key to unlock this content."
            case .canceled:
                nil
        }
    }
}

enum LockedContentSystemUnlockReason {
    static let lockFile = "lock this file"
    static let unlockFile = "unlock this file"
    static let manageLockedContent = "manage locked content"
    static let archiveLockedFiles = "export locked files"
    static let exportBackup = "export this backup"
    static let previewBackupFile = "preview this backup file"
}

enum LockedContentSavedRecoveryKeyState: Equatable {
    case available
    case missing
}

enum LockedContentSystemUnlockStore {
    private static let service = "\(Bundle.main.bundleIdentifier ?? "com.chocoford.ExcalidrawZ").locked-content"
    private static let account = "UnifiedRecoveryKey"
    private static let savedRecoveryKeyMarkerKey = "LockedContentSystemUnlockStore.hasSavedRecoveryKey"
    private static let loadCoordinator = RecoveryKeyLoadCoordinator()

    private actor RecoveryKeyLoadCoordinator {
        private var inFlight: Task<RecoveryKey, Error>?

        func load(reason: String) async throws -> RecoveryKey {
            if let inFlight {
                return try await inFlight.value
            }

            let task = Task {
                try await LockedContentSystemUnlockStore.loadRecoveryKeyDirect(reason: reason)
            }
            inFlight = task
            defer { inFlight = nil }
            return try await task.value
        }
    }

    static func availability() -> LockedContentSystemUnlockAvailability {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable
        }

        switch context.biometryType {
            case .touchID:
                return .init(
                    isAvailable: true,
                    buttonTitle: "Unlock with Touch ID or Mac Password",
                    systemImage: "touchid"
                )
            case .faceID:
                return .init(
                    isAvailable: true,
                    buttonTitle: "Unlock with Face ID or Passcode",
                    systemImage: "faceid"
                )
            case .opticID:
                return .init(
                    isAvailable: true,
                    buttonTitle: "Unlock with Optic ID or Passcode",
                    systemImage: "opticid"
                )
            case .none:
#if os(macOS)
                return .init(
                    isAvailable: true,
                    buttonTitle: "Unlock with Mac Password",
                    systemImage: LockedContentSymbols.keyShield
                )
#else
                return .init(
                    isAvailable: true,
                    buttonTitle: "Unlock with Device Passcode",
                    systemImage: LockedContentSymbols.keyShield
                )
#endif
            @unknown default:
                return .init(
                    isAvailable: true,
                    buttonTitle: "Unlock with System Authentication",
                    systemImage: LockedContentSymbols.keyShield
                )
        }
    }

    static func save(_ recoveryKey: RecoveryKey) throws {
        var accessControlError: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &accessControlError
        ) else {
            throw LockedContentSystemUnlockError.unavailable
        }

        let query = baseQuery()
        let deleteStatus = SecItemDelete(query as CFDictionary)
        var updatedAttributes: [String: Any] = [:]
        updatedAttributes[kSecValueData as String] = recoveryKey.storageData
        updatedAttributes[kSecAttrAccessControl as String] = accessControl

        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            let updateStatus = SecItemUpdate(query as CFDictionary, updatedAttributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw keychainError(for: updateStatus)
            }
            UserDefaults.standard.set(true, forKey: savedRecoveryKeyMarkerKey)
            return
        }

        var attributes = query
        attributes.merge(updatedAttributes) { _, newValue in newValue }
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(query as CFDictionary, updatedAttributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw keychainError(for: updateStatus)
            }
        } else if status != errSecSuccess {
            throw keychainError(for: status)
        }
        UserDefaults.standard.set(true, forKey: savedRecoveryKeyMarkerKey)
    }

    static func deleteSavedRecoveryKey() {
        SecItemDelete(baseQuery() as CFDictionary)
        UserDefaults.standard.set(false, forKey: savedRecoveryKeyMarkerKey)
    }

    static func hasSavedRecoveryKey() -> Bool {
        (try? savedRecoveryKeyState()) == .available
    }

    static func savedRecoveryKeyState() throws -> LockedContentSavedRecoveryKeyState {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
            case errSecSuccess:
                UserDefaults.standard.set(true, forKey: savedRecoveryKeyMarkerKey)
                return .available
            case errSecItemNotFound:
                return .missing
            case errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
                UserDefaults.standard.set(true, forKey: savedRecoveryKeyMarkerKey)
                return .available
            default:
                throw LockedContentSystemUnlockError.keychainError(status)
        }
    }

    static func shouldPromptAutomatically() -> Bool {
        UserDefaults.standard.bool(forKey: savedRecoveryKeyMarkerKey)
    }

    static func noteMissingSavedRecoveryKey() {
        UserDefaults.standard.set(false, forKey: savedRecoveryKeyMarkerKey)
    }

    static func loadRecoveryKey(reason: String) async throws -> RecoveryKey {
        try await loadCoordinator.load(reason: reason)
    }

    private static func loadRecoveryKeyDirect(reason: String) async throws -> RecoveryKey {
        let context = LAContext()
        context.localizedReason = reason
        context.touchIDAuthenticationAllowableReuseDuration = 10

        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            throw LockedContentSystemUnlockError.unavailable
        }

        try await authenticate(context: context, reason: reason)
        return try loadRecoveryKeySync(context: context)
    }

    private static func authenticate(context: LAContext, reason: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: authenticationError(for: error))
                }
            }
        }
    }

    private static func loadRecoveryKeySync(context: LAContext) throws -> RecoveryKey {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            let error = keychainError(for: status)
            if error == .noSavedRecoveryKey {
                noteMissingSavedRecoveryKey()
            }
            throw error
        }
        guard let data = item as? Data else {
            throw LockedContentSystemUnlockError.noSavedRecoveryKey
        }
        let recoveryKey = try RecoveryKey(storageData: data)
        UserDefaults.standard.set(true, forKey: savedRecoveryKeyMarkerKey)
        try? save(recoveryKey)
        return recoveryKey
    }

    private static func authenticationError(for error: Error?) -> LockedContentSystemUnlockError {
        guard let nsError = error as NSError?,
              nsError.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: nsError.code) else {
            return .authenticationFailed
        }

        switch code {
            case .userCancel, .systemCancel, .appCancel, .userFallback:
                return .canceled
            case .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled, .notInteractive:
                return .unavailable
            case .authenticationFailed, .biometryLockout:
                return .authenticationFailed
            default:
                return .authenticationFailed
        }
    }

    private static func keychainError(for status: OSStatus) -> LockedContentSystemUnlockError {
        switch status {
            case errSecItemNotFound:
                .noSavedRecoveryKey
            case errSecUserCanceled:
                .canceled
            case errSecAuthFailed:
                .authenticationFailed
            default:
                .keychainError(status)
        }
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
