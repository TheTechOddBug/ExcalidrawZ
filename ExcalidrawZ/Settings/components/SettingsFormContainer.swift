//
//  SettingsFormContainer.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/05/27.
//

import SwiftUI

struct SettingsFormContainer<Content: View>: View {
    private let legacyAlignment: HorizontalAlignment
    private let legacySpacing: CGFloat?
    private let content: Content

    init(
        legacyAlignment: HorizontalAlignment = .center,
        legacySpacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.legacyAlignment = legacyAlignment
        self.legacySpacing = legacySpacing
        self.content = content()
    }

    var body: some View {
        if #available(macOS 14.0, *) {
            Form {
                content
            }
            .formStyle(.grouped)
        } else {
            ScrollView {
                VStack(alignment: legacyAlignment, spacing: legacySpacing) {
                    content
                }
                .padding()
            }
        }
    }
}
