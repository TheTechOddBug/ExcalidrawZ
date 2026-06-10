//
//  AIImagePayloadOptimizer.swift
//  ExcalidrawZ
//

import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum AIImagePayloadOptimizer {
    struct Payload {
        let data: Data
        let mimeType: String
    }

    private enum Policy {
        static let maxLongEdge: CGFloat = 2048
        static let fallbackLongEdges: [CGFloat] = [2048, 1536, 1280, 1024]
        static let preferredMaxBytes = 1_500_000
        static let jpegQualities: [CGFloat] = [0.82, 0.72, 0.62]
    }

#if canImport(AppKit)
    static func optimize(_ image: NSImage) -> Payload? {
        guard let sourceImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let hasAlpha = cgImageHasAlpha(sourceImage)

        if hasAlpha,
           let resized = resizedCGImage(sourceImage, maxLongEdge: Policy.maxLongEdge, keepsAlpha: true),
           let data = pngData(from: resized),
           data.count <= Policy.preferredMaxBytes {
            return Payload(data: data, mimeType: "image/png")
        }

        return bestJPEGPayload(from: sourceImage)
    }
#elseif canImport(UIKit)
    static func optimize(_ image: UIImage) -> Payload? {
        let hasAlpha = uiImageHasAlpha(image)

        if hasAlpha,
           let resized = resizedUIImage(image, maxLongEdge: Policy.maxLongEdge, keepsAlpha: true),
           let data = resized.pngData(),
           data.count <= Policy.preferredMaxBytes {
            return Payload(data: data, mimeType: "image/png")
        }

        return bestJPEGPayload(from: image)
    }
#endif

    static func optimize(data: Data, mimeType: String?) -> Payload? {
        guard isOptimizableImageMIMEType(mimeType) else { return nil }
#if canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return optimize(image)
#elseif canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return optimize(image)
#else
        return nil
#endif
    }

    static func dataURL(from payload: Payload) -> String {
        "data:\(payload.mimeType);base64,\(payload.data.base64EncodedString())"
    }

    private static func isOptimizableImageMIMEType(_ mimeType: String?) -> Bool {
        switch mimeType?.lowercased() {
            case "image/png", "image/jpeg", "image/jpg", "image/heic", "image/heif", "image/tiff":
                return true
            default:
                return false
        }
    }

#if canImport(AppKit)
    private static func bestJPEGPayload(from sourceImage: CGImage) -> Payload? {
        var fallback: Data?
        for longEdge in Policy.fallbackLongEdges {
            guard let resized = resizedCGImage(sourceImage, maxLongEdge: longEdge, keepsAlpha: false) else {
                continue
            }
            for quality in Policy.jpegQualities {
                guard let data = jpegData(from: resized, quality: quality) else { continue }
                fallback = data
                if data.count <= Policy.preferredMaxBytes {
                    return Payload(data: data, mimeType: "image/jpeg")
                }
            }
        }
        return fallback.map { Payload(data: $0, mimeType: "image/jpeg") }
    }

    private static func resizedCGImage(
        _ sourceImage: CGImage,
        maxLongEdge: CGFloat,
        keepsAlpha: Bool
    ) -> CGImage? {
        let sourceWidth = CGFloat(sourceImage.width)
        let sourceHeight = CGFloat(sourceImage.height)
        let sourceLongEdge = max(sourceWidth, sourceHeight)
        let scale = min(1, maxLongEdge / max(sourceLongEdge, 1))
        let targetWidth = max(1, Int((sourceWidth * scale).rounded()))
        let targetHeight = max(1, Int((sourceHeight * scale).rounded()))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let alphaInfo: CGImageAlphaInfo = keepsAlpha ? .premultipliedLast : .noneSkipLast
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: alphaInfo.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        if !keepsAlpha {
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        }
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage()
    }

    private static func pngData(from image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    private static func jpegData(from image: CGImage, quality: CGFloat) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(
            using: .jpeg,
            properties: [.compressionFactor: NSNumber(value: Double(quality))]
        )
    }

    private static func cgImageHasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
            case .first, .last, .premultipliedFirst, .premultipliedLast:
                return true
            default:
                return false
        }
    }
#elseif canImport(UIKit)
    private static func bestJPEGPayload(from image: UIImage) -> Payload? {
        var fallback: Data?
        for longEdge in Policy.fallbackLongEdges {
            guard let resized = resizedUIImage(image, maxLongEdge: longEdge, keepsAlpha: false) else {
                continue
            }
            for quality in Policy.jpegQualities {
                guard let data = resized.jpegData(compressionQuality: quality) else { continue }
                fallback = data
                if data.count <= Policy.preferredMaxBytes {
                    return Payload(data: data, mimeType: "image/jpeg")
                }
            }
        }
        return fallback.map { Payload(data: $0, mimeType: "image/jpeg") }
    }

    private static func resizedUIImage(
        _ image: UIImage,
        maxLongEdge: CGFloat,
        keepsAlpha: Bool
    ) -> UIImage? {
        let sourcePixelSize = orientedPixelSize(for: image)
        let sourceLongEdge = max(sourcePixelSize.width, sourcePixelSize.height)
        let scale = min(1, maxLongEdge / max(sourceLongEdge, 1))
        let targetSize = CGSize(
            width: max(1, (sourcePixelSize.width * scale).rounded()),
            height: max(1, (sourcePixelSize.height * scale).rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !keepsAlpha
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            if !keepsAlpha {
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: targetSize))
            }
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private static func orientedPixelSize(for image: UIImage) -> CGSize {
        guard let cgImage = image.cgImage else {
            return CGSize(
                width: image.size.width * image.scale,
                height: image.size.height * image.scale
            )
        }

        let size = CGSize(width: cgImage.width, height: cgImage.height)
        switch image.imageOrientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                return CGSize(width: size.height, height: size.width)
            default:
                return size
        }
    }

    private static func uiImageHasAlpha(_ image: UIImage) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else { return false }
        switch alphaInfo {
            case .first, .last, .premultipliedFirst, .premultipliedLast:
                return true
            default:
                return false
        }
    }
#endif
}
