//
//  ExcalidrawCore+ConnectionTypes.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    struct ConnectElementsParams: Codable, Hashable {
        var from: String
        var to: String
        var arrow: JSONValue?
        var captureUpdate: CaptureUpdate?
    }

    struct ConnectElementsResult: Codable, Hashable {
        var arrowId: String
        var labelId: String?
    }
}
