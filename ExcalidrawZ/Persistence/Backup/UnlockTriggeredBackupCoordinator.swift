//
//  UnlockTriggeredBackupCoordinator.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/05/31.
//

import Foundation
import Logging

#if canImport(AppKit)
actor UnlockTriggeredBackupCoordinator {
    static let shared = UnlockTriggeredBackupCoordinator()

    private static let logger = Logger(label: "UnlockTriggeredBackupCoordinator")
    private static let backupDelay: Duration = .seconds(2)
    private static let markerFileName = ".unlock-triggered-backup"

    private var backupTask: Task<Void, Never>?

    func noteLockedContentUnlocked() {
        let day = Self.dayIdentifier(for: Date())
        guard !Self.hasCompletedUnlockTriggeredBackup(day: day) else {
            return
        }
        guard backupTask == nil else {
            return
        }

        backupTask = Task(priority: .utility) { [day] in
            do {
                try await Task.sleep(for: Self.backupDelay)
                let context = PersistenceController.shared.container.newBackgroundContext()
                let didBackup = try await backupFiles(context: context, reason: .unlockedContent)
                if didBackup {
                    try Self.markBackupCompleted(day: day)
                    Self.logger.info("Unlock-triggered backup completed for \(day)")
                }
            } catch is CancellationError {
            } catch {
                Self.logger.error("Unlock-triggered backup failed: \(error.localizedDescription)")
            }
            self.clearBackupTask()
        }
    }

    private func clearBackupTask() {
        backupTask = nil
    }

    private static func hasCompletedUnlockTriggeredBackup(day: String) -> Bool {
        guard let markerURL = try? markerURL(for: day) else {
            return false
        }
        return FileManager.default.fileExists(atPath: markerURL.path)
    }

    private static func markBackupCompleted(day: String) throws {
        let markerURL = try markerURL(for: day)
        let text = "unlock-triggered backup completed at \(Date().ISO8601Format())\n"
        try Data(text.utf8).write(to: markerURL, options: .atomic)
    }

    private static func markerURL(for day: String) throws -> URL {
        try getBackupsDir()
            .appendingPathComponent(day, conformingTo: .directory)
            .appendingPathComponent(markerFileName, conformingTo: .data)
    }

    private static func dayIdentifier(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
#endif
