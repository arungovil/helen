import Foundation
import os

// MARK: - Models

struct LRCLIBResponse: Decodable {
  let syncedLyrics: String?  // null for instrumentals and unsynced tracks
}

// MARK: - Service

struct LyricsService {
  private let session: URLSession
  private let decoder = JSONDecoder()
  private let log = Logger(subsystem: C.logSubsystem, category: "LyricsService")
  private let cache = LyricsCache()

  init(session: URLSession? = nil) {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = C.Lyrics.requestTimeout
    config.timeoutIntervalForResource = C.Lyrics.resourceTimeout
    self.session = session ?? URLSession(configuration: config)
  }

  /// Returns the cached lines if present; otherwise tries the exact title with duration, then a cleaned title, then the exact title without
  /// duration. lrclib 404s on a duration mismatch, so the last attempt trades timing accuracy
  /// (it may return another edit of the song) for a hit.
  func fetchLyrics(artist: String, title: String, duration: TimeInterval?) async -> [LyricLine]? {
    let title = Self.stripRemaster(title)
    let key = LyricsCache.key(artist: artist, title: title, duration: duration)
    if let cached = await cache.lines(for: key) {
      log.debug("Cache hit: \(key)")
      return cached
    }

    let cleaned = Self.cleanTitle(title)
    var attempts: [(title: String, duration: TimeInterval?)] = [(title, duration)]
    if cleaned != title { attempts.append((cleaned, duration)) }
    if duration != nil { attempts.append((title, nil)) }

    do {
      for attempt in attempts {
        if let lines = try await get(
          artist: artist, title: attempt.title, duration: attempt.duration)
        {
          if !lines.isEmpty { await cache.store(lines, for: key) }
          return lines
        }
      }
    } catch {
      log.error("Error: \(error)")
    }
    return nil
  }

  /// Drops remaster tags: "Song (Remastered 2011)", "Song [2011 Remaster]", "Song - Remastered".
  static func stripRemaster(_ title: String) -> String {
    title
      .replacing(/\s*[\(\[][^\)\]]*remaster[^\)\]]*[\)\]]/.ignoresCase(), with: "")
      .replacing(/\s+-\s+[^-]*remaster.*$/.ignoresCase(), with: "")
      .trimmingCharacters(in: .whitespaces)
  }

  /// Strips bracketed groups and a trailing " - suffix", e.g. "Song (feat. X) - Remastered" → "Song".
  static func cleanTitle(_ title: String) -> String {
    let cleaned =
      title
      .replacing(/\s*[\(\[][^\)\]]*[\)\]]/, with: "")
      .replacing(/\s+-\s+.*$/, with: "")
      .trimmingCharacters(in: .whitespaces)
    return cleaned.isEmpty ? title : cleaned
  }

  // MARK: - Helpers

  /// Returns nil on a 404 (no match); throws on transport or other HTTP errors.
  private func get(artist: String, title: String, duration: TimeInterval?) async throws
    -> [LyricLine]?
  {
    var components = URLComponents(string: C.Lyrics.baseURL)
    components?.queryItems = [
      URLQueryItem(name: "artist_name", value: artist),
      URLQueryItem(name: "track_name", value: title),
    ]
    if let duration {
      components?.queryItems?.append(
        URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
    }
    guard let url = components?.url else { throw URLError(.badURL) }

    var request = URLRequest(url: url)
    request.setValue(C.Lyrics.userAgent, forHTTPHeaderField: "User-Agent")
    log.debug("GET \(url.absoluteString)")

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

    log.debug("Status: \(http.statusCode), bytes: \(data.count)")
    guard http.statusCode != 404 else { return nil }
    guard http.statusCode == 200 else { throw URLError(.badServerResponse) }

    return try decoder.decode(LRCLIBResponse.self, from: data).syncedLyrics.map(LRCParser.parse)
  }
}
