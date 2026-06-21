//
//  ExcalidrawCore+ExportHelpers.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation
import SwiftUI

extension ExcalidrawCore {
    @MainActor
    func exportPNG() async throws {
        _ = try await webView.callAsyncJavaScript(
            "window.excalidrawZHelper.exportImage();",
            arguments: [:],
            contentWorld: .page
        )
    }

    func exportPNGData() async throws -> Data? {
        guard let file = await self.parent?.file else {
            return nil
        }
        let imageData = try await self.exportElementsToPNGData(
            elements: file.elements,
            files: file.files,
            colorScheme: .light
        )
        return imageData
    }

    func exportPDFData(
        withBackground: Bool = true,
        colorScheme: ColorScheme = .light
    ) async throws -> Data? {
        guard let file = await self.parent?.file else {
            return nil
        }
        return try await exportElementsToPDFData(
            elements: file.elements,
            files: file.files,
            withBackground: withBackground,
            colorScheme: colorScheme
        )
    }

    func exportElementsToPNGData(
        elements: [ExcalidrawElement],
        files: [String : ExcalidrawFile.ResourceFile]? = nil,
        embedScene: Bool = false,
        withBackground: Bool = true,
        colorScheme: ColorScheme,
        exportScale: Int = 1
    ) async throws -> Data {
        let elementsJSON = try elements.jsonStringified()
        let filesJSON = try files?.jsonStringified() ?? "undefined"
        let script = """
        return await window.excalidrawZHelper.exportElementsToBlob(
            \(elementsJSON), \(filesJSON), {
                exportEmbedScene: \(embedScene),
                withBackground: \(withBackground),
                exportWithDarkMode: \(colorScheme == .dark),
                mimeType: 'image/png',
                quality: 100,
                exportScale: \(exportScale)
            }
        );
        """
        let raw = try await webView.callAsyncJavaScript(
            script,
            arguments: [:],
            contentWorld: .page
        )
        guard let dict = raw as? [String: Any],
              let dataString = dict["blobData"] as? String,
              let data = Data(base64Encoded: dataString) else {
            struct DecodeImageFailed: Error {}
            throw DecodeImageFailed()
        }
        return data
    }

    func exportElementsToPNG(
        elements: [ExcalidrawElement],
        embedScene: Bool = false,
        files: [String : ExcalidrawFile.ResourceFile]? = nil,
        withBackground: Bool = true,
        colorScheme: ColorScheme,
        exportScale: Int = 1
    ) async throws -> PlatformImage {
        let data = try await self.exportElementsToPNGData(
            elements: elements,
            files: files,
            embedScene: embedScene,
            withBackground: withBackground,
            colorScheme: colorScheme,
            exportScale: exportScale
        )
        guard let image = PlatformImage(data: data) else {
            struct DecodeImageFailed: Error {}
            throw DecodeImageFailed()
        }
        return image
    }

    func exportElementsToSVGData(
        elements: [ExcalidrawElement],
        files: [String : ExcalidrawFile.ResourceFile]? = nil,
        embedScene: Bool = false,
        withBackground: Bool = true,
        colorScheme: ColorScheme
    ) async throws -> Data {
        let elementsJSON = try elements.jsonStringified()
        let filesJSON = try files?.jsonStringified() ?? "undefined"
        let script = """
        return await window.excalidrawZHelper.exportElementsToSvg(
            \(elementsJSON), \(filesJSON),
            \(embedScene), \(withBackground), \(colorScheme == .dark)
        );
        """
        let raw = try await webView.callAsyncJavaScript(
            script,
            arguments: [:],
            contentWorld: .page
        )
        guard let dict = raw as? [String: Any],
              let svg = dict["svg"] as? String else {
            struct ExportSVGFailed: Error {}
            throw ExportSVGFailed()
        }
        let minisizedSvg = removeWidthAndHeight(from: svg).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = minisizedSvg.data(using: .utf8) else {
            struct DecodeImageFailed: Error {}
            throw DecodeImageFailed()
        }
        return data
    }

    func exportElementsToPDFData(
        elements: [ExcalidrawElement],
        files: [String : ExcalidrawFile.ResourceFile]? = nil,
        embedScene: Bool = false,
        withBackground: Bool = true,
        colorScheme: ColorScheme
    ) async throws -> Data {
        let name = await parent?.file?.name ?? String(localizable: .generalUntitled)
        let svgData = try await exportElementsToSVGData(
            elements: elements,
            files: files,
            embedScene: embedScene,
            withBackground: withBackground,
            colorScheme: colorScheme
        )
        let svgURL = try getTempDirectory()
            .appendingPathComponent("\(UUID().uuidString).svg")
        try svgData.write(to: svgURL)
        return try await renderPDFData(from: svgURL, filename: name)
    }

    func exportElementsToSVG(
        elements: [ExcalidrawElement],
        files: [String : ExcalidrawFile.ResourceFile]? = nil,
        embedScene: Bool = false,
        withBackground: Bool = true,
        colorScheme: ColorScheme
    ) async throws -> PlatformImage {
        let data = try await exportElementsToSVGData(
            elements: elements,
            files: files,
            embedScene: embedScene,
            withBackground: withBackground,
            colorScheme: colorScheme
        )
        guard let image = PlatformImage(data: data) else {
            struct DecodeImageFailed: Error {}
            throw DecodeImageFailed()
        }
        return image
    }

    private func removeWidthAndHeight(from svgContent: String) -> String {
        let regexPattern = #"<svg([^>]*)\s+(width="[^"]*")\s*([^>]*)>"#

        do {
            let regex = try NSRegularExpression(pattern: regexPattern, options: [])
            let tempResult = regex.stringByReplacingMatches(
                in: svgContent,
                options: [],
                range: NSRange(location: 0, length: svgContent.utf16.count),
                withTemplate: "<svg$1 $3>"
            )

            let finalRegexPattern = #"<svg([^>]*)\s+(height="[^"]*")\s*([^>]*)>"#
            return try NSRegularExpression(pattern: finalRegexPattern, options: []).stringByReplacingMatches(
                in: tempResult,
                options: [],
                range: NSRange(location: 0, length: tempResult.utf16.count),
                withTemplate: "<svg$1 $3>"
            )
        } catch {
            logger.warning("Failed to rewrite SVG dimensions: \(error)")
            return svgContent
        }
    }
}
