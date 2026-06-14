// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotesDeskWidget",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NotesWidgetCore", targets: ["NotesWidgetCore"]),
        .executable(name: "NotesWidgetHost", targets: ["NotesWidgetHost"]),
    ],
    targets: [
        .target(
            name: "NotesWidgetCore",
            path: "Sources/NotesWidgetCore"
        ),
        .executableTarget(
            name: "NotesWidgetHost",
            dependencies: ["NotesWidgetCore"],
            path: "Sources/NotesWidgetHost",
            linkerSettings: [
                .linkedFramework("WidgetKit"),
            ]
        ),
    ]
)
