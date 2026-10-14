import SwiftUI

/// Template image so macOS tints it for light and dark menu bars.
@MainActor
private let menuIcon: NSImage? = {
  guard let url = Bundle.module.url(forResource: "icon", withExtension: "png"),
    let image = NSImage(contentsOf: url)
  else { return nil }
  image.isTemplate = true
  image.size = NSSize(width: C.Menu.iconSize, height: C.Menu.iconSize)
  return image
}()

@main
struct Helen: App {
  @StateObject private var nowPlaying = NowPlaying()

  var body: some Scene {
    MenuBarExtra {
      TrackMenu(nowPlaying: nowPlaying)
    } label: {
      if nowPlaying.isIdle, let menuIcon {
        Image(nsImage: menuIcon)
      } else {
        Text(nowPlaying.currentLine ?? nowPlaying.title)
          .frame(width: C.Menu.labelWidth, alignment: C.Menu.labelAlignment)
          .lineLimit(1)
      }
    }
  }
}

private struct TrackMenu: View {
  @ObservedObject var nowPlaying: NowPlaying

  var body: some View {
    Text(nowPlaying.title)
      .fontWeight(.semibold)
      .frame(width: C.Menu.dropdownWidth, alignment: .leading)
      .lineLimit(1)

    if let artist = nowPlaying.artist {
      Text("👤 \(artist)")
        .foregroundStyle(.secondary)
        .frame(width: C.Menu.dropdownWidth, alignment: .leading)
        .lineLimit(1)
    }
    if let album = nowPlaying.album {
      Text("💿 \(album)")
        .foregroundStyle(.tertiary)
        .frame(width: C.Menu.dropdownWidth, alignment: .leading)
        .lineLimit(1)
    }
    Divider()
    Link(destination: C.Menu.repoURL) {
      Text("★ Star on GitHub")
        .font(.caption2)
        .frame(width: C.Menu.dropdownWidth, alignment: .leading)
    }
    .foregroundStyle(.secondary)
  }
}
