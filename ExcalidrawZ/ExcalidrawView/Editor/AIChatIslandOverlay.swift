//
//  AIChatIslandOverlay.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/05.
//

import SwiftUI
import ChocofordUI

struct AIChatIslandOverlay: View {
    @Environment(\.containerHorizontalSizeClass) private var containerHorizontalSizeClass

    @EnvironmentObject private var layoutState: LayoutState
    @EnvironmentObject private var fileState: FileState
    @ObservedObject private var aiChatPreferences = AIChatPreferences.shared

    let canvasSize: CGSize

    private var isCompactIOS: Bool {
#if os(iOS)
        containerHorizontalSizeClass == .compact
#else
        false
#endif
    }

    private var isVisible: Bool {
#if os(iOS)
        guard !isCompactIOS else { return false }
#endif
        return layoutState.isAIChatIslandMode &&
        AIChatAvailability.isAvailable &&
        aiChatPreferences.isAIEnabled &&
        !fileState.currentActiveFileIsInTrash
    }

    var body: some View {
        if isVisible {
            regularOverlay
        }
    }

    private var regularOverlay: some View {
        AIChatIslandView(canvasSize: canvasSize)
            .padding(.bottom, 24)
            .transition(.scale.combined(with: .opacity))
    }
}
