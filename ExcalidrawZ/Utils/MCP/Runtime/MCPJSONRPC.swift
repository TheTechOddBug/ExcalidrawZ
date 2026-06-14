//
//  MCPJSONRPC.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/14.
//

import Foundation

struct MCPJSONRPCRequest: Decodable, Sendable {
    let jsonrpc: String?
    let id: MCPJSONValue?
    let method: String
    let params: MCPJSONValue?

    var expectsResponse: Bool {
        id != nil
    }
}

struct MCPJSONRPCResponse: Encodable, Sendable {
    let jsonrpc = "2.0"
    let id: MCPJSONValue?
    let result: MCPJSONValue?
    let error: MCPJSONRPCError?

    static func success(id: MCPJSONValue?, result: MCPJSONValue) -> MCPJSONRPCResponse {
        MCPJSONRPCResponse(id: id, result: result, error: nil)
    }

    static func failure(id: MCPJSONValue?, error: MCPJSONRPCError) -> MCPJSONRPCResponse {
        MCPJSONRPCResponse(id: id, result: nil, error: error)
    }
}

struct MCPJSONRPCError: Encodable, Error, Sendable {
    let code: Int
    let message: String
    let data: MCPJSONValue?

    static func parseError(_ message: String) -> MCPJSONRPCError {
        MCPJSONRPCError(code: -32700, message: message, data: nil)
    }

    static func invalidRequest(_ message: String) -> MCPJSONRPCError {
        MCPJSONRPCError(code: -32600, message: message, data: nil)
    }

    static func methodNotFound(_ method: String) -> MCPJSONRPCError {
        MCPJSONRPCError(code: -32601, message: "Method not found: \(method)", data: nil)
    }

    static func invalidParams(_ message: String) -> MCPJSONRPCError {
        MCPJSONRPCError(code: -32602, message: message, data: nil)
    }

    static func internalError(_ message: String) -> MCPJSONRPCError {
        MCPJSONRPCError(code: -32603, message: message, data: nil)
    }
}

extension Encodable {
    func mcpJSONData(prettyPrinted: Bool = false) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        return try encoder.encode(self)
    }
}
