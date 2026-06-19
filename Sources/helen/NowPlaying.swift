import MediaRemoteAdapter
import SwiftUI

@MainActor
final class NowPlaying: ObservableObject {
  @Published var title: String = C.Defaults.title
  @Published var artist: String?
  @Published var album: String?
  @Published var lyricsSnippet: String?
  @Published var currentLine: String?

  private let controller = MediaController()
  private let lyrics = LyricsService()
  private var lastTrackId: String?
  private var syncedLines: [LyricLine] = []
  private var syncTimer: Timer?
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

    syncPlaybackState(from: info?.payload)
    let newTrackId = makeTrackId(from: info)

    Task { @MainActor in
      self.title = newTitle
      self.artist = newArtist
      self.album = newAlbum

      guard newTrackId != self.lastTrackId else { return }
      self.lastTrackId = newTrackId
      self.lyricsSnippet = nil
      self.stopSync()
      await self.fetchLyrics()
    }
  }

  private func fetchLyrics() async {
    guard let artist, title != C.Defaults.title else {
      print("[NowPlaying] Skipping lyrics — idle")
      return
    }

    print("[NowPlaying] Fetching lyrics for \(title) — \(artist)")

    guard let result = await lyrics.fetchLyrics(artist: artist, title: title) else {
      print("[NowPlaying] No lyrics found")
      return
    }

    lyricsSnippet = makeSnippet(from: result.plain)
    print("[NowPlaying] Snippet (\(lyricsSnippet?.count ?? 0) chars)")

    guard !result.synced.isEmpty else {
      print("[NowPlaying] No synced lyrics")
      return
    }

    syncedLines = result.synced
    print("[NowPlaying] Synced: \(syncedLines.count) lines")
    startSync()
  }

  private func startSync() {
    syncTimer = Timer.scheduledTimer(
      withTimeInterval: C.Sync.tickInterval,
      repeats: true
    ) { [weak self] _ in
      Task { @MainActor in
        self?.tick()
      }
    }
  }

  private func stopSync() {
    syncTimer?.invalidate()
    syncTimer = nil
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
    lastTimestamp = (p.timestampEpochMicros ?? Date().timeIntervalSince1970) / 1_000_000
    playbackRate = p.playbackRate ?? C.Defaults.playbackRate
    isPlaying = p.isPlaying ?? false
  }

  private func makeTrackId(from info: TrackInfo?) -> String? {
    info.map { "\($0.payload.title ?? "")-\($0.payload.artist ?? "")-\($0.payload.album ?? "")" }
  }

  private func makeSnippet(from plain: String) -> String? {
    let lines = plain
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
      .prefix(C.Lyrics.snippetLineCount)

    return lines.isEmpty ? nil : lines.joined(separator: "\n")
  }
}
