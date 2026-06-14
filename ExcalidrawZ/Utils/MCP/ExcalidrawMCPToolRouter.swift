//
//  ExcalidrawMCPToolRouter.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/14.
//

import Foundation

actor ExcalidrawMCPToolRouter {
    private let store: ExcalidrawMCPDiagramSessionStore

    init(store: ExcalidrawMCPDiagramSessionStore = ExcalidrawMCPDiagramSessionStore()) {
        self.store = store
    }

    func setSessionUpdateHandler(
        _ handler: ExcalidrawMCPDiagramSessionStore.UpdateHandler?
    ) async {
        await store.setUpdateHandler(handler)
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

        let arguments = object["arguments"]?.objectValue ?? [:]
        let result: ExcalidrawMCPToolResult
        switch name {
            case ExcalidrawMCPUpstreamContract.ToolName.readMe:
                result = ExcalidrawMCPToolResult(text: ExcalidrawMCPUpstreamRecall.cheatSheet)
            case ExcalidrawMCPUpstreamContract.ToolName.createView:
                result = try await createView(arguments: arguments)
            case ExcalidrawMCPUpstreamContract.ToolName.saveCheckpoint:
                result = try await saveCheckpoint()
            case ExcalidrawMCPUpstreamContract.ToolName.readCheckpoint:
                result = try await readCheckpoint(arguments: arguments)
            default:
                throw MCPJSONRPCError.invalidParams("Unknown tool: \(name)")
        }

        return result.jsonValue
    }

    private func createView(
        arguments: [String: MCPJSONValue]
    ) async throws -> ExcalidrawMCPToolResult {
        guard let elementsString = arguments["elements"]?.stringValue else {
            throw MCPJSONRPCError.invalidParams("create_view requires arguments.elements.")
        }

        let inputData = Data(elementsString.utf8)
        guard inputData.count <= ExcalidrawMCPUpstreamContract.maxInputBytes else {
            return ExcalidrawMCPToolResult(
                text: "Elements input exceeds \(ExcalidrawMCPUpstreamContract.maxInputBytes) byte limit. Reduce the number of elements or use checkpoints to build incrementally.",
                isError: true
            )
        }

        let parsedElements: [MCPJSONValue]
        do {
            parsedElements = try MCPJSONValue.parseJSONArray(from: inputData)
        } catch {
            return ExcalidrawMCPToolResult(
                text: "Invalid JSON in elements. Ensure the value is a JSON array string with no comments or trailing commas.",
                isError: true
            )
        }

        let resolver = ExcalidrawMCPUpstreamElementResolver { [store] id in
            await store.checkpoint(id: id)
        }
        let resolved = try await resolver.resolve(parsedElements)
        let session = await store.publishSession(
            elements: resolved.elements,
            sourceElementCount: parsedElements.count,
            ratioHint: resolved.ratioHint
        )

        var message = """
        Diagram received by ExcalidrawZ. Checkpoint id: "\(session.checkpointID)".
        If the user asks to revise this diagram, call create_view again with a restoreCheckpoint pseudo-element using that id.
        """
        if let ratioHint = resolved.ratioHint {
            message += "\n\(ratioHint)"
        }

        return ExcalidrawMCPToolResult(
            text: message,
            structuredContent: .object([
                "checkpointId": .string(session.checkpointID)
            ])
        )
    }

    private func saveCheckpoint() async throws -> ExcalidrawMCPToolResult {
        guard let session = await store.latestSession() else {
            return ExcalidrawMCPToolResult(
                text: "No active MCP diagram session to save.",
                isError: true
            )
        }

        let checkpoint = await store.saveCheckpoint(elements: session.elements)
        return ExcalidrawMCPToolResult(
            text: "Checkpoint saved. Checkpoint id: \"\(checkpoint.id)\"."
        )
    }

    private func readCheckpoint(
        arguments: [String: MCPJSONValue]
    ) async throws -> ExcalidrawMCPToolResult {
        guard let id = arguments["id"]?.stringValue else {
            throw MCPJSONRPCError.invalidParams("read_checkpoint requires arguments.id.")
        }
        guard let checkpoint = await store.checkpoint(id: id) else {
            return ExcalidrawMCPToolResult(
                text: "Checkpoint \"\(id)\" was not found.",
                isError: true
            )
        }

        let data = try checkpoint.elements.mcpJSONData()
        let json = String(data: data, encoding: .utf8) ?? "[]"
        return ExcalidrawMCPToolResult(text: json)
    }
}
