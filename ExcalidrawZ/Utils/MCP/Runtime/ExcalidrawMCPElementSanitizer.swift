//
//  ExcalidrawMCPElementSanitizer.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/15.
//

import Foundation

enum ExcalidrawMCPElementSanitizer {
    static func sanitizeElements(_ elements: [MCPJSONValue]) throws -> [MCPJSONValue] {
        elements.enumerated().map { index, element in
            normalizeElement(element, index: index)
        }
    }

    static func checkpointElements(from data: MCPJSONValue) -> [MCPJSONValue]? {
        data["elements"]?.arrayValue ??
            data["data"]?["elements"]?.arrayValue ??
            data.arrayValue
    }

    private static func normalizeElement(_ element: MCPJSONValue, index: Int) -> MCPJSONValue {
        guard var object = element.objectValue else {
            return element
        }

        switch object["type"]?.stringValue {
            case "text":
                fillCommonDefaults(in: &object, index: index, shouldFillSize: false)
                fillTextDefaults(in: &object)
            case "arrow", "line":
                fillCommonDefaults(in: &object, index: index)
                fillLinearDefaults(in: &object)
            case "freedraw":
                fillCommonDefaults(in: &object, index: index)
                fillFreeDrawDefaults(in: &object)
            case "image":
                fillCommonDefaults(in: &object, index: index)
                fillImageDefaults(in: &object)
            case "pdf":
                fillCommonDefaults(in: &object, index: index)
                fillPDFDefaults(in: &object)
            default:
                fillCommonDefaults(in: &object, index: index)
                break
        }
        return .object(object)
    }

    private static func fillCommonDefaults(
        in object: inout [String: MCPJSONValue],
        index: Int,
        shouldFillSize: Bool = true
    ) {
        setStringIfNeeded(&object, key: "id", defaultValue: "mcp_element_\(index)")
        setNumberIfNeeded(&object, key: "x", defaultValue: 0)
        setNumberIfNeeded(&object, key: "y", defaultValue: 0)
        if shouldFillSize {
            setNumberIfNeeded(&object, key: "width", defaultValue: 0)
            setNumberIfNeeded(&object, key: "height", defaultValue: 0)
        }
        setStringIfNeeded(&object, key: "strokeColor", defaultValue: "#1e1e1e")
        setStringIfNeeded(&object, key: "backgroundColor", defaultValue: "transparent")
        setStringIfNeeded(&object, key: "fillStyle", defaultValue: "hachure")
        setNumberIfNeeded(&object, key: "strokeWidth", defaultValue: 1)
        setStringIfNeeded(&object, key: "strokeStyle", defaultValue: "solid")
        setNumberIfNeeded(&object, key: "roughness", defaultValue: 1)
        setNumberIfNeeded(&object, key: "opacity", defaultValue: 100)
        setNumberIfNeeded(&object, key: "angle", defaultValue: 0)
        setNumberIfNeeded(&object, key: "seed", defaultValue: Double(index + 1))
        setNumberIfNeeded(&object, key: "version", defaultValue: 1)
        setNumberIfNeeded(&object, key: "versionNonce", defaultValue: Double(1000 + index))
        setBoolIfNeeded(&object, key: "isDeleted", defaultValue: false)
        setArrayIfNeeded(&object, key: "groupIds", defaultValue: [])
    }

    private static func fillTextDefaults(in object: inout [String: MCPJSONValue]) {
        normalizeOptionalNumber(&object, key: "width")
        normalizeOptionalNumber(&object, key: "height")
        setNumberIfNeeded(&object, key: "fontSize", defaultValue: 20)
        setNumberIfNeeded(&object, key: "fontFamily", defaultValue: 5)
        setStringIfNeeded(&object, key: "text", defaultValue: "")
        setStringIfNeeded(&object, key: "textAlign", defaultValue: "left")
        setStringIfNeeded(&object, key: "verticalAlign", defaultValue: "top")
    }

