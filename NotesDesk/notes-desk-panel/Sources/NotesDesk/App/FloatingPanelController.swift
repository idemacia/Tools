import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class FloatingPanelController: NSWindowController {
    private let viewModel: PanelViewModel
    private var originSaveWorkItem: DispatchWorkItem?

    init(viewModel: PanelViewModel) {
        self.viewModel = viewModel

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "NotesDesk"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // 低于普通 App 窗口：切换应用时被遮挡、不抢焦点；但高于 desktopIcon 层级以便拖动。
        // desktopIconWindow 与桌面图标同级，系统会限制鼠标交互与 setFrameOrigin。
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .ignoresCycle,
            .fullScreenNone,
        ]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        super.init(window: panel)
        window?.delegate = self

        let contentView = FloatingPanelView(viewModel: viewModel) { [weak self] in
            self?.saveOriginDebounced()
        }
        let panelSize = panel.contentRect(forFrameRect: panel.frame).size
        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)

        let dragLayer = PanelDragLayerView(frame: container.bounds)
        dragLayer.autoresizingMask = [.width, .height]
        dragLayer.onMoved = { [weak self] in
            self?.saveOriginDebounced()
        }
        container.addSubview(dragLayer)

        panel.contentView = container

        let savedOrigin = AppSettings.panelOrigin
        let hasSavedOrigin = UserDefaults.standard.object(forKey: "panelOriginX") != nil
        if hasSavedOrigin {
            panel.setFrameOrigin(savedOrigin)
        } else {
            panel.center()
        }

        applyVisibility(viewModel.panelVisible)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyVisibility(_ visible: Bool) {
        guard let window else { return }
        if visible {
            // 固定在桌面层，不抢占前台应用焦点。
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
    }

    private func saveOriginDebounced() {
        originSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let origin = self?.window?.frame.origin else { return }
            AppSettings.panelOrigin = origin
        }
        originSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
}

extension FloatingPanelController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        viewModel.panelVisible = false
    }
}
