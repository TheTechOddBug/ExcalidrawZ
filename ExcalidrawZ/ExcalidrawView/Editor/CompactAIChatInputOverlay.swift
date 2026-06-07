//
//  CompactAIChatInputOverlay.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/07.
//

#if os(iOS)
import SwiftUI
import UIKit

struct CompactAIChatInputOverlay: View {
    @Environment(\.containerHorizontalSizeClass) private var containerHorizontalSizeClass

    @EnvironmentObject private var fileState: FileState
    @EnvironmentObject private var layoutState: LayoutState
    @EnvironmentObject private var aiChatState: AIChatState
    @ObservedObject private var aiChatPreferences = AIChatPreferences.shared

    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardAnimationDuration: TimeInterval = 0.25

    private var isVisible: Bool {
        containerHorizontalSizeClass == .compact &&
            layoutState.isCompactAIChatToolbarPresented &&
            layoutState.isCompactAIChatInputEditing &&
            AIChatAvailability.isAvailable &&
            aiChatPreferences.isAIEnabled &&
            !fileState.currentActiveFileIsInTrash
    }

    private var conversationIDBinding: Binding<String?> {
        Binding(
            get: { fileState.aiChatConversationID },
            set: { fileState.aiChatConversationID = $0 }
        )
    }

    var body: some View {
        if isVisible {
            PromptInputView(
                conversationID: conversationIDBinding,
                pendingQueue: $aiChatState.pendingQueue,
                style: .compactIOSIsland,
                focusOnAppear: true
            )
            .disabled(fileState.isAIChatConversationLoading || fileState.currentActiveFileIsInTrash)
            .padding(.horizontal, 12)
            .padding(.bottom, bottomPadding)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeOut(duration: keyboardAnimationDuration), value: keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                updateKeyboardHeight(notification)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
                updateKeyboardHeight(notification, isHiding: true)
            }
        }
    }

    private var bottomPadding: CGFloat {
        keyboardHeight > 0 ? keyboardHeight + 8 : 64
    }

    private func updateKeyboardHeight(_ notification: Notification, isHiding: Bool = false) {
        if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
            keyboardAnimationDuration = duration
        }

        if isHiding {
            keyboardHeight = 0
            layoutState.exitCompactAIChatInputEditing()
            return
        }

        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            keyboardHeight = 0
            return
        }

        let screenHeight = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }
            .first ?? UIScreen.main.bounds.height
        keyboardHeight = max(0, screenHeight - frame.minY)
    }
}
#endif
