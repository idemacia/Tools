import AppKit

/// 透明拖动层：除 ScrollView 区域外均可拖动浮窗（手动更新 frame，兼容桌面层级 NSPanel）。
final class PanelDragLayerView: NSView {
    var onMoved: (() -> Void)?

    /// nonactivating 浮窗不会成为 key window，必须允许首次点击。
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point), window != nil else { return nil }
        if isInHeaderRegion(point) {
            return self
        }
        return isOverScrollView(at: point) ? nil : self
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }

        let startMouse = NSEvent.mouseLocation
        let startOrigin = window.frame.origin
        var didDrag = false

        window.trackEvents(
            matching: [.leftMouseDragged, .leftMouseUp],
            timeout: .greatestFiniteMagnitude,
            mode: .eventTracking
        ) { event, stop in
            guard let event else { return }

            if event.type == .leftMouseUp {
                if didDrag {
                    self.onMoved?()
                }
                stop.pointee = true
                return
            }

            let current = NSEvent.mouseLocation
            let dx = current.x - startMouse.x
            let dy = current.y - startMouse.y

            if !didDrag, hypot(dx, dy) < 2 {
                return
            }

            didDrag = true
            window.setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy))
        }
    }

    private func isInHeaderRegion(_ point: NSPoint) -> Bool {
        point.y >= bounds.height - 88
    }

    private func isOverScrollView(at point: NSPoint) -> Bool {
        guard let contentView = window?.contentView else { return false }
        let windowPoint = convert(point, to: nil)
        return containsScrollView(in: contentView, at: windowPoint)
    }

    private func containsScrollView(in view: NSView, at windowPoint: NSPoint) -> Bool {
        let localPoint = view.convert(windowPoint, from: nil)
        guard view.bounds.contains(localPoint) else { return false }

        if view is NSScrollView {
            return true
        }
        if String(describing: type(of: view)).contains("ScrollView") {
            return true
        }

        for subview in view.subviews {
            if containsScrollView(in: subview, at: windowPoint) {
                return true
            }
        }
        return false
    }
}
