//
//  ExcalidrawCore+MediaFileTypes.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/18.
//

import Foundation

extension ExcalidrawFile.ResourceFile {
    init(
        jsonValue: ExcalidrawCore.JSONValue,
        fallbackID: String
    ) throws {
        guard case .object(let object) = jsonValue else {
            throw ExcalidrawMediaFileDecodeError(
                fileID: fallbackID,
                reason: "entry is not an object"
            )
        }
        guard let mimeType = object.nonEmptyString(forKey: "mimeType") else {
            throw ExcalidrawMediaFileDecodeError(
                fileID: fallbackID,
                reason: "missing mimeType"
            )
        }
        let id = object.nonEmptyString(forKey: "id") ?? fallbackID
        guard id == fallbackID else {
            throw ExcalidrawMediaFileDecodeError(
                fileID: fallbackID,
                reason: "entry id \(id) does not match its files key"
            )
        }
        guard let dataURL = object.nonEmptyString(forKey: "dataURL") else {
            throw ExcalidrawMediaFileDecodeError(
                fileID: fallbackID,
                reason: "missing dataURL"
            )
        }

        self.init(
            mimeType: mimeType,
            id: id,
            createdAt: object.millisecondDate(forKey: "created"),
            dataURL: dataURL,
            lastRetrievedAt: object.millisecondDate(forKey: "lastRetrieved")
        )
    }
}

private struct ExcalidrawMediaFileDecodeError: LocalizedError {
    let fileID: String
    let reason: String

    var errorDescription: String? {
        "Invalid Excalidraw media file \(fileID): \(reason)."
    }
}

private extension Dictionary where Key == String, Value == ExcalidrawCore.JSONValue {
    func nonEmptyString(forKey key: String) -> String? {
        guard case .string(let value)? = self[key] else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func millisecondDate(forKey key: String) -> Date? {
        guard case .number(let value)? = self[key] else { return nil }
        return Date(timeIntervalSince1970: value / 1000)
    }
}
