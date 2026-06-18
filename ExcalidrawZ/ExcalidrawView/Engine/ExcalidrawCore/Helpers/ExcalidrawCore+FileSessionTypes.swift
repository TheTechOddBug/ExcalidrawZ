//
//  ExcalidrawCore+FileSessionTypes.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawCore {
    /// One-time copy of the current editor scene at the moment it was requested.
    /// This is not a persistent/live reference and must not drive autosave.
    struct CurrentFileSnapshot: Codable, Hashable {
        var dataString: String
        var elements: [JSONValue]
        var appState: JSONValue
        var files: [String: JSONValue]
    }
}
