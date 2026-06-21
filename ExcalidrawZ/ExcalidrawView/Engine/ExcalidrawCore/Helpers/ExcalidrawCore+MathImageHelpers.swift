//
//  ExcalidrawCore+MathImageHelpers.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    @MainActor
    func createMathImage(
        params: MathImageParams
    ) async throws -> MathImageResult {
        guard !self.webView.isLoading else {
            throw InvalidJavaScriptResult()
        }
        let paramsJSON = try encodeJSON(params)
        let result = try await webView.callAsyncJavaScript(
            makeJavaScriptHelperCall(
                "window.excalidrawZHelper.createMathImage(\(paramsJSON))"
            ),
            arguments: [:],
            contentWorld: .page
        )
        return try decodeJavaScriptHelperResult(result, as: MathImageResult.self)
    }

    @MainActor
    func insertMathImage(
        params: MathImageParams,
        options: MathImageOptions = .init()
    ) async throws -> MathImageResult {
        guard !self.webView.isLoading else {
            throw InvalidJavaScriptResult()
        }
        let paramsJSON = try encodeJSON(params)
        let optionsJSON = try encodeJSON(options)
        let result = try await webView.callAsyncJavaScript(
            makeJavaScriptHelperCall(
                """
                (async () => {
                    const helper = window.excalidrawZHelper;
                    if (!helper) {
                        throw new Error("excalidrawZHelper is unavailable.");
                    }
                    const params = \(paramsJSON);
                    const options = \(optionsJSON);
                    if (typeof helper.insertMathImage === "function") {
                        return await helper.insertMathImage(params, options);
                    }
                    if (typeof helper.loadImageBuffer === "function" && params.svg) {
                        const bytes = Array.from(new TextEncoder().encode(params.svg));
                        const legacyResult = await helper.loadImageBuffer(bytes, "svg+xml");
                        return { ...legacyResult, usedLegacyFallback: true };
                    }
                    throw new Error("insertMathImage is unavailable.");
                })()
                """
            ),
            arguments: [:],
            contentWorld: .page
        )
        let insertResult = try decodeJavaScriptHelperResult(result, as: MathImageResult.self)
        documentSyncController.scheduleProgrammaticMutationCommit(reason: "insertMathImage")
        return insertResult
    }

    @MainActor
    func updateMathImage(
        elementId: String,
        params: MathImageParams,
        options: MathImageOptions = .init()
    ) async throws -> MathImageResult {
        guard !self.webView.isLoading else {
            throw InvalidJavaScriptResult()
        }
        let elementIdJSON = try encodeJSON(elementId)
        let paramsJSON = try encodeJSON(params)
        let optionsJSON = try encodeJSON(options)
        let result = try await webView.callAsyncJavaScript(
            makeJavaScriptHelperCall(
                "window.excalidrawZHelper.updateMathImage(\(elementIdJSON), \(paramsJSON), \(optionsJSON))"
            ),
            arguments: [:],
            contentWorld: .page
        )
        let updateResult = try decodeJavaScriptHelperResult(result, as: MathImageResult.self)
        documentSyncController.scheduleProgrammaticMutationCommit(reason: "updateMathImage")
        return updateResult
    }
}
