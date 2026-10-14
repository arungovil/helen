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
  private let log = Logger(subsystem: "helen", category: "LyricsService")

  init(session: URLSession? = nil) {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = C.Lyrics.requestTimeout
    config.timeoutIntervalForResource = C.Lyrics.resourceTimeout
    self.session = session ?? URLSession(configuration: config)
  }

  func fetchLyrics(artist: String, title: String) async -> [LyricLine]? {
    guard let request = makeRequest(artist: artist, title: title) else {
      log.error("Failed to build request")
      return nil
    }

    log.debug("GET \(request.url?.absoluteString ?? "?")")

    do {
      let (data, response) = try await session.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        log.error("No HTTP response")
        return nil
      }

      log.debug("Status: \(httpResponse.statusCode), bytes: \(data.count)")
      guard httpResponse.statusCode == 200 else { return nil }

      let decoded = try decoder.decode(LRCLIBResponse.self, from: data)
      return decoded.syncedLyrics.map(LRCParser.parse)
    } catch {
      log.error("Error: \(error)")
      return nil
    }
  }

  // MARK: - Helpers

  private func makeRequest(artist: String, title: String) -> URLRequest? {
    var components = URLComponents(string: C.Lyrics.baseURL)
    components?.queryItems = [
      URLQueryItem(name: "artist_name", value: artist),
      URLQueryItem(name: "track_name", value: title),
    ]

    guard let url = components?.url else { return nil }

    var request = URLRequest(url: url)
    request.setValue(C.Lyrics.userAgent, forHTTPHeaderField: "User-Agent")
    return request
  }
}
