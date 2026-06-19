import MediaRemoteAdapter
import SwiftUI

@MainActor
class NowPlaying: ObservableObject {
  @Published var title: String = "Helen"
  @Published var artist: String?
  @Published var album: String?
  private let controller = MediaController()

  init() {
    controller.onTrackInfoReceived = { [weak self] info in
      let title = info?.payload.title ?? "Helen"
      let artist = info?.payload.artist
      let album = info?.payload.album
      Task { @MainActor in
        self?.title = title
        self?.artist = artist
        self?.album = album
      }
    }
    controller.startListening()
  }
}

@main
struct helen: App {
  @StateObject private var nowPlaying = NowPlaying()

  var body: some Scene {
    MenuBarExtra {
      Text(nowPlaying.title)
        .fontWeight(.semibold)
        .frame(maxWidth: 250)
        .lineLimit(1)
      if let artist = nowPlaying.artist {
        Text("Artist: \(artist)")
          .foregroundStyle(.secondary)
          .frame(maxWidth: 250)
          .lineLimit(1)
      }
      if let album = nowPlaying.album {
        Text("Album: \(album)")
          .foregroundStyle(.tertiary)
          .frame(maxWidth: 250)
          .lineLimit(1)
      }
      Divider()
      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
    } label: {
      Text(nowPlaying.title)
        .frame(maxWidth: 200)
        .lineLimit(1)
    }
  }
}
