//
//  ExcalidrawCore+PageCommandHelpers.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    @MainActor
    func reload() {
        Task {
            _ = try? await webView.callAsyncJavaScript(
                "location.reload();",
                arguments: [:],
                contentWorld: .page
            )
        }
    }

    @MainActor
    func toggleWebPointerEvents(enabled: Bool) async throws {
        _ = try await webView.callAsyncJavaScript(
            "document.body.style = '\(enabled ? "" : "pointer-events: none;")';",
            arguments: [:],
            contentWorld: .page
        )
    }
}
