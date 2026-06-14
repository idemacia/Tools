import AppKit
import SwiftUI

struct FloatingPanelView: View {
    @ObservedObject var viewModel: PanelViewModel
    var onWindowMoved: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                )
                .opacity(viewModel.panelOpacity)

            VStack(alignment: .leading, spacing: 12) {
                header
                Divider().opacity(0.4)
                content
            }
            .padding(16)
        }
        .frame(minWidth: 280, minHeight: 200)
        .background(
            WindowMoveObserver(onMoved: onWindowMoved)
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedFolder?.displayName ?? "未选择文件夹")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(displayTitle)
                    .font(.headline)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var content: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: viewModel.fontSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if viewModel.note.isEmpty {
                Text("暂无内容")
                    .font(.system(size: viewModel.fontSize))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    Text(viewModel.note.body)
                        .font(.system(size: viewModel.fontSize))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            viewModel.openInNotes()
        }
    }

    private var displayTitle: String {
        if viewModel.isLoading {
            return "加载中…"
        }
        if let errorMessage = viewModel.errorMessage {
            return errorMessage
        }
        if viewModel.note.isEmpty {
            return "暂无内容"
        }
        return viewModel.note.displayTitle
    }
}

private struct WindowMoveObserver: NSViewRepresentable {
    let onMoved: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            context.coordinator.observe(window: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            context.coordinator.observe(window: window)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onMoved: onMoved)
    }

    final class Coordinator: NSObject {
        private let onMoved: () -> Void
        private weak var observedWindow: NSWindow?

        init(onMoved: @escaping () -> Void) {
            self.onMoved = onMoved
        }

        func observe(window: NSWindow) {
            guard observedWindow !== window else { return }
            if let observedWindow {
                NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: observedWindow)
            }
            observedWindow = window
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidMove),
                name: NSWindow.didMoveNotification,
                object: window
            )
        }

        @objc private func windowDidMove() {
            onMoved()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
