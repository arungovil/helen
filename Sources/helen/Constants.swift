import SwiftUI

enum C {
  enum Menu {
    static let labelWidth: CGFloat = 200
    static let labelAlignment: Alignment = .leading
    static let dropdownWidth: CGFloat = 250
    static let snippetLineLimit = 3
  }

  enum Lyrics {
    static let baseURL = "https://lrclib.net/api/get"
    static let userAgent = "helen/1.0"
    static let requestTimeout: TimeInterval = 20
    static let resourceTimeout: TimeInterval = 30
    static let snippetLineCount = 3
  }

  enum Sync {
    static let tickInterval: TimeInterval = 0.2
  }

  enum Defaults {
    static let title = "Helen"
    static let playbackRate: Double = 1
  }
}
