//
//  ExcalidrawCore+AICameraTypes.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

@MainActor
protocol AICameraSessionEventSink: AnyObject {
    func aiCameraSessionDidStart(_ info: ExcalidrawCore.AICameraSessionInfo)
    func aiCameraSessionDidUpdate(_ info: ExcalidrawCore.AICameraSessionInfo)
    func aiCameraSessionDidInterrupt(_ info: ExcalidrawCore.AICameraSessionInfo)
    func aiCameraSessionDidSettle(_ info: ExcalidrawCore.AICameraSessionInfo)
    func aiCameraSessionDidEnd(_ info: ExcalidrawCore.AICameraSessionInfo)
}

extension ExcalidrawCore {
    enum AICameraZoomBehavior: String, Codable, Hashable {
        case preserve
        case gentle
        case fitWhenNeeded
    }

    enum AICameraSessionState: String, Codable, Hashable {
        case active
        case settling
        case interrupted
        case ended
    }

    enum AICameraEndMode: String, Codable, Hashable {
        case settle
        case immediate
    }

    struct AICameraViewportPadding: Codable, Hashable {
        var top: Double
        var right: Double
        var bottom: Double
        var left: Double

        init(top: Double, right: Double, bottom: Double, left: Double) {
            self.top = top
            self.right = right
            self.bottom = bottom
            self.left = left
        }

        init(all: Double) {
            self.init(top: all, right: all, bottom: all, left: all)
        }
    }

    enum AICameraPaddingValue: Codable, Hashable {
        case uniform(Double)
        case edges(AICameraViewportPadding)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(Double.self) {
                self = .uniform(value)
            } else {
                self = .edges(try container.decode(AICameraViewportPadding.self))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
                case .uniform(let value):
                    try container.encode(value)
                case .edges(let value):
                    try container.encode(value)
            }
        }
    }

    struct AICameraSessionOptions: Codable, Hashable {
        var zoomBehavior: AICameraZoomBehavior = .fitWhenNeeded
        var followRate: Double?
        var viewportPadding: AICameraPaddingValue?
        var minZoom: Double?
        var maxZoom: Double?
        var safeAreaRatio: Double?
        var revision: Int?
    }

    struct AICameraTargetBox: Codable, Hashable {
        var type: String = "box"
        var minX: Double
        var minY: Double
        var maxX: Double
        var maxY: Double
    }

    struct AICameraTargetElements: Codable, Hashable {
        var type: String = "elements"
        var ids: [String]
    }

    enum AICameraTarget: Codable, Hashable {
        case box(AICameraTargetBox)
        case elements(AICameraTargetElements)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(AICameraTargetBox.self) {
                self = .box(value)
            } else {
                self = .elements(try container.decode(AICameraTargetElements.self))
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
                case .box(let value):
                    try container.encode(value)
                case .elements(let value):
                    try container.encode(value)
            }
        }
    }

    struct AICameraBeginResponse: Codable, Hashable {
        var sessionId: String
        var state: AICameraSessionState
        var startedAt: JSONValue?
    }

    struct AICameraUpdateResponse: Codable, Hashable {
        var accepted: Bool
        var state: AICameraSessionState?
        var reason: String?
    }

    struct AICameraSessionInfo: Codable, Hashable {
        var sessionId: String?
        var state: AICameraSessionState?
        var startedAt: JSONValue?
        var mode: String?
        var reason: String?
        var eventType: String?
        var revision: Int?
        var stateBeforeInterrupt: AICameraSessionState?
        var camera: CameraState?
    }

    struct AICameraEndOptions: Codable, Hashable {
        var mode: AICameraEndMode = .settle
    }

    struct AICameraInterruptOptions: Codable, Hashable {
        var reason: String = "host_override"
    }
}
