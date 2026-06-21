//
//  ExcalidrawCore+NativeViewportInsets.swift
//  ExcalidrawZ
//
//  Pushes native toolbar/overlay insets to the Web canvas. The Web side should
//  apply these to Excalidraw UI chrome only; the drawing surface can still live
//  underneath native glass.
//

import Foundation

extension ExcalidrawCore {
    @MainActor
    func setNativeViewportInsets(_ insets: ExcalidrawNativeViewportInsets) async throws {
        guard !self.isLoading else { return }
        let payload = try insets.jsonStringified()
        _ = try await webView.callAsyncJavaScript(
            """
            const helper = window.excalidrawZHelper;
            if (helper && typeof helper.setNativeViewportInsets === "function") {
                helper.setNativeViewportInsets(\(payload));
            }
            """,
            arguments: [:],
            contentWorld: .page
        )
    }
}
