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

    static let message = AIFileAccessStatusMessage.protectedContentAccessDenied

    var errorDescription: String? {
        switch self {
            case .lockedFile:
                return Self.message
        }
    }
}

enum AIFileAccessStatusMessage {
    static let noActiveFile = "No file is currently open in ExcalidrawZ."
    static let activeFileReadable = "A file is currently open in ExcalidrawZ, and AI file access is available for this request."

    static let protectedContentAccessDenied = """
    A file is currently open in ExcalidrawZ, but AI file access is disabled \
    or the file is protected. AI cannot access its content, canvas image, \
    selected elements, or file data. Protected file content remains unavailable \
    to AI even while it is temporarily unlocked for you. Canvas edits are \
    created on an AI proposal canvas for the user to Apply if they want them.
    """

    static let unreadableFilesOmitted = """
    Files that AI cannot access are omitted. Use file_access_status to check \
    the current file access state.
    """
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
        context: (any ChatInvocationContext)?,
        toolName: String
    ) async throws -> ToolResult? {
        let excalidrawContext = context as? ExcalidrawChatInvocationContext

        if requiresCurrentFileAccessCheck(toolName: toolName, context: excalidrawContext),
           let currentFileID = excalidrawContext?.currentFileID,
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

    @MainActor
    static func canAIRead(activeFile: FileState.ActiveFile?) async -> Bool {
        guard case .file(let file) = activeFile else { return true }
        return (try? await isAIReadable(fileObjectID: file.objectID)) ?? false
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

    static func canToolAccess(
        canvasTarget: ExcalidrawCoordinatorRegistry.CanvasTarget,
        currentFileID: UUID?
    ) async throws -> Bool {
        guard canvasTarget.targetsUserCanvas else { return true }
        return try await canToolAccess(fileID: currentFileID)
    }

    static func ensureAIReadable(
        canvasTarget: ExcalidrawCoordinatorRegistry.CanvasTarget,
        currentFileID: UUID?
    ) async throws {
        guard canvasTarget.targetsUserCanvas else { return }
        try await ensureAIReadable(fileID: currentFileID)
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

    private static let proposalCanvasWriteToolNames: Set<String> = [
        "adjust_elements",
    ]

    private static func requiresCurrentFileAccessCheck(
        toolName: String,
        context: ExcalidrawChatInvocationContext?
    ) -> Bool {
        !(proposalCanvasWriteToolNames.contains(toolName)
          && context?.canvasTarget.targetsProposalCanvas == true)
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
