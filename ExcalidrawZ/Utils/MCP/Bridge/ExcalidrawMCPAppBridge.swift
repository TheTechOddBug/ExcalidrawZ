//
//  ExcalidrawMCPAppBridge.swift
//  ExcalidrawZ
//
//  Created by Codex on 6/15/26.
//

import CoreData
import Foundation

@MainActor
final class ExcalidrawMCPAppBridge {
    enum BridgeError: LocalizedError {
        case appContextUnavailable
        case targetGroupUnavailable
        case createdFileUnavailable
        case aiGenerationInProgress
        case canvasUnavailable
        case fileLoadTimedOut
        case unsupportedActiveFile(String)
        case invalidGeneratedFile(String)

        var errorDescription: String? {
            switch self {
                case .appContextUnavailable:
                    "ExcalidrawZ is not ready. Open the app window before calling create_view."
                case .targetGroupUnavailable:
                    "No library group is available for the MCP drawing."
                case .createdFileUnavailable:
                    "The new MCP drawing file could not be loaded from persistence."
                case .aiGenerationInProgress:
                    "ExcalidrawZ is generating another AI response. Stop it before calling create_view."
                case .canvasUnavailable:
                    "The Excalidraw canvas is not ready. Open a drawing window before calling create_view."
                case .fileLoadTimedOut:
                    "The MCP target file did not finish loading in ExcalidrawZ."
                case .unsupportedActiveFile(let reason):
                    "The current file cannot be modified by MCP: \(reason)"
                case .invalidGeneratedFile(let message):
                    "The generated Excalidraw file is invalid: \(message)"
            }
        }
    }

    static let shared = ExcalidrawMCPAppBridge()

    private weak var fileState: FileState?
    private weak var context: NSManagedObjectContext?

    private init() {}

    func register(
        fileState: FileState,
        context: NSManagedObjectContext
    ) {
        self.fileState = fileState
        self.context = context
    }

    @discardableResult
    func createElements(
        _ elements: [MCPJSONValue]
    ) async throws -> [MCPJSONValue] {
        guard let coordinator = fileState?.excalidrawWebCoordinator else {
            throw BridgeError.canvasUnavailable
        }
        let inputData = try MCPJSONValue.array(elements).mcpJSONData()
        let inputElements = try JSONDecoder().decode(ExcalidrawCore.JSONValue.self, from: inputData)
        let convertedElements = try await coordinator.createElements(
            inputElements,
            options: .init(regenerateIds: false)
        )
        let convertedData = try JSONEncoder().encode(convertedElements)
        let convertedValue = try MCPJSONValue.parse(from: convertedData)
        guard let convertedArray = convertedValue.arrayValue else {
            throw BridgeError.invalidGeneratedFile("Converted elements is not a JSON array.")
        }
        return convertedArray
    }

    @discardableResult
    func apply(_ session: ExcalidrawMCPDiagramSession) async throws -> FileState.ActiveFile {
        guard let fileState,
              let context
        else {
            throw BridgeError.appContextUnavailable
        }
        guard fileState.aiChatSession == nil else {
            throw BridgeError.aiGenerationInProgress
        }

        let targetFile = try await ensureActiveFile(
            fileState: fileState,
            context: context
        )
        let elementsJSON = try elementsJSON(for: session)
        try await replaceCanvasElements(
            elementsJSON,
            fileID: targetFile.id,
            fileState: fileState
        )

        return targetFile
    }

    private func ensureActiveFile(
        fileState: FileState,
        context: NSManagedObjectContext
    ) async throws -> FileState.ActiveFile {
        if let activeFile = fileState.currentActiveFile {
            try validateMCPWritableActiveFile(activeFile, fileState: fileState)
            return activeFile
        }

        let targetGroupID = try targetGroupID(
            fileState: fileState,
            context: context
        )
        guard let content = ExcalidrawFile().content else {
            throw BridgeError.invalidGeneratedFile("Unable to create an empty Excalidraw file.")
        }
        let fileID = try await PersistenceController.shared.fileRepository.createFile(
            name: String(localizable: .mcpGeneratedFileName),
            content: content,
            groupObjectID: targetGroupID
        )

        guard let file = context.object(with: fileID) as? File else {
            throw BridgeError.createdFileUnavailable
        }
        if let group = file.group {
            fileState.currentActiveGroup = .group(group)
        }

        let activeFile = FileState.ActiveFile.file(file)
        fileState.setActiveFile(activeFile)
        return activeFile
    }

    private func validateMCPWritableActiveFile(
        _ activeFile: FileState.ActiveFile,
        fileState: FileState
    ) throws {
        guard !fileState.currentActiveFileIsInTrash else {
            throw BridgeError.unsupportedActiveFile("file is in Trash.")
        }

        switch activeFile {
            case .file, .localFile, .temporaryFile:
                return
            case .collaborationFile:
                throw BridgeError.unsupportedActiveFile("collaboration files are not supported yet.")
        }
    }

    private func targetGroupID(
        fileState: FileState,
        context: NSManagedObjectContext
    ) throws -> NSManagedObjectID {
        if case .group(let group) = fileState.currentActiveGroup,
           group.groupType != .trash {
            return group.objectID
        }

        guard let defaultGroup = try PersistenceController.shared.getDefaultGroup(context: context) else {
            throw BridgeError.targetGroupUnavailable
        }

        return defaultGroup.objectID
    }

    private func elementsJSON(for session: ExcalidrawMCPDiagramSession) throws -> String {
        let elementsData = try MCPJSONValue.array(session.elements).mcpJSONData()
        guard (try JSONSerialization.jsonObject(with: elementsData)) is [Any] else {
            throw BridgeError.invalidGeneratedFile("elements is not a JSON array.")
        }
        guard let jsonString = String(data: elementsData, encoding: .utf8) else {
            throw BridgeError.invalidGeneratedFile("elements JSON is not valid UTF-8.")
        }
        return jsonString
    }

    private func replaceCanvasElements(
        _ elementsJSON: String,
        fileID: String,
        fileState: FileState
    ) async throws {
        guard let coordinator = fileState.excalidrawWebCoordinator else {
            throw BridgeError.canvasUnavailable
        }

        try await waitForLoadedFile(fileID, coordinator: coordinator)
        try await coordinator.replaceAllElements(rawElementsJSON: elementsJSON)
    }

    private func waitForLoadedFile(
        _ fileID: String,
        coordinator: ExcalidrawCanvasView.Coordinator
    ) async throws {
        let deadline = Date().addingTimeInterval(5)
        while coordinator.documentSyncController.currentLoadedFileID != fileID {
            if Date() >= deadline {
                throw BridgeError.fileLoadTimedOut
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
