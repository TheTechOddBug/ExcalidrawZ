//
//  ExcalidrawCore+ConnectionHelpers.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    @MainActor
    func connectElements(
        from: String,
        to: String,
        arrow: JSONValue? = nil,
        captureUpdate: CaptureUpdate? = nil
    ) async throws -> ConnectElementsResult {
        guard !self.webView.isLoading else {
            throw InvalidJavaScriptResult()
        }
        let params = ConnectElementsParams(
            from: from,
            to: to,
            arrow: arrow,
            captureUpdate: captureUpdate
        )
        let paramsJSON = try encodeJSON(params)
        let result = try await webView.callAsyncJavaScript(
            makeJavaScriptHelperCall(
                "window.excalidrawZHelper.connectElements(\(paramsJSON))"
            ),
            arguments: [:],
            contentWorld: .page
        )
        let connectResult = try decodeJavaScriptHelperResult(result, as: ConnectElementsResult.self)
        documentSyncController.scheduleProgrammaticMutationCommit(reason: "connectElements")
        return connectResult
    }
}
