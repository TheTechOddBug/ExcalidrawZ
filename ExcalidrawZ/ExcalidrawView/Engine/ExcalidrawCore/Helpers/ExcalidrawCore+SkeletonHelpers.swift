//
//  ExcalidrawCore+SkeletonHelpers.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    @MainActor
    func insertFromSkeleton(
        _ skeletons: JSONValue,
        options: SkeletonInsertOptions = .init()
    ) async throws -> SkeletonInsertResult {
        guard !self.webView.isLoading else {
            throw InvalidJavaScriptResult()
        }
        let mediaFiles = try resourceFiles(from: options.files)
        if !mediaFiles.isEmpty {
            try await insertMediaFiles(mediaFiles)
        }
        let skeletonsJSON = try encodeJSON(skeletons)
        let optionsJSON = try encodeJSON(options)
        let result = try await webView.callAsyncJavaScript(
            makeJavaScriptHelperCall(
                "window.excalidrawZHelper.insertFromSkeleton(\(skeletonsJSON), \(optionsJSON))"
            ),
            arguments: [:],
            contentWorld: .page
        )
        let insertResult = try decodeJavaScriptHelperResult(result, as: SkeletonInsertResult.self)
        documentSyncController.scheduleProgrammaticMutationCommit(reason: "insertFromSkeleton")
        return insertResult
    }

    private func resourceFiles(
        from files: [String: JSONValue]?
    ) throws -> [ExcalidrawFile.ResourceFile] {
        guard let files, !files.isEmpty else { return [] }
        return try files.map { fileID, value in
            try ExcalidrawFile.ResourceFile(jsonValue: value, fallbackID: fileID)
        }
    }
}
