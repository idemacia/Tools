import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class FloatingPanelController: NSWindowController {
    private let viewModel: DeskViewModel
    private var originSaveWorkItem: DispatchWorkItem?

    init(viewModel: DeskViewModel) {
        self.viewModel = viewModel

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 520),
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "NotesDesk Client"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenNone]
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

        panel.contentView = container

        let hasSavedOrigin = UserDefaults.standard.object(forKey: "panelOriginX") != nil
        if hasSavedOrigin {
            panel.setFrameOrigin(AppSettings.panelOrigin)
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
            ensureOnScreen()
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            window.orderOut(nil)
        }
    }

    func ensureOnScreenAndFront() {
        ensureOnScreen()
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func ensureOnScreen() {
        guard let window else { return }
        let frame = window.frame
        let onAnyScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
        guard !onAnyScreen, let screen = NSScreen.main else { return }
        window.center()
        clampWindowToVisibleFrame(on: screen)
    }

    private func clampWindowToVisibleFrame(on screen: NSScreen) {
        guard let window else { return }
        var frame = window.frame
        let visible = screen.visibleFrame
        if frame.origin.x < visible.minX { frame.origin.x = visible.minX }
        if frame.origin.y < visible.minY { frame.origin.y = visible.minY }
        if frame.maxX > visible.maxX { frame.origin.x = visible.maxX - frame.width }
        if frame.maxY > visible.maxY { frame.origin.y = visible.maxY - frame.height }
        window.setFrameOrigin(frame.origin)
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
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if AppSettings.quitOnClosePanel {
            NSApplication.shared.terminate(nil)
            return true
        }
        viewModel.panelVisible = false
        sender.orderOut(nil)
        return false
    }
}
