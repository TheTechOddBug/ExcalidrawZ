//
//  ExcalidrawCore+AICameraHelpers.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    @MainActor
    func beginAICameraSession(options: AICameraSessionOptions = .init()) async throws -> AICameraBeginResponse {
        guard !self.webView.isLoading else {
            throw InvalidJavaScriptResult()
        }
        let optionsJSON = try encodeJSON(options)
        let result = try await webView.callAsyncJavaScript(
            "return JSON.stringify(window.excalidrawZHelper.beginAICameraSession(\(optionsJSON)));",
            arguments: [:],
            contentWorld: .page
        )
        let response = try decodeJavaScriptResult(result, as: AICameraBeginResponse.self)
        updateAICameraSession(.init(
            sessionId: response.sessionId,
            state: response.state,
            startedAt: response.startedAt
        ))
        return response
    }

    @MainActor
    func updateAICameraTarget(
        sessionId: String,
        target: AICameraTarget,
        options: AICameraSessionOptions = .init()
    ) async throws -> AICameraUpdateResponse {
        guard !self.webView.isLoading else {
            return .init(accepted: false, state: nil, reason: "webview_loading")
        }
        let sessionIdJSON = try encodeJSON(sessionId)
        let targetJSON = try encodeJSON(target)
        let optionsJSON = try encodeJSON(options)
        let result = try await webView.callAsyncJavaScript(
            "return JSON.stringify(window.excalidrawZHelper.updateAICameraTarget(\(sessionIdJSON), \(targetJSON), \(optionsJSON)));",
            arguments: [:],
            contentWorld: .page
        )
        return try decodeJavaScriptResult(result, as: AICameraUpdateResponse.self)
    }

    @MainActor
    func endAICameraSession(
        sessionId: String,
        options: AICameraEndOptions = .init()
    ) async throws {
        guard !self.webView.isLoading else { return }
        let sessionIdJSON = try encodeJSON(sessionId)
        let optionsJSON = try encodeJSON(options)
        _ = try await webView.callAsyncJavaScript(
            "window.excalidrawZHelper.endAICameraSession(\(sessionIdJSON), \(optionsJSON));",
            arguments: [:],
            contentWorld: .page
        )
    }

    @MainActor
    func cancelAICameraSession(sessionId: String) async throws {
        guard !self.webView.isLoading else { return }
        let sessionIdJSON = try encodeJSON(sessionId)
        _ = try await webView.callAsyncJavaScript(
            "window.excalidrawZHelper.cancelAICameraSession(\(sessionIdJSON));",
            arguments: [:],
            contentWorld: .page
        )
    }

    @MainActor
    func interruptAICameraSession(
        sessionId: String,
        options: AICameraInterruptOptions = .init()
    ) async throws {
        guard !self.webView.isLoading else { return }
        let sessionIdJSON = try encodeJSON(sessionId)
        let optionsJSON = try encodeJSON(options)
        _ = try await webView.callAsyncJavaScript(
            "window.excalidrawZHelper.interruptAICameraSession(\(sessionIdJSON), \(optionsJSON));",
            arguments: [:],
            contentWorld: .page
        )
    }

    @MainActor
    func getAICameraSession(sessionId: String? = nil) async throws -> AICameraSessionInfo? {
        guard !self.webView.isLoading else {
            return aiCameraSession.sessionId == nil ? nil : aiCameraSession
        }
        let body: String
        if let sessionId {
            let sessionIdJSON = try encodeJSON(sessionId)
            body = "return JSON.stringify(window.excalidrawZHelper.getAICameraSession(\(sessionIdJSON)));"
        } else {
            body = "return JSON.stringify(window.excalidrawZHelper.getAICameraSession());"
        }
        let result = try await webView.callAsyncJavaScript(
            body,
            arguments: [:],
            contentWorld: .page
        )
        guard !(result is NSNull) else { return nil }
        if let string = result as? String, string == "null" {
            return nil
        }
        let session = try decodeJavaScriptResult(result, as: AICameraSessionInfo.self)
        updateAICameraSession(session)
        return session
    }
}
