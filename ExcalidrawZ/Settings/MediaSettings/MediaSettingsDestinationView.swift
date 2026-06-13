//
//  MediaSettingsDestinationView.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/13.
//

import SwiftUI
import CoreData

struct MediaSettingsDestinationView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var route: MediaRoute

    var body: some View {
        switch route {
            case .mediaItem(let objectID):
                if let item = mediaItem(for: objectID) {
                    MediaItemDetailView(item: item)
                } else {
                    missingMediaItemView()
                }
        }
    }

    @ViewBuilder
    private func missingMediaItemView() -> some View {
        VStack(spacing: 8) {
            Text(.localizable(.settingsMediasName))
                .font(.headline)
            Text(.localizable(.generalUnknown))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mediaItem(for objectID: NSManagedObjectID) -> MediaItem? {
        guard let object = try? viewContext.existingObject(with: objectID) else {
            return nil
        }
        return object as? MediaItem
    }
}
