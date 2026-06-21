//
//  ExcalidrawCore+MermaidTypes.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    enum CaptureUpdate: String, Codable, Hashable {
        case immediately = "IMMEDIATELY"
        case eventually = "EVENTUALLY"
        case never = "NEVER"
    }

    enum MermaidAnchor: String, Codable, Hashable {
        case topLeft = "top-left"
        case center
    }

    enum MermaidPosition: Codable, Hashable {
        case auto
        case viewportCenter
        case sceneCenter
        case point(MermaidPointPosition)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let rawValue = try? container.decode(String.self) {
                switch rawValue {
                    case "auto":
                        self = .auto
                    case "viewport-center":
                        self = .viewportCenter
                    case "scene-center":
                        self = .sceneCenter
                    default:
                        throw DecodingError.dataCorruptedError(
                            in: container,
                            debugDescription: "Unsupported Mermaid position: \(rawValue)"
                        )
                }
            } else {
                self = .point(try container.decode(MermaidPointPosition.self))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
                case .auto:
                    try container.encode("auto")
                case .viewportCenter:
                    try container.encode("viewport-center")
                case .sceneCenter:
                    try container.encode("scene-center")
                case .point(let value):
                    try container.encode(value)
            }
        }
    }

    struct MermaidPointPosition: Codable, Hashable {
        var x: Double
        var y: Double
        var anchor: MermaidAnchor?
    }

    enum MermaidFocus: Codable, Hashable {
        case enabled(Bool)
        case mode(MermaidFocusMode)
        case options(MermaidFocusOptions)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let enabled = try? container.decode(Bool.self) {
                self = .enabled(enabled)
            } else if let mode = try? container.decode(MermaidFocusMode.self) {
                self = .mode(mode)
            } else {
                self = .options(try container.decode(MermaidFocusOptions.self))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
                case .enabled(let value):
                    try container.encode(value)
                case .mode(let value):
                    try container.encode(value)
                case .options(let value):
                    try container.encode(value)
            }
        }
    }

    enum MermaidFocusMode: String, Codable, Hashable {
        case center
        case fitContent
        case fitViewport
    }

    struct MermaidCanvasOffsets: Codable, Hashable {
        var top: Double?
        var right: Double?
        var bottom: Double?
        var left: Double?
    }

    struct MermaidFocusOptions: Codable, Hashable {
        var mode: MermaidFocusMode?
        var animate: Bool?
        var duration: Int?
        var viewportZoomFactor: Double?
        var minZoom: Double?
        var maxZoom: Double?
        var canvasOffsets: MermaidCanvasOffsets?
    }

    struct MermaidInsertOptions: Codable, Hashable {
        var position: MermaidPosition?
        var focus: MermaidFocus?
        var regenerateIds: Bool?
        var mermaidConfig: JSONValue?
        var captureUpdate: CaptureUpdate?
    }

    struct MermaidConvertOptions: Codable, Hashable {
        var regenerateIds: Bool?
        var mermaidConfig: JSONValue?
    }

    struct MermaidPoint: Codable, Hashable {
        var x: Double
        var y: Double
    }

    struct MermaidBounds: Codable, Hashable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    struct MermaidInsertResult: Codable, Hashable {
        var elementIds: [String]
        var insertedAt: MermaidPoint
        var bounds: MermaidBounds
    }

    struct MermaidConvertResult: Codable, Hashable {
        var elements: [JSONValue]
        var files: [String: JSONValue]
    }
}
