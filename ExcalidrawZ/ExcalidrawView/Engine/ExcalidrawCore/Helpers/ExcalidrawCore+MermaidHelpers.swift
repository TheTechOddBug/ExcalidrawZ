//
//  ExcalidrawCore+MermaidHelpers.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    @MainActor
    func insertFromMermaid(
        _ definition: String,
        options: MermaidInsertOptions = .init()
    ) async throws -> MermaidInsertResult {
        guard !self.webView.isLoading else {
            throw InvalidJavaScriptResult()
        }
        let definitionJSON = try encodeJSON(definition)
        let optionsJSON = try encodeJSON(options)
        let result = try await webView.callAsyncJavaScript(
            makeJavaScriptHelperCall(
                "window.excalidrawZHelper.insertFromMermaid(\(definitionJSON), \(optionsJSON))"
            ),
            arguments: [:],
            contentWorld: .page
        )
        let insertResult = try decodeJavaScriptHelperResult(result, as: MermaidInsertResult.self)
        documentSyncController.scheduleProgrammaticMutationCommit(reason: "insertFromMermaid")
        return insertResult
    }

    @MainActor
    func convertMermaidToExcalidraw(
        _ definition: String,
        options: MermaidConvertOptions = .init()
    ) async throws -> MermaidConvertResult {
        guard !self.webView.isLoading else {
            throw InvalidJavaScriptResult()
        }
        let definitionJSON = try encodeJSON(definition)
        let optionsJSON = try encodeJSON(options)
        let result = try await webView.callAsyncJavaScript(
            makeJavaScriptHelperCall(
                "window.excalidrawZHelper.convertMermaidToExcalidraw(\(definitionJSON), \(optionsJSON))"
            ),
            arguments: [:],
            contentWorld: .page
        )
        return try decodeJavaScriptHelperResult(result, as: MermaidConvertResult.self)
    }
}
