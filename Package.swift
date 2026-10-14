// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "helen",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(url: "https://github.com/ejbills/mediaremote-adapter.git", branch: "master")
  ],
  targets: [
    .executableTarget(
      name: "helen",
      dependencies: [.product(name: "MediaRemoteAdapter", package: "mediaremote-adapter")],
      exclude: ["Info.plist"],
      resources: [.process("Resources")],
      swiftSettings: [
        .unsafeFlags([
          "-Xlinker", "-sectcreate",
          "-Xlinker", "__TEXT",
          "-Xlinker", "__info_plist",
          "-Xlinker", "Sources/helen/Info.plist",
        ])
      ]
    )
  ]
)
