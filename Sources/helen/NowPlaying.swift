import MediaRemoteAdapter
import SwiftUI
import os

@MainActor
final class NowPlaying: ObservableObject {
  @Published var title: String = C.Defaults.title
  @Published var artist: String?
  @Published var album: String?
  @Published var currentLine: String?

  private let controller = MediaController()
  private let lyrics = LyricsService()
  private let log = Logger(subsystem: C.logSubsystem, category: "NowPlaying")
  private var lastTrackId: String?
  private var duration: TimeInterval?
  private var syncedLines: [LyricLine] = []
  private var syncTask: Task<Void, Never>?
  private var fetchTask: Task<Void, Never>?
  private var lastElapsed: TimeInterval = 0
  private var lastTimestamp: TimeInterval = 0
  private var playbackRate: Double = C.Defaults.playbackRate
  private var isPlaying: Bool = false

  init() {
    controller.onTrackInfoReceived = { [weak self] info in
      self?.handleTrackUpdate(info)
    }
    controller.startListening()
  }

  private func handleTrackUpdate(_ info: TrackInfo?) {
    let newTitle = info?.payload.title ?? C.Defaults.title
    let newArtist = info?.payload.artist
    let newAlbum = info?.payload.album
    let newDuration = info?.payload.durationMicros.map { $0 / 1_000_000 }

    syncPlaybackState(from: info?.payload)
    let newTrackId = makeTrackId(from: info)

    Task { @MainActor in
      self.title = newTitle
      self.artist = newArtist
      self.album = newAlbum
      self.duration = newDuration

      guard newTrackId != self.lastTrackId else { return }
      self.lastTrackId = newTrackId
      self.stopSync()
      self.fetchTask?.cancel()
      self.fetchTask = Task { await self.fetchLyrics() }
    }
  }

  private func fetchLyrics() async {
    guard let artist, title != C.Defaults.title else {
      log.debug("Skipping lyrics — idle")
      return
    }

    log.debug("Fetching lyrics for \(self.title) — \(artist)")

    let fetched = await lyrics.fetchLyrics(artist: artist, title: title, duration: duration)
    // A newer track cancelled this fetch; don't apply its stale result.
    guard !Task.isCancelled else { return }

    guard let lines = fetched, !lines.isEmpty else {
      log.debug("No synced lyrics")
      return
    }

    syncedLines = lines
    log.debug("Synced: \(self.syncedLines.count) lines")
    startSync()
  }

  private func startSync() {
    syncTask?.cancel()
    syncTask = Task {
      while !Task.isCancelled {
        tick()
        try? await Task.sleep(for: .seconds(C.Sync.tickInterval))
      }
    }
  }

  private func stopSync() {
    syncTask?.cancel()
    syncTask = nil
    currentLine = nil
    syncedLines = []
  }

  private func tick() {
    guard isPlaying, !syncedLines.isEmpty else {
      if currentLine != nil { currentLine = nil }
      return
    }

    let elapsed = lastElapsed + (Date().timeIntervalSince1970 - lastTimestamp) * playbackRate
    let line = syncedLines.last { $0.time <= elapsed }

    if line?.text != currentLine {
      currentLine = line?.text
    }
  }

  private func syncPlaybackState(from payload: TrackInfo.Payload?) {
    guard let p = payload else { return }
    lastElapsed = (p.elapsedTimeMicros ?? 0) / 1_000_000
    lastTimestamp = p.timestampEpochMicros.map { $0 / 1_000_000 } ?? Date().timeIntervalSince1970
    playbackRate = p.playbackRate ?? C.Defaults.playbackRate
    isPlaying = p.isPlaying ?? false
  }

  private func makeTrackId(from info: TrackInfo?) -> String? {
    info.map { "\($0.payload.title ?? "")-\($0.payload.artist ?? "")-\($0.payload.album ?? "")" }
  }
}
