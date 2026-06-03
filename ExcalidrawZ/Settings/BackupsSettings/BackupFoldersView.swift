//
//  BackupFoldersView.swift
//  ExcalidrawZ
//
//  Created by Dove Zachary on 2/28/25.
//

import SwiftUI

import ChocofordUI

private struct BackupFolderItem: Hashable {
    let url: URL
    let isDirectory: Bool
    let isEncrypted: Bool
}

struct BackupFoldersView: View {
    @Environment(\.alertToast) private var alertToast
    
    @Binding var selection: URL?
    
    var folder: URL
    var depth: Int
    
    init(
        selection: Binding<URL?>,
        folder: URL,
        depth: Int = 0
    ) {
        self._selection = selection
        self.folder = folder
        self.depth = depth
    }
    
    @State private var content: [BackupFolderItem] = []
    
    var body: some View {
        TreeStructureView(children: content, id: \.url, paddingLeading: 6) {
            HStack(spacing: 4) {
                let folderName = folder.lastPathComponent
                Label(
                    folderName,
                    systemSymbol: depth == 0 ? (folderName == "Cloud" ? .cloud : (folderName == "Local" ? .externaldrive : .folder)) : .folder
                )
                // .symbolVariant(.fill)
                .lineLimit(1)
                .truncationMode(.middle)
                
                Spacer()
            }
            .padding(6)
        } childView: { item in
            if item.isDirectory {
                BackupFoldersView(selection: $selection, folder: item.url, depth: depth + 1)
            } else if let name = (try? item.url.resourceValues(forKeys: [.nameKey]))?.name,
                      name.hasSuffix(".excalidraw") {
                Button {
                    selection = item.url
                } label: {
                    HStack(spacing: 4) {
                        Label(
                            item.url.deletingPathExtension().lastPathComponent,
                            systemImage: item.iconSystemName
                        )
                            // .symbolVariant(.fill)
                            // .padding(.leading, CGFloat(8 * depth) + 14)
                    }
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
                .buttonStyle(
                    .excalidrawSidebarRow(isSelected: selection == item.url, isMultiSelected: false)
                )
            }
        }
        .task(id: folder) {
            loadContent()
        }
    }

    private func loadContent() {
        do {
            self.content = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
                options: .skipsHiddenFiles
            )
            .map { url in
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                return BackupFolderItem(
                    url: url,
                    isDirectory: isDirectory,
                    isEncrypted: isDirectory ? false : isLegacyLockedBackupFile(url)
                )
            }
        } catch {
            alertToast(error)
        }
    }

    private func isLegacyLockedBackupFile(_ url: URL) -> Bool {
        guard url.pathExtension == "excalidraw",
              let data = try? Data(contentsOf: url) else {
            return false
        }
        return EncryptedContentService.isEncryptedEnvelope(data)
    }
}

private extension BackupFolderItem {
    var iconSystemName: String {
        guard isEncrypted else { return "doc" }
        if #available(macOS 15.0, iOS 18.0, *) {
            return "lock.document"
        } else {
            return "lock.doc"
        }
    }
}
