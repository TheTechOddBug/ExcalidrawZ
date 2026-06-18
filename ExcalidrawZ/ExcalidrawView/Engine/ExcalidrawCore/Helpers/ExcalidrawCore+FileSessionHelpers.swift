//
//  ExcalidrawCore+FileSessionHelpers.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    /// Save `currentFile` or creating if neccessary.
    ///
    /// This function will get the local storage of `excalidraw.com`.
    /// Then it will set the data got from local storage to `currentFile`.
    /// Returns `{ dataString, elementCount }` from the JS side.
    @MainActor
    @discardableResult
    func saveCurrentFile() async throws -> SaveFileResult? {
        let raw = try await self.webView.callAsyncJavaScript(
            "return await window.excalidrawZHelper.saveFile();",
            arguments: [:],
            contentWorld: .page
        )
        return SaveFileResult(fromJS: raw)
    }

    /// Returns a one-time snapshot copy of the current live canvas without
    /// participating in the persistence/autosave flow. Use this for AI tools
    /// and debug reads that need editor state newer than the throttled
    /// `onStateChanged` broadcast.
    @MainActor
    func getCurrentFileSnapshot() async throws -> CurrentFileSnapshot {
        guard !self.webView.isLoading else {
            throw InvalidJavaScriptResult()
        }
        let result = try await self.webView.callAsyncJavaScript(
            "return JSON.stringify(await window.excalidrawZHelper.getCurrentFileSnapshot());",
            arguments: [:],
            contentWorld: .page
        )
        return try decodeJavaScriptResult(result, as: CurrentFileSnapshot.self)
    }

    /// `true` if is dark mode.
    @MainActor
    func getIsDark() async throws -> Bool {
        if self.webView.isLoading { return false }
        let res = try await self.webView.callAsyncJavaScript(
            "return window.excalidrawZHelper.getIsDark();",
            arguments: [:],
            contentWorld: .page
        )
        if let isDark = res as? Bool {
            return isDark
        } else {
            return false
        }
    }

    @MainActor
    func changeColorMode(dark: Bool) async throws {
        if self.webView.isLoading { return }
        let isDark = try await getIsDark()
        guard isDark != dark else { return }
        _ = try await webView.callAsyncJavaScript(
            "window.excalidrawZHelper.toggleColorTheme(\"\(dark ? "dark" : "light")\");",
            arguments: [:],
            contentWorld: .page
        )
    }

    @MainActor
    @discardableResult
    func loadLibraryItem(item: ExcalidrawLibrary) async throws -> LoadLibraryItemResult? {
        let libraryItemsJSON = try item.libraryItems.jsonStringified()
        let raw = try await self.webView.callAsyncJavaScript(
            "return await window.excalidrawZHelper.loadLibraryItem(\(libraryItemsJSON));",
            arguments: [:],
            contentWorld: .page
        )
        return LoadLibraryItemResult(fromJS: raw)
    }
}
