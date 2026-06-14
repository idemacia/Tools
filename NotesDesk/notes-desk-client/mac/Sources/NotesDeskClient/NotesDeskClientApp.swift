import AppKit
import SwiftUI

@main
struct NotesDeskClientApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("NotesDesk Client", systemImage: "cloud") {
            MenuContentView(viewModel: appDelegate.viewModel, appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuContentView: View {
    @ObservedObject var viewModel: DeskViewModel
    let appDelegate: AppDelegate

    var body: some View {
        Group {
            Text(viewModel.statusMessage)
                .font(.caption)

            HStack {
                Circle()
                    .fill(viewModel.serverConnected ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(viewModel.serverConnected
                     ? (viewModel.bridgeConnected ? "NAS · 钉钉桥在线" : "NAS · 钉钉桥离线")
                     : "NAS：未连接")
                    .font(.caption)
            }

            Toggle("显示浮窗", isOn: $viewModel.panelVisible)
                .onChange(of: viewModel.panelVisible) { visible in
                    appDelegate.setPanelVisible(visible)
                }

            Button("打开浮窗") {
                appDelegate.setPanelVisible(true)
            }

            Picker("视图", selection: $viewModel.viewMode) {
                ForEach(DeskViewMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            Button("设置…") {
                viewModel.panelVisible = true
                appDelegate.setPanelVisible(true)
                viewModel.showSettings = true
            }

            Toggle("显示已完成", isOn: $viewModel.showCompletedSection)

            Button("刷新") {
                Task { await viewModel.refreshFromServer() }
            }

            Button("完成最近一条") {
                viewModel.completeMostRecent()
            }

            Button("清除已完成") {
                viewModel.clearCompleted()
            }

            Divider()

            Text("服务器: \(AppSettings.serverBaseURL)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("退出 NotesDesk Client") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = DeskViewModel()
    private var panelController: FloatingPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        viewModel.startPolling()
        bootstrapPanel()
        presentUIOnLaunch()
        print("NotesDeskClient 已启动（NAS API 模式）")
        print("→ 服务器: \(AppSettings.serverBaseURL)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopPolling()
    }

    func setPanelVisible(_ visible: Bool) {
        viewModel.panelVisible = visible
        panelController?.applyVisibility(visible)
        if visible {
            panelController?.ensureOnScreenAndFront()
            Task { await viewModel.refreshFromServer() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        setPanelVisible(true)
        return true
    }

    private func presentUIOnLaunch() {
        NSApp.activate(ignoringOtherApps: true)
        viewModel.panelVisible = true
        panelController?.applyVisibility(true)
        panelController?.ensureOnScreenAndFront()
    }

    private func bootstrapPanel() {
        guard panelController == nil else { return }
        let controller = FloatingPanelController(viewModel: viewModel)
        panelController = controller
        controller.applyVisibility(viewModel.panelVisible)
    }
}
