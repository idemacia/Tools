import AppKit
import SwiftUI

struct FloatingPanelView: View {
    @ObservedObject var viewModel: DeskViewModel
    var onWindowMoved: () -> Void
    @State private var newTaskText = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                )
                .opacity(viewModel.panelOpacity)

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                quickAddBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                Divider().opacity(0.4)
                content
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 320, minHeight: 280)
        .background(WindowMoveObserver(onMoved: onWindowMoved))
        .sheet(isPresented: $viewModel.showSettings) {
            ConnectionSettingsSheet(viewModel: viewModel)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(viewModel.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WindowHeaderDragArea(onMoved: onWindowMoved))

            SettingsGearButton(viewModel: viewModel)
                .frame(width: 28, height: 28)

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
        }
    }

    private var statusColor: Color {
        if !viewModel.serverConnected { return .secondary }
        return viewModel.bridgeConnected ? .green : .orange
    }

    private var quickAddBar: some View {
        HStack(spacing: 8) {
            TextField("新建待办…", text: $newTaskText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submitNewTask)
            Button("添加") { submitNewTask() }
                .disabled(newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func submitNewTask() {
        let text = newTaskText
        newTaskText = ""
        viewModel.addTask(text: text)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.incompleteTasks.isEmpty && viewModel.completedTasks.isEmpty {
                    emptyPlaceholder
                } else {
                    if !viewModel.incompleteTasks.isEmpty {
                        sectionHeader("未完成", count: viewModel.incompleteTasks.count)
                        ForEach(viewModel.incompleteTasks) { task in
                            TaskRowView(
                                task: task,
                                fontSize: viewModel.fontSize,
                                isCompleted: false,
                                onComplete: { viewModel.completeTask(id: task.id) },
                                onUncomplete: {},
                                onDueDateChange: { date in
                                    viewModel.setDueDate(taskID: task.id, dueDate: date)
                                }
                            )
                            if task.id != viewModel.incompleteTasks.last?.id {
                                Divider().opacity(0.3)
                            }
                        }
                    } else {
                        Text("暂无未完成事项")
                            .font(.system(size: viewModel.fontSize))
                            .foregroundStyle(.secondary)
                    }

                    if !viewModel.completedTasks.isEmpty {
                        sectionHeader("已完成", count: viewModel.completedTasks.count)
                            .padding(.top, 8)
                        if viewModel.showCompletedSection {
                            ForEach(viewModel.completedTasks) { task in
                                TaskRowView(
                                    task: task,
                                    fontSize: viewModel.fontSize,
                                    isCompleted: true,
                                    onComplete: {},
                                    onUncomplete: { viewModel.uncompleteTask(id: task.id) },
                                    onDueDateChange: { _ in }
                                )
                                if task.id != viewModel.completedTasks.last?.id {
                                    Divider().opacity(0.3)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text("\(title)（\(count)）")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if title == "已完成" {
                Button(viewModel.showCompletedSection ? "隐藏" : "显示") {
                    viewModel.showCompletedSection.toggle()
                }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyPlaceholder: some View {
        Text("暂无待办\n\n手机钉钉发消息到 NAS，或上方输入框添加。\n示例：买牛奶 / 6/1 交报告")
            .font(.system(size: viewModel.fontSize))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.top, 4)
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
