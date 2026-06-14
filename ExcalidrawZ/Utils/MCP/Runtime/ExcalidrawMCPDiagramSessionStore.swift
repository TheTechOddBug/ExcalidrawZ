//
//  ExcalidrawMCPDiagramSessionStore.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/14.
//

import Foundation

struct ExcalidrawMCPDiagramSession: Identifiable, Codable, Sendable {
    let id: String
    let checkpointID: String
    let createdAt: Date
    let updatedAt: Date
    let elements: [MCPJSONValue]
    let sourceElementCount: Int
    let ratioHint: String?
}

struct ExcalidrawMCPCheckpoint: Codable, Sendable {
    let id: String
    let createdAt: Date
    let elements: [MCPJSONValue]
}

actor ExcalidrawMCPDiagramSessionStore {
    typealias UpdateHandler = @Sendable (ExcalidrawMCPDiagramSession) async -> Void

    private var checkpoints: [String: ExcalidrawMCPCheckpoint] = [:]
    private var currentSession: ExcalidrawMCPDiagramSession?
    private var updateHandler: UpdateHandler?

    func setUpdateHandler(_ handler: UpdateHandler?) {
        updateHandler = handler
    }

    func latestSession() -> ExcalidrawMCPDiagramSession? {
        currentSession
    }

    func checkpoint(id: String) -> ExcalidrawMCPCheckpoint? {
        checkpoints[id]
    }

    @discardableResult
    func saveCheckpoint(elements: [MCPJSONValue]) -> ExcalidrawMCPCheckpoint {
        let checkpoint = ExcalidrawMCPCheckpoint(
            id: Self.makeCheckpointID(),
            createdAt: Date(),
            elements: elements
        )
        checkpoints[checkpoint.id] = checkpoint
        return checkpoint
    }

    @discardableResult
    func publishSession(
        elements: [MCPJSONValue],
        sourceElementCount: Int,
        ratioHint: String?
    ) async -> ExcalidrawMCPDiagramSession {
        let checkpoint = saveCheckpoint(elements: elements)
        let now = Date()
        let session = ExcalidrawMCPDiagramSession(
            id: UUID().uuidString,
            checkpointID: checkpoint.id,
            createdAt: now,
            updatedAt: now,
            elements: elements,
            sourceElementCount: sourceElementCount,
            ratioHint: ratioHint
        )
        currentSession = session
        await updateHandler?(session)
        return session
    }

    private static func makeCheckpointID() -> String {
        UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
            .prefix(18)
            .description
    }
}
