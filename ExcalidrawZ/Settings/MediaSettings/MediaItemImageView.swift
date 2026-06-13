//
//  MediaItemImageView.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/13.
//

import SwiftUI
import CoreData

struct MediaItemImageView: View {
    var item: MediaItem

    @State private var data: Data?

    var body: some View {
        Color.clear
            .overlay {
                if let data {
                    DataImage(data: data)
                        .scaledToFit()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .task(id: item.objectID) {
                // Load raw data directly from FileStorage (local/iCloud) or CoreData.
                await MainActor.run {
                    self.data = nil
                }
                let imageData = try? await item.loadData()
                await MainActor.run {
                    self.data = imageData
                }
            }
    }
}
