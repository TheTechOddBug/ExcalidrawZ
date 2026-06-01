//
//  LockedContentAIGuard.swift
//  ExcalidrawZ
//
//  Created by Codex
//

import CoreData
import Foundation
import LLMCore

enum LockedContentAIError: LocalizedError {
    case lockedFile

    static let message = "This file is locked. AI cannot access locked file content, even while the file is temporarily unlocked for you."

    var errorDescription: String? {
        switch self {
            case .lockedFile:
                return Self.message
        }
    }
}

enum LockedContentAIGuard {
    static var lockedToolResult: ToolResult {
        .text(LockedContentAIError.message)
    }

    static func withProtectedContentAccessDenied<T>(
        operation: () async throws -> T
    ) async rethrows -> T {
        try await LockedContentReadPolicy.withProtectedContentBlocked(
            message: LockedContentAIError.message,
            operation: operation
        )
    }

    static func lockedToolResultIfNeeded(
        input: String,
        context: (any ChatInvocationContext)?
    ) async throws -> ToolResult? {
        if let currentFileID = (context as? ExcalidrawChatInvocationContext)?.currentFileID,
           !(try await canToolAccess(fileID: currentFileID)) {
            return lockedToolResult
        }

        if let fileID = fileIDFromToolInput(input),
           !(try await canToolAccess(fileID: fileID)) {
            return lockedToolResult
        }

        return nil
    }

    @MainActor
    static func ensureAIReadable(activeFile: FileState.ActiveFile?) async throws {
        guard case .file(let file) = activeFile else { return }
        try await ensureAIReadable(fileObjectID: file.objectID)
    }

    static func ensureAIReadable(fileID: UUID?) async throws {
        guard let fileID else { return }
        guard let fileObjectID = try await fileObjectID(for: fileID) else { return }
        try await ensureAIReadable(fileObjectID: fileObjectID)
    }

    static func ensureAIReadable(fileObjectID: NSManagedObjectID?) async throws {
        guard let fileObjectID else { return }
        guard try await isAIReadable(fileObjectID: fileObjectID) else {
            throw LockedContentAIError.lockedFile
        }
    }

    static func ensureToolCanAccess(fileID: UUID?) async throws {
        do {
            try await ensureAIReadable(fileID: fileID)
        } catch let error as LockedContentAIError {
            throw ToolError.executionFailed(error.localizedDescription)
        }
    }

    static func canToolAccess(fileID: UUID?) async throws -> Bool {
        guard let fileID else { return true }
        guard let fileObjectID = try await fileObjectID(for: fileID) else { return true }
        return try await isAIReadable(fileObjectID: fileObjectID)
    }

    static func canToolAccess(fileObjectID: NSManagedObjectID?) async throws -> Bool {
        guard let fileObjectID else { return true }
        return try await isAIReadable(fileObjectID: fileObjectID)
    }

    static func ensureToolCanAccess(fileObjectID: NSManagedObjectID?) async throws {
        do {
            try await ensureAIReadable(fileObjectID: fileObjectID)
        } catch let error as LockedContentAIError {
            throw ToolError.executionFailed(error.localizedDescription)
        }
    }

    static func isAIReadable(fileObjectID: NSManagedObjectID) async throws -> Bool {
        let isProtected = try await PersistenceController.shared.fileRepository
            .isFileContentProtected(fileObjectID: fileObjectID)
        return !isProtected
    }

    private static func fileObjectID(for fileID: UUID) async throws -> NSManagedObjectID? {
        let context = PersistenceController.shared.newTaskContext()
        return try await context.perform {
            let fetchRequest = NSFetchRequest<File>(entityName: "File")
            fetchRequest.predicate = NSPredicate(format: "id == %@", fileID as CVarArg)
            fetchRequest.fetchLimit = 1
            return try context.fetch(fetchRequest).first?.objectID
        }
    }

    private static func fileIDFromToolInput(_ input: String) -> UUID? {
        guard let data = input.data(using: .utf8),
              let probe = try? JSONDecoder().decode(FileIDProbe.self, from: data),
              let rawFileID = probe.fileID
        else {
            return nil
        }
        return UUID(uuidString: rawFileID)
    }

    private struct FileIDProbe: Decodable {
        let fileID: String?

        enum CodingKeys: String, CodingKey {
            case fileID = "fileID"
            case snakeFileID = "file_id"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fileID = try container.decodeIfPresent(String.self, forKey: .snakeFileID)
                ?? container.decodeIfPresent(String.self, forKey: .fileID)
        }
    }
}
