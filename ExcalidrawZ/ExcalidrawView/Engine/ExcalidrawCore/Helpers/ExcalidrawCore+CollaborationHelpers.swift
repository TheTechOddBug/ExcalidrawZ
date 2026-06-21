//
//  ExcalidrawCore+CollaborationHelpers.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

typealias CollaborationInfo = ExcalidrawCore.CollaborationInfo

extension ExcalidrawCore {
    struct CollaborationInfo: Codable, Hashable {
        var username: String
    }

    @MainActor
    public func openCollabMode() async throws {
        _ = try await webView.callAsyncJavaScript(
            "window.excalidrawZHelper.openCollabMode();",
            arguments: [:],
            contentWorld: .page
        )
    }

    @MainActor
    public func getCollaborationInfo() async throws -> CollaborationInfo {
        let res = try await webView.callAsyncJavaScript(
            "return window.excalidrawZHelper.getExcalidrawCollabInfo();",
            arguments: [:],
            contentWorld: .page
        )
        guard let res, JSONSerialization.isValidJSONObject(res) else {
            return CollaborationInfo(username: "")
        }
        let data = try JSONSerialization.data(withJSONObject: res)
        return try JSONDecoder().decode(CollaborationInfo.self, from: data)
    }

    @MainActor
    public func setCollaborationInfo(_ info: CollaborationInfo) async throws {
        _ = try await webView.callAsyncJavaScript(
            "window.excalidrawZHelper.setExcalidrawCollabInfo(\(info.jsonStringified()));",
            arguments: [:],
            contentWorld: .page
        )
    }

    @MainActor
    public func followCollborator(_ collaborator: Collaborator) async throws {
        _ = try await webView.callAsyncJavaScript(
            "window.excalidrawZHelper.followCollaborator(\(collaborator.jsonStringified()));",
            arguments: [:],
            contentWorld: .page
        )
    }
}
