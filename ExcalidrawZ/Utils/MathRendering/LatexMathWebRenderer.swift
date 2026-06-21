//
//  LatexMathWebRenderer.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/20.
//

import Foundation
import WebKit

@MainActor
final class LatexMathWebRenderer: NSObject {
    static let shared = LatexMathWebRenderer()

    private var webView: WKWebView?
    private var isReady = false
    private var preparationTask: Task<Void, Error>?
    private var loadContinuation: CheckedContinuation<Void, Error>?

    private override init() {
        super.init()
    }

    func render(_ request: MathLatexRenderRequest) async throws -> MathRenderedSVG {
        let trimmed = request.latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LatexMathRenderError.emptyInput
        }

        try await prepareWebView()

        let requestData = try JSONEncoder().encode(
            LatexMathWebRenderRequest(
                latex: trimmed,
                foregroundColor: request.foregroundColor
            )
        )
        guard let requestJSONString = String(data: requestData, encoding: .utf8) else {
            throw LatexMathRenderError.invalidRequest
        }

        let script = """
        window.ExcalidrawZLatexRenderer.renderLatex(\(requestJSONString))
        """

        guard let result = try await evaluateJavaScript(script) as? [String: Any],
              let rawSVG = result["svg"] as? String else {
            throw LatexMathRenderError.invalidRenderResult
        }

        let svg = request.foregroundColor.map {
            Self.applyForegroundColor($0, to: rawSVG)
        } ?? rawSVG

