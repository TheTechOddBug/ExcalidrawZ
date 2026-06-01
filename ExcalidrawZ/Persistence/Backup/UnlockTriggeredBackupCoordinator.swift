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

    private static let lastSuccessfulBackupDayKey = "UnlockTriggeredBackupCoordinator.lastSuccessfulBackupDay"
    private static let logger = Logger(label: "UnlockTriggeredBackupCoordinator")

    private var backupTask: Task<Void, Never>?

    func noteLockedContentUnlocked() {
        let day = Self.dayIdentifier(for: Date())
        guard UserDefaults.standard.string(forKey: Self.lastSuccessfulBackupDayKey) != day else {
            return
        }
        guard backupTask == nil else {
            return
        }

        backupTask = Task(priority: .utility) { [day] in
            do {
                let context = PersistenceController.shared.container.newBackgroundContext()
                try await backupFiles(context: context)
                self.markBackupCompleted(day: day)
            } catch {
                Self.logger.error("Unlock-triggered backup failed: \(error.localizedDescription)")
            }
            self.clearBackupTask()
        }
    }

    private func markBackupCompleted(day: String) {
        UserDefaults.standard.set(day, forKey: Self.lastSuccessfulBackupDayKey)
    }

    private func clearBackupTask() {
        backupTask = nil
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
