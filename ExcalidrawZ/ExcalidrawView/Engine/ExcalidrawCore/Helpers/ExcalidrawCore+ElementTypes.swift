//
//  ExcalidrawCore+ElementTypes.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    struct CreateElementsOptions: Codable, Hashable {
        var regenerateIds: Bool?
    }

    struct ReplaceAllElementsOptions: Codable, Hashable {
        var captureUpdate: CaptureUpdate = .immediately
    }

    struct UpdateElementOperation: Codable, Hashable {
        var id: String
        var updates: [String: JSONValue]
    }
}
