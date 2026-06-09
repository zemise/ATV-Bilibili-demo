//
//  TopShelfImageUploadServer.swift
//  BilibiliLive
//
//  Created by Codex on 2026/6/9.
//

import Foundation
import Swifter
import UIKit

final class TopShelfImageUploadServer {
    static let shared = TopShelfImageUploadServer()

    private let server = HttpServer()
    private var isConfigured = false

    private init() {}

    var uploadURLString: String? {
        guard let host = localIPAddress,
              let port = try? server.port()
        else { return nil }

        return "http://\(host):\(port)"
    }

    var isRunning: Bool {
        uploadURLString != nil
    }

    func start() throws -> String {
        configureRoutesIfNeeded()
        if let uploadURLString {
            return uploadURLString
        }

        try server.start(0)
        guard let uploadURLString else {
            throw UploadServerError.localAddressUnavailable
        }
        return uploadURLString
    }

    func stop() {
        server.stop()
    }

    private func configureRoutesIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        server.get["/"] = { _ in
            HttpResponse.ok(.html(Self.uploadPageHTML(hasCustomImage: TopShelfSharedImageStore.hasCustomImage)))
        }

        server.post["/upload"] = { request in
            do {
                let imageData = try Self.extractImageData(from: request)
                let topShelfImage = try Self.makeTopShelfImage(from: imageData)
                try TopShelfSharedImageStore.saveImageData(topShelfImage.data, fileExtension: topShelfImage.fileExtension)
                return HttpResponse.ok(.html(Self.resultPageHTML(title: "上传成功", message: "回到 Apple TV 首页，聚焦本 App 后会显示新的 Top Shelf 图片。")))
            } catch {
                return HttpResponse.badRequest(.html(Self.resultPageHTML(title: "上传失败", message: error.localizedDescription)))
            }
        }

        server.post["/delete"] = { _ in
            do {
                try TopShelfSharedImageStore.removeImage()
                return HttpResponse.ok(.html(Self.resultPageHTML(title: "已恢复默认", message: "自定义 Top Shelf 图片已删除。")))
            } catch {
                return HttpResponse.badRequest(.html(Self.resultPageHTML(title: "操作失败", message: error.localizedDescription)))
            }
        }
    }

    private static func extractImageData(from request: HttpRequest) throws -> Data {
        if let part = request.parseMultiPartFormData().first(where: { $0.name == "image" || $0.fileName != nil }),
           !part.body.isEmpty
        {
            return Data(part.body)
        }

        if !request.body.isEmpty {
            return Data(request.body)
        }

        throw TopShelfImageError.imageDataMissing
    }

    private static func makeTopShelfImage(from data: Data) throws -> TopShelfUploadedImage {
        guard let image = UIImage(data: data) else {
            throw UploadServerError.invalidImage
        }

        if let fileExtension = imageFileExtension(for: data) {
            return TopShelfUploadedImage(data: data, fileExtension: fileExtension)
        }

        guard let jpegData = image.jpegData(compressionQuality: 1) else {
            throw UploadServerError.invalidImage
        }
        return TopShelfUploadedImage(data: jpegData, fileExtension: "jpg")
    }

    private static func imageFileExtension(for data: Data) -> String? {
        guard data.count >= 12 else { return nil }

        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }
        if bytes.starts(with: [0x47, 0x49, 0x46]) {
            return "gif"
        }
        if String(bytes: bytes[4..<8], encoding: .ascii) == "ftyp",
           let header = String(bytes: data.prefix(64), encoding: .ascii)
        {
            let heifBrands = ["heic", "heix", "hevc", "hevx", "mif1", "msf1"]
            if heifBrands.contains(where: { header.contains($0) }) {
                return "heic"
            }
        }

        return nil
    }

    private static func uploadPageHTML(hasCustomImage: Bool) -> String {
        let deleteForm = hasCustomImage ? """
        <form method="post" action="/delete">
          <button class="secondary" type="submit">恢复默认图片</button>
        </form>
        """ : ""

        return """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Top Shelf 图片上传</title>
          <style>
            body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif; background: #111; color: #fff; }
            main { max-width: 680px; margin: 0 auto; padding: 40px 24px; }
            h1 { font-size: 28px; margin: 0 0 12px; }
            p { color: #c8c8c8; line-height: 1.55; }
            form { margin-top: 24px; }
            input { width: 100%; box-sizing: border-box; padding: 16px; border: 1px solid #444; border-radius: 8px; background: #1d1d1d; color: #fff; }
            button { width: 100%; margin-top: 16px; padding: 16px; border: 0; border-radius: 8px; background: #00a6ff; color: #fff; font-size: 17px; font-weight: 700; }
            .secondary { background: #333; }
          </style>
        </head>
        <body>
          <main>
            <h1>Top Shelf 图片上传</h1>
            <p>请选择一张横向高分辨率图片。系统会按 Top Shelf 展示区域自动适配。</p>
            <form method="post" action="/upload" enctype="multipart/form-data">
              <input name="image" type="file" accept="image/*" required>
              <button type="submit">上传并替换</button>
            </form>
            \(deleteForm)
          </main>
        </body>
        </html>
        """
    }

    private static func resultPageHTML(title: String, message: String) -> String {
        """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(title)</title>
          <style>
            body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif; background: #111; color: #fff; }
            main { max-width: 680px; margin: 0 auto; padding: 40px 24px; }
            p { color: #c8c8c8; line-height: 1.55; }
            a { display: block; margin-top: 24px; color: #00a6ff; font-weight: 700; }
          </style>
        </head>
        <body>
          <main>
            <h1>\(title)</h1>
            <p>\(message)</p>
            <a href="/">返回上传页面</a>
          </main>
        </body>
        </html>
        """
    }

    private var localIPAddress: String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let interface = ptr?.pointee else { continue }
                guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

                let name = String(cString: interface.ifa_name)
                guard name == "en0" || name == "en1" || name == "en2" || name == "en3" || name == "en4" else { continue }

                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                address = String(cString: hostname)
                if name == "en0" {
                    break
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}

enum UploadServerError: LocalizedError {
    case localAddressUnavailable
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .localAddressUnavailable:
            return "无法获取 Apple TV 局域网地址"
        case .invalidImage:
            return "图片格式无法识别"
        }
    }
}

private struct TopShelfUploadedImage {
    let data: Data
    let fileExtension: String
}
