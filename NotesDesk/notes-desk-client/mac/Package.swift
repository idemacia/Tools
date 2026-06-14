// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotesDeskClient",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NotesDeskClient",
            path: "Sources/NotesDeskClient"
        ),
    ]
)