        return MathRenderedSVG(
            source: trimmed,
            svg: svg,
            renderer: "mathjax",
            width: number(from: result["width"]),
            height: number(from: result["height"])
        )
    }

    private func prepareWebView() async throws {
        if isReady {
            return
        }

        if let preparationTask {
            try await preparationTask.value
            return
        }

        let task = Task { @MainActor in
            try await loadRuntime()
        }
        preparationTask = task
        defer { preparationTask = nil }
        try await task.value
    }

    private func loadRuntime() async throws {
        if webView == nil {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            let webView = WKWebView(frame: .init(x: 0, y: 0, width: 1, height: 1), configuration: configuration)
            webView.navigationDelegate = self
            self.webView = webView
        }

        guard let runtimeURL = mathJaxRuntimeURL,
              let webView else {
            throw LatexMathRenderError.missingMathJaxRuntime
        }

        try await withCheckedThrowingContinuation { continuation in
            loadContinuation = continuation
            webView.loadHTMLString(
                Self.runtimeHTML(scriptName: runtimeURL.lastPathComponent),
                baseURL: runtimeURL.deletingLastPathComponent()
            )
        }

        isReady = true
    }

    private var mathJaxRuntimeURL: URL? {
        Bundle.main.url(
            forResource: "mathjax-svg-3.2.2",
            withExtension: "js",
            subdirectory: "MathRendering"
        )
        ?? Bundle.main.url(
            forResource: "mathjax-svg-3.2.2",
            withExtension: "js"
        )
    }

    private func evaluateJavaScript(_ script: String) async throws -> Any? {
        guard let webView else {
            throw LatexMathRenderError.webViewUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }

    private func number(from value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        return nil
    }

    private static func applyForegroundColor(_ color: String, to svg: String) -> String {
        var svg = svg
        svg = svg.replacingOccurrences(of: #"fill="currentColor""#, with: #"fill="\#(color)""#)
        svg = svg.replacingOccurrences(of: #"stroke="currentColor""#, with: #"stroke="\#(color)""#)

        guard let svgStart = svg.range(of: "<svg"),
              let tagEnd = svg[svgStart.upperBound...].firstIndex(of: ">") else {
            return svg
        }

        let tagRange = svgStart.lowerBound...tagEnd
        var tag = String(svg[tagRange])
        if let styleRange = tag.range(of: #"style="[^"]*""#, options: .regularExpression) {
            let styleAttribute = String(tag[styleRange])
            let style = styleAttribute
                .dropFirst(#"style=""#.count)
                .dropLast()
                .replacingOccurrences(
                    of: #"(^|;)\s*(color|fill)\s*:\s*[^;]*;?"#,
                    with: "$1",
                    options: .regularExpression
                )
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let separator = style.isEmpty ? "" : " "
            tag.replaceSubrange(styleRange, with: #"style="color: \#(color); fill: \#(color);\#(separator)\#(style)""#)
        } else {
            tag.insert(contentsOf: #" style="color: \#(color); fill: \#(color);""#, at: tag.index(before: tag.endIndex))
        }

        if let fillRange = tag.range(of: #"\sfill="[^"]*""#, options: .regularExpression) {
            tag.replaceSubrange(fillRange, with: #" fill="\#(color)""#)
        } else {
            tag.insert(contentsOf: #" fill="\#(color)""#, at: tag.index(before: tag.endIndex))
        }

        svg.replaceSubrange(tagRange, with: tag)
        return svg
    }

    private static func runtimeHTML(scriptName: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                html, body {
                    width: 100%;
                    height: 100%;
                    margin: 0;
                    padding: 0;
                    overflow: hidden;
                    background: transparent;
                }
            </style>
            <script src="\(scriptName)"></script>
        </head>
        <body>
            <script>
                window.ExcalidrawZLatexRenderer = {
                    renderLatex(request) {
                        if (!window.svg || !window.svg.SVGConverter) {
                            throw new Error("MathJax SVG runtime is unavailable.");
                        }

                        const latex = String(request.latex || "").trim();
                        if (!latex) {
                            throw new Error("Enter a LaTeX math expression.");
                        }

                        const results = window.svg.SVGConverter.tex2svg(
                            [latex],
                            false,
                            false,
                            false,
                            true,
                            {
                                display: true,
                                em: 16,
                                ex: 8,
                                containerWidth: 640,
                                lineWidth: 100000,
                                scale: 1
                            },
                            {
                                enableAssistiveMml: false,
                                enableMenu: false
                            },
                            {
                                loadPackages: [
                                    "base",
                                    "ams",
                                    "autoload",
                                    "cases",
                                    "color",
                                    "empheq",
                                    "mathtools",
                                    "newcommand",
                                    "noundefined",
                                    "require"
                                ]
                            },
                            {
                                fontCache: "local",
                                internalSpeechTitles: true
                            }
                        );

                        const svgText = Array.isArray(results) ? results[0] : results;
                        if (typeof svgText !== "string" || svgText.length === 0) {
                            throw new Error("MathJax did not produce an SVG.");
                        }

                        const parser = new DOMParser();
                        const document = parser.parseFromString(svgText, "image/svg+xml");
                        const parserError = document.querySelector("parsererror");
                        if (parserError) {
                            throw new Error(parserError.textContent || "MathJax produced invalid SVG.");
                        }

                        const svgElement = document.documentElement;
                        if (!svgElement || svgElement.nodeName.toLowerCase() !== "svg") {
                            throw new Error("MathJax did not produce an SVG.");
                        }

                        const mathError = svgElement.querySelector("[data-mjx-error]");
                        if (mathError) {
                            throw new Error(mathError.getAttribute("data-mjx-error") || mathError.textContent || "Invalid LaTeX.");
                        }

                        svgElement.setAttribute("xmlns", "http://www.w3.org/2000/svg");
                        const width = this.pixelLength(svgElement.getAttribute("width"));
                        const height = this.pixelLength(svgElement.getAttribute("height"));
                        if (width !== null) {
                            svgElement.setAttribute("width", `${width}px`);
                        }
                        if (height !== null) {
                            svgElement.setAttribute("height", `${height}px`);
                        }

                        return {
                            svg: new XMLSerializer().serializeToString(svgElement),
                            width,
                            height
                        };
                    },

                    pixelLength(value) {
                        if (!value) {
                            return null;
                        }
                        const match = String(value).trim().match(/^([0-9]+(?:\\.[0-9]+)?)(px|em|ex|pt)?$/i);
                        if (!match) {
                            return null;
                        }

                        const number = Number(match[1]);
                        const unit = (match[2] || "px").toLowerCase();
                        switch (unit) {
                            case "px":
                                return number;
                            case "em":
                                return number * 16;
                            case "ex":
                                return number * 8;
                            case "pt":
                                return number * 96 / 72;
                            default:
                                return null;
                        }
                    }
                };
            </script>
        </body>
        </html>
        """
    }
}

extension LatexMathWebRenderer: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            loadContinuation?.resume(returning: ())
            loadContinuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            loadContinuation?.resume(throwing: error)
            loadContinuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            loadContinuation?.resume(throwing: error)
            loadContinuation = nil
        }
    }
}

private struct LatexMathWebRenderRequest: Encodable {
    var latex: String
    var foregroundColor: String?
}

private enum LatexMathRenderError: LocalizedError {
    case emptyInput
    case invalidRequest
    case invalidRenderResult
    case missingMathJaxRuntime
    case webViewUnavailable

    var errorDescription: String? {
        switch self {
            case .emptyInput:
                "Enter a LaTeX math expression."
            case .invalidRequest:
                "LaTeX render request could not be encoded."
            case .invalidRenderResult:
                "LaTeX renderer returned an invalid result."
            case .missingMathJaxRuntime:
                "MathJax SVG runtime is missing from the app bundle."
            case .webViewUnavailable:
                "LaTeX renderer is unavailable."
        }
    }
}
