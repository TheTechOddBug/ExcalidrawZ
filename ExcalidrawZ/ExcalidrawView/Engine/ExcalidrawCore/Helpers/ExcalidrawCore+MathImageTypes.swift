//
//  ExcalidrawCore+MathImageTypes.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    struct MathImageParams: Codable, Hashable {
        var svg: String?
        var svgBase64: String?
        var dataURL: String?
        var latex: String?
        var renderer: String?
        var width: Double?
        var height: Double?
    }

    struct MathImageOptions: Codable, Hashable {
        var position: MermaidPosition?
        var focus: MermaidFocus?
        var captureUpdate: CaptureUpdate?
    }

    struct MathImageResult: Codable, Hashable {
        var elementId: String?
        var fileId: String?
        var elementCount: Int?
        var durationMs: Double?
        var bounds: MermaidBounds?
        var width: Double?
        var height: Double?
        var usedLegacyFallback: Bool?
    }
}
