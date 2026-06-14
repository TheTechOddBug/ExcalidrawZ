//
//  ExcalidrawMCPUpstreamTools.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/14.
//

import Foundation

struct ExcalidrawMCPTool: Sendable {
    let name: String
    let title: String
    let description: String
    let inputSchema: MCPJSONValue
    let annotations: [String: MCPJSONValue]

    init(
        name: String,
        title: String,
        description: String,
        inputSchema: MCPJSONValue,
        annotations: [String: MCPJSONValue] = [:]
    ) {
        self.name = name
        self.title = title
        self.description = description
        self.inputSchema = inputSchema
        self.annotations = annotations
    }

    var jsonValue: MCPJSONValue {
        var object: [String: MCPJSONValue] = [
            "name": .string(name),
            "title": .string(title),
            "description": .string(description),
            "inputSchema": inputSchema
        ]

        if !annotations.isEmpty {
            object["annotations"] = .object(annotations)
        }

        return .object(object)
    }
}

struct ExcalidrawMCPToolResult: Sendable {
    struct Content: Sendable {
        let type: String
        let text: String

        var jsonValue: MCPJSONValue {
            .object([
                "type": .string(type),
                "text": .string(text)
            ])
        }
    }

    let content: [Content]
    let isError: Bool
    let structuredContent: MCPJSONValue?

    init(
        text: String,
        isError: Bool = false,
        structuredContent: MCPJSONValue? = nil
    ) {
        self.content = [Content(type: "text", text: text)]
        self.isError = isError
        self.structuredContent = structuredContent
    }

    var jsonValue: MCPJSONValue {
        var object: [String: MCPJSONValue] = [
            "content": .array(content.map(\.jsonValue))
        ]
        if isError {
            object["isError"] = .bool(true)
        }
        if let structuredContent {
            object["structuredContent"] = structuredContent
        }
        return .object(object)
    }
}

enum ExcalidrawMCPToolSchemas {
    static let emptyObject: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([:]),
        "additionalProperties": .bool(false)
    ])

    static let createView: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "elements": .object([
                "type": .string("string"),
                "description": .string(
                    "JSON array string of Excalidraw elements. Must be valid JSON; no comments or trailing commas. Keep compact. Call read_me first for format reference."
                )
            ])
        ]),
        "required": .array([.string("elements")]),
        "additionalProperties": .bool(false)
    ])

    static let checkpointID: MCPJSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "id": .object([
                "type": .string("string"),
                "description": .string("Checkpoint id returned by create_view or save_checkpoint.")
            ])
        ]),
        "required": .array([.string("id")]),
        "additionalProperties": .bool(false)
    ])
}

enum ExcalidrawMCPUpstreamToolCatalog {
    static let tools: [ExcalidrawMCPTool] = [
        ExcalidrawMCPTool(
            name: ExcalidrawMCPUpstreamContract.ToolName.readMe,
            title: "Read Excalidraw Drawing Guide",
            description: "Returns the Excalidraw element format reference with color palettes, examples, and tips. Call this BEFORE using create_view for the first time.",
            inputSchema: ExcalidrawMCPToolSchemas.emptyObject,
            annotations: ["readOnlyHint": .bool(true)]
        ),
        ExcalidrawMCPTool(
            name: ExcalidrawMCPUpstreamContract.ToolName.createView,
            title: "Draw Diagram",
            description: "Renders a hand-drawn diagram using Excalidraw elements. Elements stream in one by one with draw-on animations. Call read_me first to learn the element format.",
            inputSchema: ExcalidrawMCPToolSchemas.createView,
            annotations: ["readOnlyHint": .bool(true)]
        ),
        ExcalidrawMCPTool(
            name: ExcalidrawMCPUpstreamContract.ToolName.saveCheckpoint,
            title: "Save Checkpoint",
            description: "Saves the current MCP diagram state and returns a checkpoint id.",
            inputSchema: ExcalidrawMCPToolSchemas.emptyObject
        ),
        ExcalidrawMCPTool(
            name: ExcalidrawMCPUpstreamContract.ToolName.readCheckpoint,
            title: "Read Checkpoint",
            description: "Reads a previously saved MCP diagram checkpoint as an elements JSON string.",
            inputSchema: ExcalidrawMCPToolSchemas.checkpointID,
            annotations: ["readOnlyHint": .bool(true)]
        )
    ]
}
