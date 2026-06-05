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
        layoutState.isAIChatIslandMode &&
        AIChatAvailability.isAvailable &&
        aiChatPreferences.isAIEnabled &&
        !fileState.currentActiveFileIsInTrash
    }

    private var bottomPadding: CGFloat {
        isCompactIOS ? 20 : 24
    }

    private var transition: AnyTransition {
        isCompactIOS
        ? .move(edge: .bottom).combined(with: .opacity)
        : .scale.combined(with: .opacity)
    }

    var body: some View {
        if isVisible {
            AIChatIslandView(canvasSize: canvasSize)
                .padding(.bottom, bottomPadding)
                .transition(transition)
        }
    }
}
