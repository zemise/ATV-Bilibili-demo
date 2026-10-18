//
//  PlayerMediaWarmup.swift
//  BilibiliLive
//
//  Created by OpenAI on 2026/4/4.
//

import AVFoundation
import Foundation

final class PreparedPlayerMedia: @unchecked Sendable {
    let asset: AVURLAsset
    let delegate: BilibiliVideoResourceLoaderDelegate
    @MainActor private var previewBuffer: PreviewPlayerBuffer?

    init(asset: AVURLAsset, delegate: BilibiliVideoResourceLoaderDelegate) {
        self.asset = asset
        self.delegate = delegate
    }

    @MainActor var isPreviewBuffered: Bool {
        previewBuffer?.isReady == true
    }

    @MainActor func bufferPreview(startTime: Double) async {
        guard previewBuffer == nil else { return }
        let buffer = PreviewPlayerBuffer(asset: asset, startTime: startTime)
        previewBuffer = buffer
        let ready = await buffer.prepare()
        if !ready, previewBuffer === buffer {
            discardPreviewBuffer()
        }
    }

    @MainActor func takePreviewPlayer(startTime: Double) -> AVPlayer? {
        guard let buffer = previewBuffer else { return nil }
        previewBuffer = nil
        guard abs(buffer.startTime - startTime) < 0.5 else {
            buffer.stop()
            return nil
        }
        return buffer.takePlayer()
    }

    @MainActor func discardPreviewBuffer() {
        previewBuffer?.stop()
        previewBuffer = nil
    }
}

/// A paused, muted player prepares a neighboring preview's media and decoder.
/// Ownership transfers to AVKit on focus; no hidden player ever starts playback.
@MainActor
private final class PreviewPlayerBuffer {
    let player: AVPlayer
    let startTime: Double
    private(set) var isReady = false
    private var claimed = false

    init(asset: AVURLAsset, startTime: Double) {
        self.startTime = startTime
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 2
        player = AVPlayer(playerItem: item)
        player.isMuted = true
    }

