//
//  ExcalidrawCore+SkeletonTypes.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    struct SkeletonInsertOptions: Codable, Hashable {
        var layout: String?
        var layoutOptions: [String: JSONValue]?
        var regenerateIds: Bool?
        var position: MermaidPosition?
        var focus: MermaidFocus?
        var files: [String: JSONValue]?
        var captureUpdate: CaptureUpdate?
        var sanitize: Bool?
    }

    struct SkeletonInsertResult: Codable, Hashable {
        var elementIds: [String]
        var insertedAt: MermaidPoint
        var bounds: MermaidBounds
    }
}
