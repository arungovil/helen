import SwiftUI

@main
struct helen: App {
  var body: some Scene {
    MenuBarExtra("Helen") {
      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
    }
  }
}
