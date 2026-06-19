import Foundation

// MARK: - Models

struct LRCLIBResponse: Decodable {
  let plainLyrics: String
  let syncedLyrics: String?
}

struct LyricsResult {
  let plain: String
  let synced: [LyricLine]
}

// MARK: - Service

struct LyricsService {
  private let session: URLSession
  private let decoder = JSONDecoder()

  init(session: URLSession? = nil) {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = C.Lyrics.requestTimeout
    config.timeoutIntervalForResource = C.Lyrics.resourceTimeout
    self.session = session ?? URLSession(configuration: config)
  }

  func fetchLyrics(artist: String, title: String) async -> LyricsResult? {
    guard let request = makeRequest(artist: artist, title: title) else {
      print("[LyricsService] Failed to build request")
      return nil
    }

    print("[LyricsService] GET \(request.url?.absoluteString ?? "?")")

    do {
      let (data, response) = try await session.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        print("[LyricsService] No HTTP response")
        return nil
      }

      print("[LyricsService] Status: \(httpResponse.statusCode), bytes: \(data.count)")
      guard httpResponse.statusCode == 200 else { return nil }

      let decoded = try decoder.decode(LRCLIBResponse.self, from: data)
      return makeResult(from: decoded)
    } catch {
      print("[LyricsService] Error: \(error)")
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

  private func makeResult(from response: LRCLIBResponse) -> LyricsResult {
    let plain = response.plainLyrics.trimmingCharacters(in: .whitespacesAndNewlines)

    let synced: [LyricLine]
    if let raw = response.syncedLyrics {
      synced = LRCParser.parse(raw)
    } else {
      synced = []
    }

    return LyricsResult(plain: plain, synced: synced)
  }
}
