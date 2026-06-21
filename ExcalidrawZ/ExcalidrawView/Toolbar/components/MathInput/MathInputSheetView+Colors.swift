//
//  MathInputSheetView+Colors.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/20.
//

import SwiftUI

extension MathInputSheetView {
    static let defaultLightSVGColor = "#1e1e1e"
    static let defaultDarkSVGColor = "#ffffff"

    static func isThemeDefaultSVGColor(_ color: String) -> Bool {
        let normalizedColor = color.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedColor == defaultLightSVGColor
            || normalizedColor == defaultDarkSVGColor
    }

    static func isThemeDefaultSVGColorSelection(_ color: String) -> Bool {
        color.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == defaultLightSVGColor
    }

    var selectedSVGColorForPicker: String {
        usesThemeDefaultSVGColor ? Self.defaultLightSVGColor : selectedSVGColor
    }

    var resolvedSVGColorForRendering: String {
        usesThemeDefaultSVGColor ? Self.defaultLightSVGColor : selectedSVGColor
    }
}

extension CanvasPreferencesState.Theme {
    var colorScheme: ColorScheme {
        switch self {
            case .light:
                return .light
            case .dark:
                return .dark
        }
    }
}
