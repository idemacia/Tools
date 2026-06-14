// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotesDesk",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NotesDesk",
            path: "Sources/NotesDesk"
        ),
    ]
)
