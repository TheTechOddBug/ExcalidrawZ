//
//  ExcalidrawCore+FontHelpers.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    @MainActor
    public func setAvailableFonts(fontFamilies: [String]) async throws {
        guard !self.webView.isLoading else { return }
        let payload = try encodeJSON(fontFamilies)
        for attempt in 0..<5 {
            let result = try await webView.callAsyncJavaScript(
                """
                if (window.excalidrawZHelper?.setAvailableFonts) {
                    window.excalidrawZHelper.setAvailableFonts(\(payload));
                    return true;
                }
                return false;
                """,
                arguments: [:],
                contentWorld: .page
            )
            if let applied = result as? Bool, applied {
                return
            }
            if attempt < 4 {
                try await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        throw InvalidJavaScriptResult()
    }
}
