//
//  ExcalidrawMCPUpstreamElementResolver.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/15.
//

import Foundation

struct ExcalidrawMCPUpstreamElementResolver {
    struct Result: Sendable {
        let elements: [MCPJSONValue]
    }

    private struct ExtractedElements: Sendable {
        let drawElements: [MCPJSONValue]
        let restoreCheckpointID: String?
        let deleteIDs: Set<String>
    }

    var loadCheckpointElements: @Sendable (String) async -> [MCPJSONValue]?

    func resolve(_ parsedElements: [MCPJSONValue]) async throws -> Result {
        let extracted = Self.extractViewportAndElements(parsedElements)

        let resolvedElements: [MCPJSONValue]
        if let restoreCheckpointID = extracted.restoreCheckpointID {
            guard let checkpointElements = await loadCheckpointElements(restoreCheckpointID) else {
                throw MCPJSONRPCError.invalidParams(
                    "Checkpoint \"\(restoreCheckpointID)\" not found. Recreate the diagram from scratch."
                )
            }

            let base = Self.extractViewportAndElements(checkpointElements).drawElements
            let filteredBase = Self.filterDeletedElements(
                base,
                deleteIDs: extracted.deleteIDs
            )
            resolvedElements = filteredBase + extracted.drawElements
        } else {
            resolvedElements = extracted.drawElements
        }

        return Result(elements: resolvedElements)
    }

    private static func extractViewportAndElements(_ elements: [MCPJSONValue]) -> ExtractedElements {
        var restoreCheckpointID: String?
        var deleteIDs: Set<String> = []
        var drawElements: [MCPJSONValue] = []

        for element in elements {
            switch element["type"]?.stringValue {
                case ExcalidrawMCPUpstreamContract.PseudoElementType.cameraUpdate:
                    continue
                case ExcalidrawMCPUpstreamContract.PseudoElementType.restoreCheckpoint:
                    restoreCheckpointID = element["id"]?.stringValue
                case ExcalidrawMCPUpstreamContract.PseudoElementType.delete:
                    deleteIDs.formUnion(Self.deleteIDs(from: element))
                default:
                    drawElements.append(element)
            }
        }

        if !deleteIDs.isEmpty {
            drawElements = drawElements.map { element in
                guard Self.shouldHideInlineDeletedElement(element, deleteIDs: deleteIDs),
                      var object = element.objectValue
                else {
                    return element
                }
                object["opacity"] = .number(1)
                return .object(object)
            }
        }

        return ExtractedElements(
            drawElements: drawElements,
            restoreCheckpointID: restoreCheckpointID,
            deleteIDs: deleteIDs
        )
    }

    private static func filterDeletedElements(
        _ elements: [MCPJSONValue],
        deleteIDs: Set<String>
    ) -> [MCPJSONValue] {
        guard !deleteIDs.isEmpty else { return elements }
        return elements.filter { element in
            !shouldHideInlineDeletedElement(element, deleteIDs: deleteIDs)
        }
    }

    private static func shouldHideInlineDeletedElement(
        _ element: MCPJSONValue,
        deleteIDs: Set<String>
    ) -> Bool {
        let id = element["id"]?.stringValue
        let containerID = element["containerId"]?.stringValue
        return deleteIDs.contains(id ?? "") || deleteIDs.contains(containerID ?? "")
    }

    private static func deleteIDs(from element: MCPJSONValue) -> [String] {
        guard element["type"]?.stringValue == ExcalidrawMCPUpstreamContract.PseudoElementType.delete else {
            return []
        }
        let raw = element["ids"]?.stringValue ?? element["id"]?.stringValue ?? ""
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
