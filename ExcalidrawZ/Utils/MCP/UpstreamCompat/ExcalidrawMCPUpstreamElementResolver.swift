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
        let ratioHint: String?
    }

    var loadCheckpoint: @Sendable (String) async -> ExcalidrawMCPCheckpoint?

    func resolve(_ parsedElements: [MCPJSONValue]) async throws -> Result {
        let restoreCheckpointID = parsedElements.first { element in
            element["type"]?.stringValue == ExcalidrawMCPUpstreamContract.PseudoElementType.restoreCheckpoint
        }?["id"]?.stringValue

        let deleteIDs = Set(parsedElements.flatMap(Self.deleteIDs(from:)))
        let newElements = parsedElements.filter { element in
            let type = element["type"]?.stringValue
            return type != ExcalidrawMCPUpstreamContract.PseudoElementType.restoreCheckpoint &&
                type != ExcalidrawMCPUpstreamContract.PseudoElementType.delete
        }

        let resolvedElements: [MCPJSONValue]
        if let restoreCheckpointID {
            guard let checkpoint = await loadCheckpoint(restoreCheckpointID) else {
                throw MCPJSONRPCError.invalidParams(
                    "Checkpoint \"\(restoreCheckpointID)\" not found. Recreate the diagram from scratch."
                )
            }

            let baseElements = checkpoint.elements.filter { element in
                let id = element["id"]?.stringValue
                let containerID = element["containerId"]?.stringValue
                return !deleteIDs.contains(id ?? "") &&
                    !deleteIDs.contains(containerID ?? "")
            }
            resolvedElements = baseElements + newElements
        } else {
            resolvedElements = newElements
        }

        return Result(
            elements: resolvedElements,
            ratioHint: Self.cameraRatioHint(in: parsedElements)
        )
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

    private static func cameraRatioHint(in elements: [MCPJSONValue]) -> String? {
        for element in elements where element["type"]?.stringValue == ExcalidrawMCPUpstreamContract.PseudoElementType.cameraUpdate {
            guard let width = element["width"]?.numberValue,
                  let height = element["height"]?.numberValue,
                  height > 0
            else {
                continue
            }

            let ratio = width / height
            if abs(ratio - 4.0 / 3.0) > 0.15 {
                return "Tip: cameraUpdate used \(Int(width))x\(Int(height)); prefer a 4:3 viewport such as 400x300, 800x600, or 1200x900."
            }
        }
        return nil
    }
}
