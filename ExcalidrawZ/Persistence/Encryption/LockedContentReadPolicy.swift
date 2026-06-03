//
//  LockedContentReadPolicy.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/01.
//

import Foundation

struct LockedContentReadBlockedError: LocalizedError, Equatable {
    let message: String

    var errorDescription: String? {
        message
    }
}

enum LockedContentReadPolicy {
    @TaskLocal
    private static var protectedContentBlockMessage: String?

    static func withProtectedContentBlocked<T>(
        message: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await $protectedContentBlockMessage.withValue(message) {
            try await operation()
        }
    }

    static func ensureProtectedContentAccessAllowed() throws {
        if let protectedContentBlockMessage {
            throw LockedContentReadBlockedError(message: protectedContentBlockMessage)
        }
    }
}
