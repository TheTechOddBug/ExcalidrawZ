//
//  CheckpointWriteOptions.swift
//  ExcalidrawZ
//
//  Policy enum that callers of `FileRepository.updateElements(...)` and the
//  local-file equivalent use to control checkpoint history behaviour.
//
//  - `suppress`     — content saves; NO checkpoint row touched. Used while
//                     an AI chat session is active so canvas mutations
//                     don't pollute user history.
//  - `userEdit`     — user-edit semantics: first edit creates a fresh user
//                     checkpoint, subsequent edits update the latest user row
//                     until the rollover interval passes. AI-tagged rows are
//                     skipped over (immutable snapshots).
//  - `explicit`     — force-create a checkpoint with explicit metadata.
//                     Used by the AI chat session begin/end hooks.
//

import Foundation

enum CheckpointWriteOptions {
    case suppress
    case userEdit(newCheckpoint: Bool)
    case explicit(
        source: FileCheckpointSource,
        description: String?
    )
}

enum UserCheckpointRolloverPolicy {
    static let interval: TimeInterval = 10 * 60

    /// User checkpoints use `updatedAt` as the checkpoint window's start time.
    /// Segment updates should replace content without sliding this timestamp;
    /// otherwise long editing runs would never roll over to a fresh checkpoint.
    static func shouldCreateNewCheckpoint(
        latestUpdatedAt: Date?,
        now: Date = .now
    ) -> Bool {
        guard let latestUpdatedAt else {
            return true
        }
        return now.timeIntervalSince(latestUpdatedAt) >= interval
    }
}
