//
//  TopShelfContentProvider.swift
//  BilibiliTopShelfExtension
//
//  Created by Codex on 2026/6/9.
//

import Foundation
import TVServices

final class TopShelfContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        guard let imageURL = TopShelfSharedImageStore.imageURL,
              FileManager.default.fileExists(atPath: imageURL.path)
        else {
            completionHandler(nil)
            return
        }

        let item = TVTopShelfCarouselItem(identifier: "custom-top-shelf-image-\(TopShelfSharedImageStore.currentImageIdentifier)")
        item.setImageURL(imageURL, for: [.screenScale1x, .screenScale2x])
        completionHandler(TVTopShelfCarouselContent(style: .actions, items: [item]))
    }
}
