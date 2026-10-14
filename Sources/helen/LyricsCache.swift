import Foundation
import os

/// Lyrics cache backed by a single JSON file in ~/Library/Caches/helen.
actor LyricsCache {
  private let fileURL: URL
  private let log = Logger(subsystem: C.logSubsystem, category: "LyricsCache")
  private var entries: [String: [LyricLine]]

  init() {
    fileURL = URL.cachesDirectory.appending(path: "helen/lyrics.json")
    entries =
      (try? Data(contentsOf: fileURL))
      .flatMap { try? JSONDecoder().decode([String: [LyricLine]].self, from: $0) } ?? [:]
  }

  static func key(artist: String, title: String, duration: TimeInterval?) -> String {
    "\(artist)|\(title)|\(duration.map { String(Int($0.rounded())) } ?? "-")"
  }

  func lines(for key: String) -> [LyricLine]? { entries[key] }

  // shortcut: rewrites the whole file on every store, fine until the cache reaches thousands of songs.
  func store(_ lines: [LyricLine], for key: String) {
    entries[key] = lines
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
    } catch {
      log.error("Failed to write cache: \(error)")
    }
  }
}
