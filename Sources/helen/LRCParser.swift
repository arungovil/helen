import Foundation

/// A single timed lyric line parsed from LRC format.
struct LyricLine: Codable, Sendable {
  /// Time offset in seconds from the start of the track.
  let time: TimeInterval
  /// The lyric text at this timestamp.
  let text: String
}

/// Parses LRC-format lyrics into timed lines.
///
/// Supports `[mm:ss.xx]text` and `[mm:ss]text` formats.
/// Lines are returned sorted by time ascending.
enum LRCParser {
  static func parse(_ lrc: String) -> [LyricLine] {
    // Local, not static: Regex isn't Sendable under Swift 6.
    let linePattern = /\[(\d+):(\d+(?:\.\d+)?)\](.*)/

    return lrc
      .components(separatedBy: .newlines)
      .compactMap { line -> LyricLine? in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.prefixMatch(of: linePattern) else { return nil }

        let text = String(match.3).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        let minutes = Double(match.1) ?? 0
        let seconds = Double(match.2) ?? 0
        return LyricLine(time: minutes * 60 + seconds, text: text)
      }
      .sorted { $0.time < $1.time }
  }
}
