//
//  ExcalidrawCore+ViewportTypes.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    struct CameraState: Codable, Hashable {
        var scrollX: Double = 0
        var scrollY: Double = 0
        var zoom: Double = 1
    }

    struct CameraPatch: Codable, Hashable {
        var scrollX: Double?
        var scrollY: Double?
        var zoom: Double?
    }

    struct ViewportFrame: Codable, Hashable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    struct CanvasPoint: Codable, Hashable {
        var x: Double
        var y: Double
    }

    struct CameraAnimationOptions: Codable, Hashable {
        var animate: Bool = true
        var duration: Int = 300
    }

    enum ScrollToElementMode: String, Codable, Hashable {
        case center
        case fitContent
        case fitViewport
    }

    struct ScrollToElementOptions: Codable, Hashable {
        var mode: ScrollToElementMode = .fitContent
        var animate: Bool = true
        var duration: Int = 300
        var viewportZoomFactor: Double?
        var minZoom: Double?
        var maxZoom: Double?
    }

    struct ZoomToFitOptions: Codable, Hashable {
        var animate: Bool = true
        var duration: Int = 300
        var viewportZoomFactor: Double = 0.9
    }
}
