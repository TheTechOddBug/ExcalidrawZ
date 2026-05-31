//
//  BackupsSettingsView.swift
//  ExcalidrawZ
//
//  Created by Dove Zachary on 2024/11/15.
//

import SwiftUI
import CoreData

import ChocofordUI

#if os(macOS)
private struct BackupFilePreview {
    let url: URL
    let file: ExcalidrawFile
}

struct BackupsSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.alertToast) var alertToast
    
    @State private var backups: [URL] = []
    
    @State private var selectedBackup: URL?
    @State private var selectedBackupSize: Int = 0

    @State private var selectedBackupDirs: [String : [URL]] = [:]
    
    @State private var selectedFile: URL?
    
    @State private var backupToBeDeleted: URL?
    @State private var isExportingBackup = false
    @State private var unlockedBackupPreview: BackupFilePreview?
    @State private var isUnlockingBackupPreview = false
    @State private var backupPreviewErrorMessage: String?
    @State private var isBackupPreviewRecoveryKeySheetPresented = false
    @State private var systemUnlockAvailability: LockedContentSystemUnlockAvailability = .unavailable
    
    enum Route: Hashable {
        case dateList
        case folderList
    }
    
    @State private var route: Route = .dateList
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                switch route {
                    case .dateList:
                        backupsDateList()
                    case .folderList:
                        VStack(spacing: 0) {
                            HStack {
                                Button {
                                    route = .dateList
                                    self.selectedBackup = nil
                                    self.selectedFile = nil
                                } label: {
                                    Label(.localizable(.navigationButtonBack), systemSymbol: .chevronLeft)
                                }
                                .buttonStyle(.borderless)
                                Spacer()
                            }
                            .padding(6)
                            .transition(.opacity)
                            
                            if let selectedBackup {
                                BackupContentView(
                                    backup: selectedBackup,
                                    selectedFile: $selectedFile,
                                    selectedBackupSize: $selectedBackupSize
                                )
                                .transition(.opacity.combined(with: .offset(x: 50)).animation(.smooth(duration: 0.2)))
                            }
                        }
                        .animation(.default, value: selectedBackup)
                }
            }
            .clipped()
            .animation(.default, value: route)
            .frame(width: 240)
            // .visualEffect(material: .sidebar)

            Divider()
            
            ZStack {
                if let selectedFile {
                    if let unlockedBackupPreview,
                       unlockedBackupPreview.url == selectedFile {
                        ExcalidrawRenderer(file: unlockedBackupPreview.file)
                    } else if let excalidrawFile = try? ExcalidrawFile(contentsOf: selectedFile) {
                        ExcalidrawRenderer(file: excalidrawFile)
                    } else if isEncryptedBackupFile(selectedFile) {
                        encryptedBackupFileView(selectedFile)
                    } else if let selectedBackup {
                        backupHomeView(selectedBackup)
                    }
                } else if let selectedBackup {
                    backupHomeView(selectedBackup)
                } else {
                    placeholderView()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onChange(of: selectedFile) { newValue in
            unlockedBackupPreview = nil
            backupPreviewErrorMessage = nil
            isBackupPreviewRecoveryKeySheetPresented = false
            guard let newValue, isEncryptedBackupFile(newValue) else { return }
            Task {
                await unlockBackupPreviewWithSystemAuthentication(newValue, isAutomatic: true)
            }
        }
        .confirmationDialog(
            String(localizable: .backupsDeleteConfirmationTitle),
            isPresented: Binding { backupToBeDeleted != nil } set: { if !$0 { backupToBeDeleted = nil } }
        ) {
            Button(role: .destructive) {
                deleteBackup()
            } label: {
                Text(.localizable(.generalButtonConfirm))
            }
        }
        .sheet(isPresented: $isBackupPreviewRecoveryKeySheetPresented) {
            if let selectedFile {
                RecoveryKeyInputSheet(
                    title: "Use Recovery Key",
                    subtitle: selectedFile.deletingPathExtension().lastPathComponent,
                    primaryButtonTitle: "Unlock",
                    headerLayout: .compact,
                    width: 520
                ) { recoveryKey in
                    try await unlockBackupPreview(selectedFile, recoveryKey: recoveryKey)
                }
            } else {
                EmptyView()
            }
        }
        .onAppear {
            systemUnlockAvailability = LockedContentSystemUnlockStore.availability()
            loadBackups()
        }
        .onDisappear {
            unlockedBackupPreview = nil
            backupPreviewErrorMessage = nil
            isBackupPreviewRecoveryKeySheetPresented = false
        }
    }
    
    @ViewBuilder
    private func backupsDateList() -> some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(backups, id: \.self) { item in
                    Button {
                        route = .folderList
                        selectedBackup = item
                    } label: {
                        Text(item.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.listCell(selected: selectedBackup == item))
                    .contextMenu {
                        Button(role: .destructive) {
                            backupToBeDeleted = item
                        } label: {
                            Label(.localizable(.generalButtonDelete), systemSymbol: .trash)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
            }
            .padding(10)
            .frame(minHeight: 400, alignment: .top)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedBackup = nil
                    }
            }
        }
    }
    
    @ViewBuilder
    private func placeholderView() -> some View {
        VStack {
            Text(.localizable(.settingsBackupsName)).font(.largeTitle)
            VStack(alignment: .leading) {
                Text(.localizable(.settingsBackupsDescription))
                Divider()
                Text(.localizable(.settingsBackupsDescriptionSecondary))
            }
            .padding()
            .background {
                let roundedRectangle = RoundedRectangle(cornerRadius: 8)
                ZStack {
                    roundedRectangle.fill(.regularMaterial)
                    roundedRectangle.stroke(.separator)
                }
            }
        }
        .frame(maxWidth: 400)
    }

    @ViewBuilder
    private func encryptedBackupFileView(_ url: URL) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("Encrypted backup file")
                .font(.title3.weight(.semibold))

            Text("This file is protected. Restore or open it in ExcalidrawZ, then unlock it with the Recovery Key.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            VStack(spacing: 6) {
                Button {
                    Task {
                        await unlockBackupPreviewWithSystemAuthentication(url)
                    }
                } label: {
                    if isUnlockingBackupPreview {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Unlock Preview", systemImage: systemUnlockAvailability.systemImage)
                    }
                }
                .modernButtonStyle(style: .glassProminent, size: .large, shape: .capsule)
                .disabled(isUnlockingBackupPreview || !systemUnlockAvailability.isAvailable)
                .help(systemUnlockAvailability.buttonTitle)

                Button {
                    isBackupPreviewRecoveryKeySheetPresented = true
                } label: {
                    Text("Use Recovery Key")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .disabled(isUnlockingBackupPreview)
            }
            .padding(.top, 4)

            if let backupPreviewErrorMessage {
                Label(backupPreviewErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .padding()
    }

    private func isEncryptedBackupFile(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        return EncryptedContentService.isEncryptedEnvelope(data)
    }

    @MainActor
    private func unlockBackupPreviewWithSystemAuthentication(
        _ url: URL,
        isAutomatic: Bool = false
    ) async {
        guard selectedFile == url else { return }
        guard !isUnlockingBackupPreview else { return }
        backupPreviewErrorMessage = nil
        systemUnlockAvailability = LockedContentSystemUnlockStore.availability()

        isUnlockingBackupPreview = true
        defer { isUnlockingBackupPreview = false }

        do {
            let recoveryKey: RecoveryKey
            if let currentRecoveryKey = await RecoveryKeyVault.shared.currentRecoveryKey() {
                recoveryKey = currentRecoveryKey
            } else {
                recoveryKey = try await LockedContentSystemUnlockStore.loadRecoveryKey(
                    reason: LockedContentSystemUnlockReason.previewBackupFile
                )
            }
            try await unlockBackupPreview(url, recoveryKey: recoveryKey)
        } catch let unlockError as LockedContentSystemUnlockError {
            systemUnlockAvailability = LockedContentSystemUnlockStore.availability()
            switch unlockError {
                case .canceled:
                    break
                case .noSavedRecoveryKey:
                    if !isAutomatic {
                        isBackupPreviewRecoveryKeySheetPresented = true
                    }
                default:
                    if !isAutomatic {
                        backupPreviewErrorMessage = LockedContentErrorPresenter.message(for: unlockError)
                    }
            }
        } catch {
            if !isAutomatic {
                backupPreviewErrorMessage = LockedContentErrorPresenter.message(for: error)
            }
        }
    }

    @MainActor
    private func unlockBackupPreview(_ url: URL, recoveryKey: RecoveryKey) async throws {
        guard selectedFile == url else { return }
        let file = try await unlockedEncryptedBackupExcalidrawFile(
            from: url,
            context: viewContext,
            recoveryKey: recoveryKey
        )
        guard selectedFile == url else { return }
        await RecoveryKeyVault.shared.activate(recoveryKey)
        unlockedBackupPreview = BackupFilePreview(url: url, file: file)
        backupPreviewErrorMessage = nil
    }

    @ViewBuilder
    private func backupHomeView(_ backup: URL) -> some View {
        let title = String(
            localizable: .backupName(
                (try? backup.resourceValues(forKeys: [.creationDateKey]).creationDate?.formatted()) ?? String(localizable: .generalUnknown)
            )
        )
    
        VStack {
            Text(title).font(.title)
            
            Text(String(localizable: .generalTotalSizeLabel) + selectedBackupSize.formatted(.byteCount(style: .file)))
            
            HStack {
                Button {
                    Task {
                        await exportBackup(backup, title: title)
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isExportingBackup {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Label(.localizable(.backupButtonExport), systemSymbol: .squareAndArrowUp)
                    }
                }
                .disabled(isExportingBackup)

#if DEBUG
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([backup])
                } label: {
                    Label(.localizable(.generalButtonRevealInFinder), systemSymbol: .docViewfinder)
                }
#endif

                Button(role: .destructive) {
                    backupToBeDeleted = backup
                } label: {
                    Label(.localizable(.backupButtonDelete), systemSymbol: .trash)
                }
            }
        }
    }

    @MainActor
    private func exportBackup(_ backup: URL, title: String) async {
        guard !isExportingBackup else { return }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = title
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let targetURL = panel.url else {
            return
        }

        isExportingBackup = true
        defer { isExportingBackup = false }

        do {
            let recoveryKey: RecoveryKey?
            let containsEncryptedFiles = try await Task.detached(priority: .userInitiated) {
                try backupContainsEncryptedExcalidrawFiles(backup)
            }.value

            if containsEncryptedFiles {
                if let currentRecoveryKey = await RecoveryKeyVault.shared.currentRecoveryKey() {
                    recoveryKey = currentRecoveryKey
                } else {
                    recoveryKey = try await LockedContentSystemUnlockStore.loadRecoveryKey(
                        reason: LockedContentSystemUnlockReason.exportBackup
                    )
                }
            } else {
                recoveryKey = nil
            }

            try await exportBackupRecord(
                from: backup,
                to: targetURL,
                context: viewContext,
                recoveryKey: recoveryKey
            )

            alertToast(.init(
                displayMode: .hud,
                type: .complete(.green),
                title: String(localizable: .generalFileExporterSaved)
            ))
        } catch let unlockError as LockedContentSystemUnlockError where unlockError == .canceled {
            return
        } catch {
            alertToast(error)
        }
    }
    
    private func loadBackups() {
        do {
            let backupsDir = try getBackupsDir()
            
            let backupDirs: [URL] = try FileManager.default.contentsOfDirectory(
                at: backupsDir,
                includingPropertiesForKeys: [.nameKey, .isDirectoryKey, .creationDateKey]
            )
                .filter({ (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true })
                .sorted(by: {
                    ((try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast) > ((try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast)
                })
                        
            self.backups = backupDirs
        } catch {
            alertToast(error)
        }
    }
    
    private func deleteBackup() {
        guard let item = backupToBeDeleted, let index = backups.firstIndex(of: item) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: item)
            backups.remove(at: index)
            selectedBackup = nil
            selectedBackupSize = 0
            selectedBackupDirs = [:]
            selectedFile = nil
            backupToBeDeleted = nil
            route = .dateList
        } catch {
            alertToast(error)
        }
    }
}

private func backupContainsEncryptedExcalidrawFiles(_ backup: URL) throws -> Bool {
    try backupDirectoryContainsEncryptedExcalidrawFiles(backup)
}

private func exportBackupRecord(
    from backup: URL,
    to targetURL: URL,
    context: NSManagedObjectContext,
    recoveryKey: RecoveryKey?
) async throws {
    let fileManager = FileManager.default
    let replacementDirectory = try fileManager.url(
        for: .itemReplacementDirectory,
        in: .userDomainMask,
        appropriateFor: targetURL.deletingLastPathComponent(),
        create: true
    )
    defer {
        try? fileManager.removeItem(at: replacementDirectory)
    }

    let stagingURL = replacementDirectory.appendingPathComponent(targetURL.lastPathComponent, conformingTo: .directory)
    try await writeExportedBackupRecord(
        from: backup,
        to: stagingURL,
        context: context,
        recoveryKey: recoveryKey
    )

    if fileManager.fileExists(atPath: targetURL.path) {
        try fileManager.removeItem(at: targetURL)
    }
    try fileManager.copyItem(at: stagingURL, to: targetURL)
}

private func writeExportedBackupRecord(
    from backup: URL,
    to targetURL: URL,
    context: NSManagedObjectContext,
    recoveryKey: RecoveryKey?
) async throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: false)

    guard let enumerator = fileManager.enumerator(
        at: backup,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return
    }

    while let sourceURL = enumerator.nextObject() as? URL {
        let destinationURL = exportedBackupDestinationURL(
            sourceURL: sourceURL,
            backupRoot: backup,
            exportRoot: targetURL
        )
        let isDirectory = (try? sourceURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true

        if isDirectory {
            try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
            continue
        }

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if sourceURL.pathExtension == "excalidraw" {
            let data = try await exportedBackupExcalidrawFileData(
                from: sourceURL,
                context: context,
                recoveryKey: recoveryKey
            )
            try data.write(to: destinationURL, options: .atomic)
        } else {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }
}

private func exportedBackupDestinationURL(
    sourceURL: URL,
    backupRoot: URL,
    exportRoot: URL
) -> URL {
    let backupComponents = backupRoot.standardizedFileURL.pathComponents
    let sourceComponents = sourceURL.standardizedFileURL.pathComponents
    let relativeComponents = sourceComponents.dropFirst(backupComponents.count)

    return relativeComponents.reduce(exportRoot) { partialResult, component in
        partialResult.appendingPathComponent(component)
    }
}

private func exportedBackupExcalidrawFileData(
    from sourceURL: URL,
    context: NSManagedObjectContext,
    recoveryKey: RecoveryKey?
) async throws -> Data {
    let storedData = try Data(contentsOf: sourceURL)

    guard EncryptedContentService.isEncryptedEnvelope(storedData) else {
        return storedData
    }

    guard let recoveryKey else {
        throw LockedContentSystemUnlockError.noSavedRecoveryKey
    }

    let excalidrawFile = try await unlockedEncryptedBackupExcalidrawFile(
        from: sourceURL,
        context: context,
        recoveryKey: recoveryKey
    )
    return excalidrawFile.content ?? storedData
}

private func unlockedEncryptedBackupExcalidrawFile(
    from sourceURL: URL,
    context: NSManagedObjectContext,
    recoveryKey: RecoveryKey
) async throws -> ExcalidrawFile {
    let storedData = try Data(contentsOf: sourceURL)
    let envelope = try EncryptedContentService.decodeEnvelope(storedData)
    let plaintext = try EncryptedContentService.decrypt(storedData, recoveryKey: recoveryKey)
    let fileID = envelope.contentType == "file" ? envelope.contentID : nil

    var excalidrawFile = try ExcalidrawFile(data: plaintext, id: fileID)
    if excalidrawFile.name == nil {
        excalidrawFile.name = sourceURL.deletingPathExtension().lastPathComponent
    }
    try await excalidrawFile.syncFiles(context: context)
    return excalidrawFile
}

#elseif os(iOS)
struct BackupsSettingsView: View {
    var body: some View {
        Text(.localizable(.settingsBackupUnavailableDescription))
    }
}
#endif
#Preview {
    BackupsSettingsView()
}
