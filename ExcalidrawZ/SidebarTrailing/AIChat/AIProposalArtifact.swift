//
//  AIProposalArtifact.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/01.
//

import Foundation
import LLMCore

struct AIProposalArtifact: Codable, Hashable {
    static let kind = "excalidrawz.aiProposal.v1"

    var kind: String
    var file: ExcalidrawFile
    var elementCount: Int

    init(file: ExcalidrawFile) {
        self.kind = Self.kind
        self.file = file
        self.elementCount = file.elements.filter { !$0.isDeleted }.count
    }

    var visibleElements: [ExcalidrawElement] {
        file.elements.filter { !$0.isDeleted }
    }

    static func parse(from content: ChatMessageContent) -> AIProposalArtifact? {
        guard let raw = content.content else { return nil }
        return parse(from: raw)
    }

    static func parse(from raw: String) -> AIProposalArtifact? {
        guard raw.contains(Self.kind) else { return nil }

        for candidate in jsonCandidates(from: raw) {
            guard let data = candidate.data(using: .utf8) else { continue }
            if let artifact = decodeArtifact(from: data) {
                return artifact
            }
            if let object = try? JSONSerialization.jsonObject(with: data),
               let artifact = findArtifact(in: object) {
                return artifact
            }
        }
        return nil
    }

    private static func decodeArtifact(from data: Data) -> AIProposalArtifact? {
        if let envelope = try? JSONDecoder().decode(AIProposalToolOutputEnvelope.self, from: data),
           envelope.proposal?.kind == Self.kind {
            return envelope.proposal
        }
        if let artifact = try? JSONDecoder().decode(AIProposalArtifact.self, from: data),
           artifact.kind == Self.kind {
            return artifact
        }
        return nil
    }

    private static func findArtifact(in object: Any) -> AIProposalArtifact? {
        if let dictionary = object as? [String: Any] {
            if let kind = dictionary["kind"] as? String,
               kind == Self.kind,
               let data = try? JSONSerialization.data(withJSONObject: dictionary),
               let artifact = decodeArtifact(from: data) {
                return artifact
            }

            if let proposal = dictionary["proposal"],
               let artifact = findArtifact(in: proposal) {
                return artifact
            }

            for value in dictionary.values {
                if let artifact = findArtifact(in: value) {
                    return artifact
                }
            }
        }

        if let array = object as? [Any] {
            for value in array {
                if let artifact = findArtifact(in: value) {
                    return artifact
                }
            }
        }

        if let string = object as? String,
           string.contains(Self.kind) || string.contains("\"proposal\"") {
            return parse(from: string)
        }

        return nil
    }

    private static func jsonCandidates(from raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else {
            return [trimmed]
        }

        var lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else { return [trimmed] }
        lines.removeFirst()
        if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") == true {
            lines.removeLast()
        }
        let fenced = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return fenced.isEmpty ? [trimmed] : [fenced, trimmed]
    }
}

private struct AIProposalToolOutputEnvelope: Decodable {
    let proposal: AIProposalArtifact?
}
