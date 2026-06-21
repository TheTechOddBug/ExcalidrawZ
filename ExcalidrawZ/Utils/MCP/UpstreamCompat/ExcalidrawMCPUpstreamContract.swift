//
//  ExcalidrawMCPUpstreamContract.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/15.
//

import Foundation

/// Compatibility surface intentionally mirrored from
/// `excalidraw/excalidraw-mcp`.
///
/// Keep this file focused on the external tool contract: names, schemas,
/// size limits, prompt/reference text ownership, and pseudo-element semantics.
/// ExcalidrawZ-specific transport, UI presentation, file access, and security
/// policy should live outside `UpstreamCompat`.
enum ExcalidrawMCPUpstreamContract {
    /// Source tracked by our drift checker. Update only after reviewing
    /// upstream changes and deciding that ExcalidrawZ should follow them.
    static let upstreamRepository = "excalidraw/excalidraw-mcp"
    static let upstreamBranch = "main"
    static let upstreamServerPath = "src/server.ts"
    static let upstreamManifestPath = "manifest.json"
    static let upstreamPackagePath = "package.json"

    /// Mirrors upstream manifest/package metadata inspected by the drift check.
    static let upstreamPackageName = "@mcp-demos/excalidraw-server"
    static let upstreamAppName = "excalidraw-mcp-app"
    static let upstreamVersion = "0.3.2"

    /// Mirrors upstream's current element/data string limit.
    static let maxInputBytes = 5 * 1024 * 1024

    static let protocolVersion = "2025-03-26"

    enum ToolName {
        static let readMe = "read_me"
        static let createView = "create_view"
        static let saveCheckpoint = "save_checkpoint"
        static let readCheckpoint = "read_checkpoint"
        static let exportToExcalidraw = "export_to_excalidraw"
    }

    enum PseudoElementType {
        static let cameraUpdate = "cameraUpdate"
        static let delete = "delete"
        static let restoreCheckpoint = "restoreCheckpoint"
    }
}