    func prepare() async -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + 4
        while !claimed, !Task.isCancelled, player.status == .unknown,
              ProcessInfo.processInfo.systemUptime < deadline
        {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        guard !claimed, !Task.isCancelled, player.status == .readyToPlay else { return false }
        if startTime > 0 {
            await player.seek(to: CMTime(seconds: startTime, preferredTimescale: 1), toleranceBefore: .zero, toleranceAfter: .zero)
        }
        guard !claimed, !Task.isCancelled else { return false }
        player.preroll(atRate: 1) { [weak self] finished in
            Task { @MainActor [weak self] in
                guard let self, !self.claimed else { return }
                self.isReady = finished
            }
        }
        while !claimed, !Task.isCancelled, !isReady,
              player.status != .failed, ProcessInfo.processInfo.systemUptime < deadline
        {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return isReady && !Task.isCancelled && !claimed
    }

    func takePlayer() -> AVPlayer {
        claimed = true
        player.cancelPendingPrerolls()
        return player
    }

    func stop() {
        claimed = true
        player.cancelPendingPrerolls()
        player.currentItem?.cancelPendingSeeks()
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}

enum PlayerMediaFactory {
    static func prepare(aid: Int,
                        urlInfo: VideoPlayURLInfo,
                        playerInfo: PlayerInfo?,
                        maxQuality: Int? = nil,
                        streamIndex: Int? = nil,
                        preferredHost: String? = nil) async throws -> PreparedPlayerMedia
    {
        let playURL = URL(string: BilibiliVideoResourceLoaderDelegate.URLs.play)!
        let headers: [String: String] = [
            "User-Agent": Keys.userAgent,
            "Referer": Keys.referer(for: aid),
        ]
        let asset = AVURLAsset(url: playURL, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let delegate = BilibiliVideoResourceLoaderDelegate()
        delegate.setBilibili(info: urlInfo,
                             subtitles: playerInfo?.subtitle?.subtitles ?? [],
                             aid: aid,
                             maxQuality: maxQuality,
                             streamIndex: streamIndex,
                             preferredHost: preferredHost)
        asset.resourceLoader.setDelegate(delegate, queue: DispatchQueue(label: "loader.\(aid).\(UUID().uuidString)"))
        try Task.checkCancellation()
        let playable = try await asset.load(.isPlayable)
        try Task.checkCancellation()
        guard playable else {
            throw "加载资源失败"
        }
        try await withTaskCancellationHandler {
            await delegate.prewarmPrimaryVideoIndex()
            try Task.checkCancellation()
        } onCancel: {
            delegate.cancelPendingIndexLoads()
        }
        return PreparedPlayerMedia(asset: asset, delegate: delegate)
    }
}

actor PlayerMediaWarmupManager {
    private struct InFlightEntry {
        let token: UUID
        let task: Task<PreparedPlayerMedia, Error>
    }

    private let maxPreparedEntries = 4
    private let playContextCache: PlayContextCache
    private let mode: PlayContextMode
    private var prepared = [String: PreparedPlayerMedia]()
    private var inFlight = [String: InFlightEntry]()
    private var accessOrder = [String]()
    private var cancellationGeneration = 0

    init(playContextCache: PlayContextCache, mode: PlayContextMode = .regular) {
        self.playContextCache = playContextCache
        self.mode = mode
    }

    func preload(playInfo: PlayInfo, bufferPreview: Bool = false) async {
        guard let media = try? await preparedMedia(for: playInfo), !Task.isCancelled else { return }
        guard mode == .preview, bufferPreview else { return }
        let resolved = try? await PlayInfoResolver.resolve(playInfo)
        guard let resolved,
              let snapshot = try? await playContextCache.context(for: resolved, mode: mode),
              !Task.isCancelled else { return }
        let lastCid = playInfo.lastPlayCid ?? snapshot.playerInfo?.last_play_cid ?? 0
        let lastTime = playInfo.playTimeInSecond ?? snapshot.playerInfo?.playTimeInSecond ?? 0
        let startTime = Settings.continuePlay && lastCid == snapshot.cid && snapshot.videoPlayURLInfo.dash.duration - lastTime > 5 ? max(0, lastTime) : 0
        await media.bufferPreview(startTime: Double(startTime))
    }

    func isPreviewBuffered(for playInfo: PlayInfo) async -> Bool {
        guard let media = prepared[playInfo.sequenceKey] else { return false }
        return await media.isPreviewBuffered
    }

    func retainPreviewBuffers(for playInfos: [PlayInfo]) async {
        let keys = Set(playInfos.prefix(2).map(\.sequenceKey))
        for (key, media) in prepared where !keys.contains(key) {
            await media.discardPreviewBuffer()
        }
    }

    func preparedMedia(for playInfo: PlayInfo) async throws -> PreparedPlayerMedia {
        let generation = cancellationGeneration
        let resolvedPlayInfo = try await PlayInfoResolver.resolve(playInfo)
        try Task.checkCancellation()
        guard cancellationGeneration == generation else { throw CancellationError() }
        let key = resolvedPlayInfo.sequenceKey
        if let cached = prepared[key] {
            Logger.info("[media-warmup] hit mode=\(mode.rawValue) aid=\(resolvedPlayInfo.aid)")
            touch(key)
            return cached
        }
        if let entry = inFlight[key] {
            return try await resolve(entry, for: key)
        }

        let token = UUID()
        let task = Task<PreparedPlayerMedia, Error> {
            try Task.checkCancellation()
            let snapshot = try await playContextCache.context(for: resolvedPlayInfo, mode: mode)
            try Task.checkCancellation()
            return try await PlayerMediaFactory.prepare(
                aid: resolvedPlayInfo.aid,
                urlInfo: snapshot.videoPlayURLInfo,
                playerInfo: snapshot.playerInfo
            )
        }

        let entry = InFlightEntry(token: token, task: task)
        inFlight[key] = entry
        return try await resolve(entry, for: key)
    }

    private func resolve(_ entry: InFlightEntry, for key: String) async throws -> PreparedPlayerMedia {
        do {
            let media = try await entry.task.value
            if let cached = prepared[key] {
                touch(key)
                return cached
            }
            guard inFlight[key]?.token == entry.token else {
                throw CancellationError()
            }
            inFlight[key] = nil
            prepared[key] = media
            touch(key)
            trimToCapacity()
            return media
        } catch {
            if inFlight[key]?.token == entry.token {
                inFlight[key] = nil
            }
            throw error
        }
    }

    func trim(keeping playInfos: [PlayInfo]) {
        let keys = Set(playInfos.map(\.sequenceKey))
        for key in Array(inFlight.keys) where !keys.contains(key) {
            inFlight.removeValue(forKey: key)?.task.cancel()
        }
        for (key, media) in prepared where !keys.contains(key) {
            discardBuffer(of: media)
        }
        prepared = prepared.filter { keys.contains($0.key) }
        accessOrder.removeAll { !keys.contains($0) }
    }

    func cancelAll() {
        cancellationGeneration += 1
        inFlight.values.forEach { $0.task.cancel() }
        inFlight.removeAll()
        prepared.values.forEach { discardBuffer(of: $0) }
        prepared.removeAll()
        accessOrder.removeAll()
    }

    private func touch(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func trimToCapacity() {
        while prepared.count > maxPreparedEntries, let key = accessOrder.first {
            accessOrder.removeFirst()
            if let media = prepared.removeValue(forKey: key) {
                discardBuffer(of: media)
            }
        }
    }

    private func discardBuffer(of media: PreparedPlayerMedia) {
        Task { @MainActor in media.discardPreviewBuffer() }
    }
}
