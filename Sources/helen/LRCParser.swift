import Foundation

/// A single timed lyric line parsed from LRC format.
struct LyricLine: Sendable {
  /// Time offset in seconds from the start of the track.
  let time: TimeInterval
  /// The lyric text at this timestamp.
  let text: String
}

/// Parses LRC-format lyrics into timed lines.
///
/// Supports `[mm:ss.xx]text` and `[mm:ss]text` formats.
/// Lines are returned sorted by time ascending.
struct LRCParser {
  static func parse(_ lrc: String) -> [LyricLine] {
    let lines = lrc.components(separatedBy: .newlines)
    var result: [LyricLine] = []

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard trimmed.hasPrefix("[") else { continue }

      // Match [mm:ss.xx]text or [mm:ss]text
      let timePattern = /\[(\d+):(\d+(?:\.\d+)?)\](.*)/
      guard let match = try? timePattern.firstMatch(in: trimmed) else { continue }

      let minutes = Double(match.1) ?? 0
      let seconds = Double(match.2) ?? 0
      let text = String(match.3).trimmingCharacters(in: .whitespaces)

      guard !text.isEmpty else { continue }

      let time = minutes * 60 + seconds
      result.append(LyricLine(time: time, text: text))
    }

    return result.sorted { $0.time < $1.time }
  }
}
