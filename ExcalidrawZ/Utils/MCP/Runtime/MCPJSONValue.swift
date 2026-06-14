//
//  MCPJSONValue.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/14.
//

import Foundation

enum MCPJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([MCPJSONValue])
    case object([String: MCPJSONValue])

    init(from decoder: Decoder) throws {
        if var container = try? decoder.unkeyedContainer() {
            var values: [MCPJSONValue] = []
            while !container.isAtEnd {
                values.append(try container.decode(MCPJSONValue.self))
            }
            self = .array(values)
            return
        }

        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var object: [String: MCPJSONValue] = [:]
            for key in container.allKeys {
                object[key.stringValue] = try container.decode(MCPJSONValue.self, forKey: key)
            }
            self = .object(object)
            return
        }

        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
            case .null:
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            case .bool(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .number(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .string(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .array(let values):
                var container = encoder.unkeyedContainer()
                for value in values {
                    try container.encode(value)
                }
            case .object(let object):
                var container = encoder.container(keyedBy: DynamicCodingKey.self)
                for key in object.keys.sorted() {
                    try container.encode(object[key], forKey: DynamicCodingKey(key))
                }
        }
    }

    init(jsonObject: Any) throws {
        switch jsonObject {
            case is NSNull:
                self = .null
            case let value as Bool:
                self = .bool(value)
            case let value as Int:
                self = .number(Double(value))
            case let value as Double:
                self = .number(value)
            case let value as String:
                self = .string(value)
            case let array as [Any]:
                self = .array(try array.map(MCPJSONValue.init(jsonObject:)))
            case let dictionary as [String: Any]:
                self = .object(try dictionary.mapValues { try MCPJSONValue(jsonObject: $0) })
            default:
                throw MCPJSONValueError.unsupportedValue
        }
    }

    var objectValue: [String: MCPJSONValue]? {
        guard case .object(let object) = self else { return nil }
        return object
    }

    var arrayValue: [MCPJSONValue]? {
        guard case .array(let values) = self else { return nil }
        return values
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var numberValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    subscript(key: String) -> MCPJSONValue? {
        objectValue?[key]
    }

    static func parseJSONArray(from data: Data) throws -> [MCPJSONValue] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let array = object as? [Any] else {
            throw MCPJSONValueError.expectedArray
        }
        return try array.map(MCPJSONValue.init(jsonObject:))
    }
}

private enum MCPJSONValueError: Error {
    case expectedArray
    case unsupportedValue
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
