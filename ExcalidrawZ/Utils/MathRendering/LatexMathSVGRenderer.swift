//
//  LatexMathSVGRenderer.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/19.
//

import Foundation

enum LatexMathSVGRenderer {
    static func debugPrintSVGBeforeInsert(_ svg: String, source: String) {
#if DEBUG
        print(
            """
            [LatexMathSVGRenderer] MathJax SVG before insert (\(source)):
            \(svg)
            """
        )
#endif
    }
}
