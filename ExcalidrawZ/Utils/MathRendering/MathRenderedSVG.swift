//
//  MathRenderedSVG.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/19.
//

import Foundation

struct MathRenderedSVG: Hashable, Sendable {
    let source: String
    let svg: String
    let renderer: String
    let width: Double?
    let height: Double?

    var latex: String {
        source
    }

    var mathImageParams: ExcalidrawCore.MathImageParams {
        ExcalidrawCore.MathImageParams(
            svg: svg,
            latex: source,
            renderer: renderer,
            width: width,
            height: height
        )
    }
}
