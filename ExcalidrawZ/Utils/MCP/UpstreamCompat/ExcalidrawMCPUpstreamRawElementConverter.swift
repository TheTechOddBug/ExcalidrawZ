//
//  ExcalidrawMCPUpstreamRawElementConverter.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/16.
//

import Foundation

/// Mirrors upstream `convertRawElements` from
/// `excalidraw/excalidraw-mcp/src/mcp-app.tsx`.
///
/// Keep this type limited to upstream compatibility. App-specific canvas
/// access is injected through `createElements`.
struct ExcalidrawMCPUpstreamRawElementConverter {
    typealias CreateElements = @Sendable ([MCPJSONValue]) async throws -> [MCPJSONValue]

    private let createElements: CreateElements

    init(createElements: @escaping CreateElements) {
        self.createElements = createElements
    }

    func convertRawElements(_ elements: [MCPJSONValue]) async throws -> [MCPJSONValue] {
        let pseudos = elements.filter(Self.isPseudoElement)
        let real = elements.filter { !Self.isPseudoElement($0) }
        let withDefaults = real.map(Self.elementWithLabelDefaults)
        let convertedElements = try await createElements(withDefaults)
        let converted = convertedElements.map(Self.elementWithTextFontFix)

        return converted + pseudos
    }

    private static func isPseudoElement(_ element: MCPJSONValue) -> Bool {
        guard let type = element["type"]?.stringValue else { return false }
        return pseudoElementTypes.contains(type)
    }

    private static func elementWithLabelDefaults(_ element: MCPJSONValue) -> MCPJSONValue {
        guard var object = element.objectValue,
              var label = object["label"]?.objectValue
        else {
            return element
        }

        if label["textAlign"] == nil {
            label["textAlign"] = .string("center")
        }
        if label["verticalAlign"] == nil {
            label["verticalAlign"] = .string("middle")
        }
        object["label"] = .object(label)
        return .object(object)
    }

    private static func elementWithTextFontFix(_ element: MCPJSONValue) -> MCPJSONValue {
        guard var object = element.objectValue,
              object["type"]?.stringValue == "text"
        else {
            return element
        }

        object["fontFamily"] = .number(excalifontFamily)
        return .object(object)
    }

    private static let pseudoElementTypes: Set<String> = [
        ExcalidrawMCPUpstreamContract.PseudoElementType.cameraUpdate,
        ExcalidrawMCPUpstreamContract.PseudoElementType.delete,
        ExcalidrawMCPUpstreamContract.PseudoElementType.restoreCheckpoint
    ]

    /// Upstream uses `FONT_FAMILY.Excalifont ?? 1`; in our bundled
    /// Excalidraw build, Excalifont is represented by 5.
    private static let excalifontFamily = 5.0
}
