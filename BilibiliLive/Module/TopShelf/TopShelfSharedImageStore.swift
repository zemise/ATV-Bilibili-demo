//
//  TopShelfSharedImageStore.swift
//  BilibiliLive
//
//  Created by Codex on 2026/6/9.
//

import Foundation
import TVServices

enum TopShelfSharedImageStore {
    static let appGroupIdentifier = "group.com.zemise.tv.BilibiliLive"
    static let updatedNotificationName = "TopShelfImageDidUpdate"

    static var imageURL: URL? {
        guard let currentImageFileName else { return nil }
        return sharedImageDirectoryURL?.appendingPathComponent(currentImageFileName)
    }

    static var currentImageIdentifier: String {
        currentImageFileName ?? "default"
    }

    static var diagnosticMessage: String {
        """
        请确认主 App 和 Top Shelf Extension 的签名 profile 都包含 App Group：\(appGroupIdentifier)
        """
    }

    static var hasCustomImage: Bool {
        guard let imageURL else { return false }
        return FileManager.default.fileExists(atPath: imageURL.path)
    }

    static func saveImageData(_ data: Data, fileExtension: String = "jpg") throws {
        guard let sharedImageDirectoryURL else {
            throw TopShelfImageError.sharedContainerUnavailable
        }

        let previousImageURL = imageURL
        let imageFileName = "custom-top-shelf-\(UUID().uuidString).\(fileExtension)"
        let imageURL = sharedImageDirectoryURL.appendingPathComponent(imageFileName)

        do {
            try FileManager.default.createDirectory(at: sharedImageDirectoryURL, withIntermediateDirectories: true)
            try data.write(to: imageURL)
            defaults?.set(imageFileName, forKey: currentImageFileNameKey)
            defaults?.synchronize()
            removeStaleImages(excluding: imageURL, previousImageURL: previousImageURL)
        } catch {
            throw TopShelfImageError.writeFailed(error)
        }
        NotificationCenter.default.post(name: Notification.Name(updatedNotificationName), object: nil)
        TVTopShelfContentProvider.topShelfContentDidChange()
    }

    static func removeImage() throws {
        guard let sharedImageDirectoryURL else {
            throw TopShelfImageError.sharedContainerUnavailable
        }

        do {
            try FileManager.default.createDirectory(at: sharedImageDirectoryURL, withIntermediateDirectories: true)
            try removeCustomImages(in: sharedImageDirectoryURL)
            defaults?.removeObject(forKey: currentImageFileNameKey)
            defaults?.synchronize()
        } catch {
            throw TopShelfImageError.writeFailed(error)
        }
        NotificationCenter.default.post(name: Notification.Name(updatedNotificationName), object: nil)
        TVTopShelfContentProvider.topShelfContentDidChange()
    }

    private static let currentImageFileNameKey = "TopShelfCurrentImageFileName"

    private static var currentImageFileName: String? {
        defaults?.string(forKey: currentImageFileNameKey)
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private static var sharedImageDirectoryURL: URL? {
        sharedContainerURL?
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
    }

    private static func removeStaleImages(excluding currentImageURL: URL, previousImageURL: URL?) {
        guard let sharedImageDirectoryURL else { return }

        do {
            let imageURLs = try customImageURLs(in: sharedImageDirectoryURL)
            for imageURL in imageURLs where imageURL != currentImageURL {
                try? FileManager.default.removeItem(at: imageURL)
            }
        } catch {
            if let previousImageURL, previousImageURL != currentImageURL {
                try? FileManager.default.removeItem(at: previousImageURL)
            }
        }
    }

    private static func removeCustomImages(in directoryURL: URL) throws {
        for imageURL in try customImageURLs(in: directoryURL) {
            try FileManager.default.removeItem(at: imageURL)
        }
    }

    private static func customImageURLs(in directoryURL: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { url in
            url.lastPathComponent.hasPrefix("custom-top-shelf")
        }
    }
}

enum TopShelfImageError: LocalizedError {
    case sharedContainerUnavailable
    case imageDataMissing
    case writeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .sharedContainerUnavailable:
            return "无法访问 App Group 共享目录。\(TopShelfSharedImageStore.diagnosticMessage)"
        case .imageDataMissing:
            return "没有读取到上传的图片"
        case let .writeFailed(error):
            return "保存 Top Shelf 图片失败：\(error.localizedDescription)。\(TopShelfSharedImageStore.diagnosticMessage)"
        }
    }
}