    private static func fillLinearDefaults(in object: inout [String: MCPJSONValue]) {
        guard object["points"]?.arrayValue == nil else { return }
        let width = object["width"]?.numberValue ?? 0
        let height = object["height"]?.numberValue ?? 0
        object["points"] = .array([
            .array([.number(0), .number(0)]),
            .array([.number(width), .number(height)])
        ])
    }

    private static func fillFreeDrawDefaults(in object: inout [String: MCPJSONValue]) {
        setArrayIfNeeded(&object, key: "points", defaultValue: [])
    }

    private static func fillImageDefaults(in object: inout [String: MCPJSONValue]) {
        setEnumStringIfNeeded(&object, key: "status", defaultValue: "saved", allowedValues: imageStatusValues)
        setArrayIfNeeded(&object, key: "scale", defaultValue: [.number(1), .number(1)])
    }

    private static func fillPDFDefaults(in object: inout [String: MCPJSONValue]) {
        setEnumStringIfNeeded(&object, key: "status", defaultValue: "saved", allowedValues: pdfStatusValues)
        setNumberIfNeeded(&object, key: "currentPage", defaultValue: 1)
        setNumberIfNeeded(&object, key: "totalPages", defaultValue: 1)
    }

    private static func setNumberIfNeeded(
        _ object: inout [String: MCPJSONValue],
        key: String,
        defaultValue: Double
    ) {
        switch object[key] {
            case .number(let number) where number.isFinite:
                return
            case .string(let string):
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if let number = Double(trimmed), number.isFinite {
                    object[key] = .number(number)
                } else {
                    object[key] = .number(defaultValue)
                }
            default:
                object[key] = .number(defaultValue)
        }
    }

    private static func normalizeOptionalNumber(
        _ object: inout [String: MCPJSONValue],
        key: String
    ) {
        switch object[key] {
            case .number(let number) where number.isFinite:
                return
            case .string(let string):
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if let number = Double(trimmed), number.isFinite {
                    object[key] = .number(number)
                } else {
                    object.removeValue(forKey: key)
                }
            case nil:
                return
            default:
                object.removeValue(forKey: key)
        }
    }

    private static func setStringIfNeeded(
        _ object: inout [String: MCPJSONValue],
        key: String,
        defaultValue: String
    ) {
        switch object[key] {
            case .string(let value) where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
                return
            case .number(let number) where number.isFinite:
                object[key] = .string(String(number))
            default:
                object[key] = .string(defaultValue)
        }
    }

    private static func setEnumStringIfNeeded(
        _ object: inout [String: MCPJSONValue],
        key: String,
        defaultValue: String,
        allowedValues: Set<String>
    ) {
        guard case .string(let value) = object[key],
              allowedValues.contains(value)
        else {
            object[key] = .string(defaultValue)
            return
        }
    }

    private static func setBoolIfNeeded(
        _ object: inout [String: MCPJSONValue],
        key: String,
        defaultValue: Bool
    ) {
        switch object[key] {
            case .bool:
                return
            case .string(let value):
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                    case "true":
                        object[key] = .bool(true)
                    case "false":
                        object[key] = .bool(false)
                    default:
                        object[key] = .bool(defaultValue)
                }
            case .number(let value) where value.isFinite:
                object[key] = .bool(value != 0)
            default:
                object[key] = .bool(defaultValue)
        }
    }

    private static func setArrayIfNeeded(
        _ object: inout [String: MCPJSONValue],
        key: String,
        defaultValue: [MCPJSONValue]
    ) {
        guard object[key]?.arrayValue == nil else { return }
        object[key] = .array(defaultValue)
    }

    private static let imageStatusValues: Set<String> = [
        "pending",
        "saved",
        "error"
    ]

    private static let pdfStatusValues: Set<String> = [
        "pending",
        "saved",
        "error"
    ]
}
