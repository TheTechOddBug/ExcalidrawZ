//
//  MediaRoute.swift
//  ExcalidrawZ
//
//  Created by Codex on 2026/06/13.
//

import CoreData

enum MediaRoute: Hashable {
    case mediaItem(NSManagedObjectID)

    var id: String {
        switch self {
            case .mediaItem(let objectID):
                "mediaItem.\(objectID.uriRepresentation().absoluteString)"
        }
    }
}
