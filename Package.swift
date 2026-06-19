// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "helen",
  platforms: [.macOS(.v13)],
  targets: [
    .executableTarget(
      name: "helen",
      swiftSettings: [
        .unsafeFlags([
          "-Xlinker", "-sectcreate",
          "-Xlinker", "__TEXT",
          "-Xlinker", "__info_plist",
          "-Xlinker", "Sources/helen/Info.plist"
        ])
      ]
    )
  ]
)
