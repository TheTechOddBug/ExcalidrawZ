//
//  ExcalidrawMCPToolRouter.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/14.
//

import Foundation

actor ExcalidrawMCPToolRouter {
    private let store: ExcalidrawMCPDiagramSessionStore
    private var elementConverter: ExcalidrawMCPUpstreamToolHandler.ElementConverter?

    init(store: ExcalidrawMCPDiagramSessionStore = ExcalidrawMCPDiagramSessionStore()) {
        self.store = store
    }

    func setSessionUpdateHandler(
        _ handler: ExcalidrawMCPDiagramSessionStore.UpdateHandler?
    ) async {
        await store.setUpdateHandler(handler)
    }

    func setElementConverter(
        _ converter: ExcalidrawMCPUpstreamToolHandler.ElementConverter?
    ) async {
        elementConverter = converter
    }

    func handle(_ request: MCPJSONRPCRequest) async -> MCPJSONRPCResponse? {
        guard request.jsonrpc == nil || request.jsonrpc == "2.0" else {
            return .failure(
                id: request.id,
                error: .invalidRequest("Only JSON-RPC 2.0 requests are supported.")
            )
        }

        do {
            let result = try await result(for: request)
            guard request.expectsResponse else { return nil }
            return .success(id: request.id, result: result)
        } catch let error as MCPJSONRPCError {
            guard request.expectsResponse else { return nil }
            return .failure(id: request.id, error: error)
        } catch {
            guard request.expectsResponse else { return nil }
            return .failure(id: request.id, error: .internalError(error.localizedDescription))
        }
    }

    private func result(for request: MCPJSONRPCRequest) async throws -> MCPJSONValue {
        switch request.method {
            case "initialize":
                return initializeResult()
            case "notifications/initialized":
                return .object([:])
            case "ping":
                return .object([:])
            case "tools/list":
                return .object([
                    "tools": .array(ExcalidrawMCPUpstreamToolCatalog.tools.map(\.jsonValue))
                ])
            case "tools/call":
                return try await callTool(params: request.params)
            default:
                throw MCPJSONRPCError.methodNotFound(request.method)
        }
    }

    private func initializeResult() -> MCPJSONValue {
        .object([
            "protocolVersion": .string(ExcalidrawMCPUpstreamContract.protocolVersion),
            "capabilities": .object([
                "tools": .object([:])
            ]),
            "serverInfo": .object([
                "name": .string("ExcalidrawZ"),
                "version": .string(Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "0")
            ]),
            "instructions": .string(
                "Use read_me first, then create_view with Excalidraw elements JSON."
            )
        ])
    }

    private func callTool(params: MCPJSONValue?) async throws -> MCPJSONValue {
        guard let object = params?.objectValue,
              let name = object["name"]?.stringValue
        else {
            throw MCPJSONRPCError.invalidParams("tools/call requires params.name.")
        }

        let result = try await makeUpstreamToolHandler().callTool(
            name: name,
            arguments: object["arguments"]?.objectValue ?? [:]
        )
        return result.jsonValue
    }

    private func makeUpstreamToolHandler() -> ExcalidrawMCPUpstreamToolHandler {
        let converter = elementConverter
        return ExcalidrawMCPUpstreamToolHandler(
            convertRawElements: { elements in
                guard let converter else {
                    throw MCPJSONRPCError.internalError("MCP element converter is unavailable.")
                }
                return try await converter(elements)
            },
            publishDiagram: { [store] elements, sourceElementCount in
                let session = try await store.publishSession(
                    elements: elements,
                    sourceElementCount: sourceElementCount
                )
                return ExcalidrawMCPUpstreamToolHandler.PublishedDiagram(
                    checkpointID: session.checkpointID
                )
            },
            saveCheckpointData: { [store] id, data in
                _ = try await store.saveCheckpoint(id: id, data: data)
            },
            readCheckpointData: { [store] id in
                await store.checkpoint(id: id)?.dataValue
            },
            readCheckpointElements: { [store] id in
                await store.checkpoint(id: id)?.elements
            }
        )
    }
}
