//
//  FeatureDiscoveryTips.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/02.
//

import SwiftUI

#if canImport(TipKit)
import TipKit
#endif

enum FeatureDiscoveryTips {
    private static let resetPendingDefaultsKey = "FeatureDiscoveryTipsResetPending"

    static var isAvailable: Bool {
#if canImport(TipKit)
        if #available(macOS 14.0, iOS 17.0, *) {
            return true
        }
#endif
        return false
    }

    @MainActor
    static func configureIfAvailable() {
#if canImport(TipKit)
        if #available(macOS 14.0, iOS 17.0, *) {
            resetDatastoreBeforeConfigureIfNeeded()
            try? Tips.configure([
                .datastoreLocation(.applicationDefault)
            ])
        }
#endif
    }

    static func requestResetOnNextLaunch() {
        UserDefaults.standard.set(true, forKey: resetPendingDefaultsKey)
    }

#if canImport(TipKit)
    @available(macOS 14.0, iOS 17.0, *)
    private static func resetDatastoreBeforeConfigureIfNeeded() {
        guard UserDefaults.standard.bool(forKey: resetPendingDefaultsKey) else { return }

        do {
            try Tips.resetDatastore()
            UserDefaults.standard.removeObject(forKey: resetPendingDefaultsKey)
        } catch {
            print("Failed to reset TipKit datastore before configure:", error)
        }
    }
#endif
}

enum FeatureDiscoveryTipKind {
    case aiFileVisibility
    case lockFile
}

struct FeatureDiscoveryTipModifier: ViewModifier {
    let kind: FeatureDiscoveryTipKind
    var isEnabled: Bool = true

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
#if canImport(TipKit)
            if #available(macOS 14.0, iOS 17.0, *) {
                switch kind {
                    case .aiFileVisibility:
                        content.popoverTip(AIFileVisibilityDiscoveryTip())
                    case .lockFile:
                        content.popoverTip(LockFileDiscoveryTip())
                }
            } else {
                content
            }
#else
            content
#endif
        } else {
            content
        }
    }
}

#if canImport(TipKit)
@available(macOS 14.0, iOS 17.0, *)
private struct AIFileVisibilityDiscoveryTip: Tip {
    var title: Text {
        Text(.localizable(.featureTipsAIFileVisibilityTitle))
    }

    var message: Text? {
        Text(.localizable(.featureTipsAIFileVisibilityMessage))
    }

    var image: Image? {
        Image(systemName: "eye.slash")
    }
}

@available(macOS 14.0, iOS 17.0, *)
private struct LockFileDiscoveryTip: Tip {
    var title: Text {
        Text(.localizable(.featureTipsLockFileTitle))
    }

    var message: Text? {
        Text(.localizable(.featureTipsLockFileMessage))
    }

    var image: Image? {
        Image(systemName: "lock.shield")
    }
}
#endif
