import AppKit
import SwiftUI

struct WindowHeaderDragArea: NSViewRepresentable {
    var onMoved: () -> Void

    func makeNSView(context: Context) -> HeaderDragView {
        let view = HeaderDragView()
        view.onMoved = onMoved
        return view
    }

    func updateNSView(_ nsView: HeaderDragView, context: Context) {
        nsView.onMoved = onMoved
    }
}

final class HeaderDragView: NSView {
    var onMoved: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct SettingsGearButton: NSViewRepresentable {
    @ObservedObject var viewModel: DeskViewModel

    func makeNSView(context: Context) -> FirstMouseButton {
        let button = FirstMouseButton()
        button.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "设置")
        button.imagePosition = .imageOnly
        button.isBordered = false
        button.bezelStyle = .inline
        button.toolTip = "NAS 连接设置"
        button.target = context.coordinator
        button.action = #selector(Coordinator.openSettings)
        return button
    }

    func updateNSView(_ nsView: FirstMouseButton, context: Context) {
        context.coordinator.viewModel = viewModel
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    final class Coordinator: NSObject {
        var viewModel: DeskViewModel

        init(viewModel: DeskViewModel) {
            self.viewModel = viewModel
        }

        @objc func openSettings() {
            Task { @MainActor in
                NSApp.activate(ignoringOtherApps: true)
                viewModel.showSettings = true
            }
        }
    }
}

final class FirstMouseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
